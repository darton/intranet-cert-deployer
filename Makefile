# --- CONFIG ---
DOMAIN ?= www.example.com
EMAIL ?= hostmaster@example.com

#ISPCONFIG
ISPC_User ?= "remoteuser"
ISPC_Password ?= "remotepass"
ISPC_Api ?= "https://ispconfig.example.com:8080/remote/json.php"
ISPC_Api_Insecure ?= 0

#ACME
ACME_SH ?= /root/.acme.sh/acme.sh
DNS_PLUGIN ?= dns_ispconfig
DNS_SLEEP ?= 20

#PKI
CERT_DIR ?= /etc/pki/tls/certs
KEY_DIR ?= /etc/pki/tls/private

#APP
APP_ROOT ?= /var/www/$(DOMAIN)
APP_USER ?= lms
APP_GROUP ?= lms
WEB_ROOT ?= $(APP_ROOT)/web
BACKUP_DIR ?= /mnt/backup

#Apache
WEB_SERVICE ?= httpd
APACHE_CONF_DIR ?= /etc/httpd/conf.d
CONF_FILE ?= $(APACHE_CONF_DIR)/$(DOMAIN).conf

# PHP-FPM
PHP_FPM_DIR ?= /etc/php-fpm.d
PHP_FPM_CONF ?= $(PHP_FPM_DIR)/$(DOMAIN).conf
PHP_SOCKET ?= /run/php-fpm/$(DOMAIN).sock


# --------------------

.PHONY: help get issue install vhost setup renew check

help:
	@echo "Available commands:"
	@echo "  make setup       - Downloads and installs acme.sh for $(EMAIL)"
	@echo "  make issue       - Issues a new certificate via acme.sh (DNS-01)"
	@echo "  make install     - Configures acme.sh for automatic certificate installation"
	@echo "  make php-fpm     - Generates the PHP-FPM configuration file for $(DOMAIN)"
	@echo "  make vhost       - Generates the Apache configuration file from a template for $(DOMAIN)"
	@echo "  make deploy      - Performs full step-by-step configuration (issue -> install -> php-fpm -> vhost)"
	@echo "  make renew       - Forces certificate renewal and deployment"
	@echo "  make check       - Checks the validity of the web server and PHP-FPM configuration"

setup:
	@echo "[+] Downloading and installing acme.sh for $(EMAIL)"
	curl https://get.acme.sh |sh -s email=$(EMAIL)

issue:
	@echo "[+] Issuing certificate for $(DOMAIN) using Let's Encrypt and the $(DNS_PLUGIN) plugin..."
	ISPC_User=$(ISPC_User) ISPC_Password=$(ISPC_Password) ISPC_Api=$(ISPC_Api) ISPC_Api_Insecure=$(ISPC_Api_Insecure) \
                $(ACME_SH) --set-default-ca --server letsencrypt
	ISPC_User=$(ISPC_User) ISPC_Password=$(ISPC_Password) ISPC_Api=$(ISPC_Api) ISPC_Api_Insecure=$(ISPC_Api_Insecure) \
                $(ACME_SH) --issue --dns $(DNS_PLUGIN) -d $(DOMAIN) --dnssleep $(DNS_SLEEP)
	@echo "[+] Certificate successfully issued."

install:
	@echo "[+] Configuring automatic certificate installation into system paths..."
	sudo $(ACME_SH) --install-cert -d $(DOMAIN) \
                --cert-file        $(CERT_DIR)/$(DOMAIN).crt \
                --key-file         $(KEY_DIR)/$(DOMAIN).key \
                --fullchain-file  $(CERT_DIR)/$(DOMAIN)-fullchain.crt \
                --reloadcmd        "systemctl reload $(WEB_SERVICE)"
	@echo "[+] Installation bound."

php-fpm:
	@echo "[+] Generating PHP-FPM configuration for $(DOMAIN)..."
	cp php-fpm.template php-fpm.tmp
	sed -i 's|DOMAIN_PLACEHOLDER|$(DOMAIN)|g' php-fpm.tmp
	sed -i 's|APP_ROOT_PLACEHOLDER|$(APP_ROOT)|g' php-fpm.tmp
	sed -i 's|WEB_ROOT_PLACEHOLDER|$(WEB_ROOT)|g' php-fpm.tmp
	sed -i 's|APP_USER_PLACEHOLDER|$(APP_USER)|g' php-fpm.tmp
	sed -i 's|APP_GROUP_PLACEHOLDER|$(APP_GROUP)|g' php-fpm.tmp
	sed -i 's|BACKUP_DIR_PLACEHOLDER|$(BACKUP_DIR)|g' php-fpm.tmp
	sudo mv php-fpm.tmp $(PHP_FPM_CONF)
	sudo chmod 644 $(PHP_FPM_CONF)
	@echo "[+] PHP-FPM pool deployed."

vhost: php-fpm
	@echo "[+] Creating directory for website: $(WEB_ROOT)..."
	sudo install -d -m 755 -o $(APP_USER) -g $(APP_GROUP) $(WEB_ROOT)
	sudo install -d -m 755 -o $(APP_USER) -g $(APP_GROUP) $(APP_ROOT)/var/sessions
	sudo install -d -m 755 -o $(APP_USER) -g $(APP_GROUP) $(APP_ROOT)/var/tmp
	@echo "[+] Generating vhost from vhost.template template..."
	cp vhost.template $(CONF_FILE)
	sed -i 's|DOMAIN_PLACEHOLDER/$(DOMAIN)|g' $(CONF_FILE)
	sed -i 's|WEB_ROOT_PLACEHOLDER|$(WEB_ROOT)|g' $(CONF_FILE)
	sed -i 's|CERT_DIR_PLACEHOLDER|$(CERT_DIR)|g' $(CONF_FILE)
	sed -i 's|KEY_DIR_PLACEHOLDER|$(KEY_DIR)|g' $(CONF_FILE)
	sed -i 's|PHP_SOCKET_PLACEHOLDER|$(PHP_SOCKET)|g' $(CONF_FILE)
	sudo mv vhost.tmp $(CONF_FILE)
	sudo chmod 644 $(CONF_FILE)
	@echo "[+] Vhost configuration is ready."
	$(MAKE) check

deploy: issue install vhost
	@echo "[+] Full configuration of domain $(DOMAIN) completed successfully!"
	sudo systemctl restart $(WEB_SERVICE)
	sudo systemctl restart php-fpm

renew:
	@echo "[+] Renewing and deploying certificate for $(DOMAIN)..."
	$(ACME_SH) --renew -d $(DOMAIN) --force
	@echo "[+] Process completed."

check:
	@echo "[+] Checking PHP-FPM configuration validity..."
	php-fpm -t
	@echo "[+] Checking $(WEB_SERVICE) web server configuration..."
	sudo httpd -t
