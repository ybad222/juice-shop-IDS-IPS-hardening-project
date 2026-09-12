# Defense-in-Depth Lab — Hardening a Vulnerable Web App with iptables, TLS/PKI, WAF, IDS & IPS

![Status](https://img.shields.io/badge/status-completed-brightgreen)
![Category](https://img.shields.io/badge/category-defensive%20security-blue)
![OWASP CRS](https://img.shields.io/badge/OWASP-CRS%203.3.5-red)
![Target](https://img.shields.io/badge/target-OWASP%20Juice%20Shop-orange)
![Env](https://img.shields.io/badge/environment-isolated%20VM%20lab-lightgrey)

A progressive blue-team hardening exercise: **iptables → TLS reverse proxy (private PKI) → ModSecurity WAF (OWASP CRS) → Snort NIDS → Fail2ban-driven IPS**, built and validated end-to-end against a live, intentionally vulnerable target (OWASP Juice Shop) in an isolated VM lab. Every layer is tested with a real attack (XSS, port scans, sensitive-file disclosure, SYN flood) and the evidence is captured.

> **Educational lab, not a production deployment.** Built entirely inside an isolated VirtualBox host-only network (`192.168.56.0/24`) against a deliberately vulnerable target (OWASP Juice Shop). No real systems, credentials, or public IPs are involved.

