#!/usr/bin/env bash
# ==============================================================================
# iptables baseline — Juice Shop defense-in-depth lab
# Environment: isolated VirtualBox lab (host-only network 192.168.56.0/24)
# Policy: default-deny on all three built-in chains, explicit allow-listing only.
# ==============================================================================
set -euo pipefail

ADMIN_IP="192.168.56.1"   # trusted administrator workstation (lab-only, non-routable range)

# --- Stage 1: default-deny baseline -----------------------------------------
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# Loopback — required for local inter-process traffic (Apache <-> Docker app)
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Established/related connections (stateful return traffic)
iptables -A INPUT  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# DNS resolution
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
iptables -A INPUT  -p tcp --sport 53 -j ACCEPT

# ICMP (diagnostics / path MTU)
iptables -A OUTPUT -p icmp -j ACCEPT
iptables -A INPUT  -p icmp -j ACCEPT

# DHCP (dynamic addressing on the host-only adapter)
iptables -A OUTPUT -p udp --dport 67:68 -j ACCEPT
iptables -A INPUT  -p udp --sport 67:68 --dport 67:68 -j ACCEPT

# --- Stage 2: administration + outbound web ---------------------------------
# SSH restricted to the admin workstation only (least privilege)
iptables -A INPUT  -p tcp -s "${ADMIN_IP}/32" --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 22 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Outbound HTTP/HTTPS (package updates, external checks)
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A INPUT  -p tcp --sport 80  -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
iptables -A INPUT  -p tcp --sport 443 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# --- Stage 3: TLS reverse proxy exposure ------------------------------------
# Internal loopback channel: Apache -> Juice Shop container (3000/tcp)
iptables -A INPUT  -p tcp --dport 3000 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 3000 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Public-facing TLS entry point (8443/tcp) — the only externally reachable app port
iptables -A INPUT  -p tcp --dport 8443 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 8443 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# --- Stage 4: close the WAF bypass (defense-in-depth fix) -------------------
# A secondary backend port (10000/tcp) was found reachable directly, bypassing
# the reverse proxy + ModSecurity entirely. Lock it to loopback only.
iptables -I INPUT 1 -p tcp -s 127.0.0.1 --dport 10000 -j ACCEPT
iptables -A INPUT   -p tcp --dport 10000 -j REJECT

# --- Optional: connection logging for triage --------------------------------
iptables -I INPUT 1 -m state --state NEW -j LOG --log-prefix "[IPTABLES]: " --log-ip-options

# --- Optional: SYN-flood mitigation (see Exercise 5 / README §Findings) -----
# Left commented out — thresholds need calibrating per environment before
# enabling permanently. Two example strategies:
#
#   Direct ban of a known-bad source:
#     iptables -I INPUT -s <attacker_ip> -p tcp --syn -j DROP
#
#   Rate-limit new SYNs per source before falling back to DROP:
#     iptables -A INPUT -p tcp --syn -m hashlimit --hashlimit 20/sec \
#       --hashlimit-mode srcip --hashlimit-name synlimit -j ACCEPT
#     iptables -A INPUT -p tcp --syn -j DROP

echo "[+] Ruleset applied. Persist with: iptables-save | tee /etc/iptables/rules.v4"
