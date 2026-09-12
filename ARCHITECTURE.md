# Architecture Notes

Deeper detail on two parts of the build that carry the most engineering weight: the private PKI / TLS termination, and the Fail2ban proof-of-blocking sequence.

## 1. Private CA and TLS termination

The app is never exposed in cleartext beyond the loopback interface. Apache terminates TLS using a certificate issued by a lab-local CA (Easy-RSA), not a public authority — appropriate for an isolated lab, and it's what makes the CN/SAN and trust-chain issues below worth documenting (a public CA would have hidden them).

```bash
make-cadir ~/myCA && cd ~/myCA
./easyrsa init-pki
./easyrsa build-ca                 # creates the root CA (passphrase-protected)

./easyrsa gen-req juice_shop nopass   # CSR for the reverse-proxy hostname
./easyrsa sign-req server juice_shop  # CA signs it as a server certificate
```

Reading the issued certificate back confirms what a client will check during the handshake:
```bash
openssl x509 -in ~/myCA/pki/issued/juice_shop.crt -text -noout
```
Key fields: `Subject/CN=juice_shop`, the issuing CA, validity window, public key, and extended key usage (`serverAuth`). The **CN is `juice_shop`**, which matters directly for the second issue below.

**Trust chain on the client.** Neither the OS nor the browser trusts this CA by default:
- Windows: imported via `certmgr` into *Trusted Root Certification Authorities*.
- Firefox: imported **separately**, since Firefox maintains its own certificate store independent of the OS trust store — a detail that's easy to miss if you only fix it once.

**CN/SAN vs. connection target.** Connecting to `https://<VM_IP>:8443` against a certificate issued for `CN=juice_shop` fails hostname validation (the name in the URL doesn't match the name on the cert). Two independent fixes were identified:
1. Map the hostname locally (e.g. `/etc/hosts` entry `<VM_IP> juice_shop`) and connect via the name.
2. Reissue the certificate with a Subject Alternative Name covering the IP directly — the more correct fix for anything beyond a quick lab test, since it doesn't depend on every client's local hosts file.

## 2. Enforcing the inspected path (closing the WAF bypass)

The Juice Shop container also exposes a secondary internal port used during testing. Early in the WAF work, hitting that port directly reproduced the exact same XSS-vulnerable response — but with **zero entries** in `modsec_audit.log`, because that traffic never passed through Apache/ModSecurity at all.

```
Before fix:                              After fix:

Client ──X──► app:10000 (direct)          Client ──✗ REJECT──► app:10000 (direct)
Client ─────► :8443 ► WAF ► app:3000      Client ─────► :8443 ► WAF ► app:3000
                                            loopback ──✓ ACCEPT──► app:10000
```

```bash
iptables -I INPUT 1 -p tcp -s 127.0.0.1 --dport 10000 -j ACCEPT
iptables -A INPUT   -p tcp --dport 10000 -j REJECT
```

This is the single clearest "defense-in-depth" moment in the lab: the fix isn't in ModSecurity at all — it's a network-layer rule that guarantees the WAF is never bypassable, regardless of how well-tuned its rules are.

## 3. Detection → automated response loop (Fail2ban proof)

Sequence used to prove the IPS stage actually blocks, not just logs:

1. `SecRuleEngine On` — ModSecurity now returns `403` for CRS-matched requests instead of only logging them.
2. Fail2ban's `modsec` jail tails `modsec_audit.log` via a custom filter (`filter.d/modsec.conf`) matching ModSecurity's `Access denied with code 403` line.
3. Send 3 malicious (XSS) requests through the reverse proxy.
4. Expected and observed: the first requests already return `403` from ModSecurity; once the `maxretry` threshold is crossed, Fail2ban adds an `iptables-multiport` ban for that source IP.
5. A subsequent request from the same source fails at the network layer (`Connection refused` / no response) — the block has moved from "the app said no" to "the network never delivers the packet."
6. Debanning for repeat testing: `fail2ban-client set modsec unbanip <ip>`.

`bantime = 15s` in `jail.local` is a lab-testing value chosen to make the ban/replay cycle fast to observe — a production deployment would use a much longer window.

## 4. Why Snort needs to sit before TLS termination

Custom rules that match on `http_uri` (e.g. the `acquisitions.md` detection rule) only fire on cleartext HTTP. Placed on the public-facing interface where traffic arrives as TLS on `8443`, Snort sees encrypted bytes and nothing to pattern-match against. Placed on the loopback interface (where Apache forwards decrypted traffic to the app on `3000`), the same rule fires correctly. This is a deliberate architectural choice, not a limitation worked around — different Snort deployment points answer different questions (network-level recon/flood detection doesn't need cleartext; application-layer content matching does).

## 5. Documented limits of the DoS detection

The SYN-flood threshold rule (`sid:10000020`) and its `iptables` mitigation are explicitly scoped, not oversold:
- **Distributed sources** (DDoS) make per-source-IP banning far less effective — needs upstream mitigation.
- **Source IP spoofing** undermines any IP-based block for SYN floods specifically.
- **Low-and-slow** attacks can stay under the detection threshold entirely — would need additional signals (latency, socket/file-descriptor exhaustion) to catch.
- **Flag/port variation and fragmentation** can evade a rule written for one specific pattern — argues for tuning Snort's preprocessors and OS-level protections (e.g. `tcp_syncookies`) alongside signature rules.
