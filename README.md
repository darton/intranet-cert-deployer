# Intranet Cert Deployer

A lightweight `Makefile`-based automation tool for provisioning Apache virtual hosts, dedicated PHP-FPM pools, and internal SSL certificates on AlmaLinux using **`acme.sh`** and the **`dns_ispconfig`** plugin.

## Overview
Designed specifically for servers in **internal intranet environments** that lack public internet exposure. It leverages remote DNS-01 challenges via a central ISPConfig API to issue and renew SSL certificates securely, completely bypassing the need for public HTTP/HTTPS ports (80/443).

## Features
- **Intranet-Ready:** Automated DNS-01 validation via external ISPConfig.
- **One-Command Deployment (`make deploy`):** Handles certificate issuance, system path binding, PHP-FPM pool generation, and Apache VHost setup in a single workflow.
- **Principle of Least Privilege:** System-level actions use `sudo`, while template configuration and manipulation are handled locally.
- **Configuration Validation:** Built-in checks for both Apache and PHP-FPM syntax (`httpd -t` and `php-fpm -t`).

## Requirements
- **OS:** AlmaLinux / Rocky Linux 9
- **Services:** Apache (`httpd`), PHP-FPM
- **Tools:** `acme.sh` installed on the system
- **Permissions:** Sudo privileges for system-level paths and service reloads
- **ISPConfig:** A remote API user configured on your central ISPConfig server

## Quick Start

1. Clone the repository to your server:
   ```bash
   git clone [https://github.com/darton/intranet-cert-deployer.git](https://github.com/darton/intranet-cert-deployer.git) /opt/intranet-cert-deployer
   cd /opt/intranet-cert-deployer
   ```
2. Use command
   ```bash
   # make
Dostępne komendy:
  make setup       - Pobiera i instaluje acme.sh dla hostmaster@example.com
  make issue       - Wystawia nowy certyfikat przez acme.sh (DNS-01)
  make install     - Konfiguruje acme.sh do automatycznej instalacji certyfikatu
  make php-fpm     - Generuje plik konfiguracyjny PHP-FPM dla www.example.com
  make vhost       - Generuje plik konfiguracyjny Apache z szablonu dla www.example.com
  make deploy      - Wykonuje pełną konfigurację krok po kroku (issue -> install -> php-fpm -> vhost)
  make renew       - Wymusza odnowienie certyfikatu i wdrożenie go
  make check       - Sprawdza poprawność konfiguracji serwera WWW i PHP-FPM
```
