# Screenshot Extraction Notes

All 42 embedded screenshots from `TP_IDSIPS_FINAL.pdf` have been extracted and sorted
into folders matching the report's 5 stages + final exercises.

**Confidence level:**
- Folder-level grouping (which stage each image belongs to) is verified against the
  report's page structure and is reliable.
- Filenames for the "hero" evidence shots (ModSecurity audit log / OWASP CRS match,
  the `acquisitions.md` leak, the SSH/XMAS Snort alerts, the Fail2ban 403 block) were
  visually confirmed against the actual image content.
- The remaining filenames (mostly repetitive terminal/tcpdump captures) are labeled
  from the surrounding report text but were **not each individually re-opened** —
  give them a quick glance before use and rename if a label doesn't match.

**Recommended picks for the README "Evidence" section** (strongest signal per stage):
- `01-firewall/01-iptables-policy-state.png` — default-deny ruleset
- `02-tls-reverse-proxy/06-windows-ca-import-fig2.1.png` — private CA trust chain
- `03-waf-modsecurity/04-modsec-audit-log-xss-detected.png` — OWASP CRS rule match (941110/941160), anomaly score 10/CRITICAL
- `04-ids-snort/03-snort-console-ssh-alerts.png` — live NIDS alert
- `05-ips-fail2ban/07-forbidden-403-browser-after-ban.png` — active block after threshold breach
- `06-exercises/12-ex3-acquisitions-md-leaked-content.png` — sensitive file disclosure (Juice Shop's built-in decoy doc, not real company data)
- `06-exercises/03-ex2-nmap-xmas-scan-output.png` + `05-ex2-snort-xmas-alert-console.png` — recon attempt + detection pair

Rename freely — this structure is just a starting point for your `/screenshots` folder.
