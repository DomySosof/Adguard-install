#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}    AdGuard Home - Instalador Docker    ${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${YELLOW}Puertos sugeridos (evitando 3000 y 80 que ya usas):${NC}"
echo ""

read -p "Puerto para el dashboard (default: 8080): " PORT_DASHBOARD
PORT_DASHBOARD=${PORT_DASHBOARD:-8080}
while [ "$PORT_DASHBOARD" = "3000" ] || [ "$PORT_DASHBOARD" = "80" ]; do
    echo -e "${RED}Puerto ${PORT_DASHBOARD} esta en uso. Elige otro (ej: 8080, 8888, 9000):${NC}"
    read -p "Puerto para el dashboard: " PORT_DASHBOARD
done

read -p "Puerto para el setup wizard (default: 3001): " PORT_WIZARD
PORT_WIZARD=${PORT_WIZARD:-3001}
while [ "$PORT_WIZARD" = "3000" ] || [ "$PORT_WIZARD" = "80" ]; do
    echo -e "${RED}Puerto ${PORT_WIZARD} esta en uso. Elige otro (ej: 3001, 3002, 8081):${NC}"
    read -p "Puerto para el setup wizard: " PORT_WIZARD
done

read -p "Puerto DNS (default: 53): " PORT_DNS
PORT_DNS=${PORT_DNS:-53}

read -p "Puerto HTTPS (default: 443, deja vacio para omitir): " PORT_HTTPS

read -p "Nombre de usuario admin: " ADMIN_USER
while [ -z "$ADMIN_USER" ]; do
    read -p "El nombre de usuario no puede estar vacio: " ADMIN_USER
done

read -s -p "Contrasena admin: " ADMIN_PASS
echo ""
while [ -z "$ADMIN_PASS" ]; do
    read -s -p "La contrasena no puede estar vacia: " ADMIN_PASS
    echo ""
done

read -p "Upstream DNS (default: https://dns.quad9.net/dns-query): " DNS_UPSTREAM
DNS_UPSTREAM=${DNS_UPSTREAM:-"https://dns.quad9.net/dns-query"}

echo ""
echo -e "${YELLOW}Resumen de configuracion:${NC}"
echo -e "  Dashboard:    ${GREEN}http://localhost:${PORT_DASHBOARD}${NC}"
echo -e "  Setup wizard: ${GREEN}http://localhost:${PORT_WIZARD}${NC}"
echo -e "  DNS:          ${GREEN}${PORT_DNS}${NC}"
echo -e "  Admin user:   ${GREEN}${ADMIN_USER}${NC}"
echo -e "  DNS upstream: ${GREEN}${DNS_UPSTREAM}${NC}"
echo ""
read -p "Continuar? (s/n): " CONFIRM
if [ "$CONFIRM" != "s" ] && [ "$CONFIRM" != "S" ]; then
    echo "Instalacion cancelada."
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="${SCRIPT_DIR}/workdir"
CONFDIR="${SCRIPT_DIR}/confdir"

mkdir -p "$WORKDIR" "$CONFDIR"

PASS_HASH=$(htpasswd -Bbn "$ADMIN_USER" "$ADMIN_PASS" 2>/dev/null | cut -d: -f2-)

if [ -z "$PASS_HASH" ]; then
    echo -e "${RED}Error: No se pudo generar el hash de la contrasena.${NC}"
    echo "Creando configuracion sin usuario. Podras crearlo desde el wizard."
    CREATE_USER=false
else
    CREATE_USER=true
fi

cat > "${SCRIPT_DIR}/docker-compose.yml" <<EOF
services:
  adguardhome:
    image: adguard/adguardhome:latest
    container_name: adguardhome
    restart: unless-stopped
    ports:
      - "${PORT_DNS}:53/tcp"
      - "${PORT_DNS}:53/udp"
      - "${PORT_WIZARD}:3000/tcp"
      - "${PORT_DASHBOARD}:80/tcp"
EOF

if [ -n "$PORT_HTTPS" ]; then
    echo "      - \"${PORT_HTTPS}:443/tcp\"" >> "${SCRIPT_DIR}/docker-compose.yml"
fi

cat >> "${SCRIPT_DIR}/docker-compose.yml" <<EOF
    volumes:
      - "./workdir:/opt/adguardhome/work"
      - "./confdir:/opt/adguardhome/conf"
    cap_add:
      - NET_ADMIN
EOF

echo -e "${GREEN}docker-compose.yml creado${NC}"

if [ "$CREATE_USER" = true ]; then
    cat > "${CONFDIR}/AdGuardHome.yaml" <<'YAMLEOF'
http:
  pprof:
    port: 6060
    enabled: false
  doh:
    routes:
      - GET /dns-query
      - POST /dns-query
      - GET /dns-query/{ClientID}
      - POST /dns-query/{ClientID}
    insecure_enabled: false
  address: 0.0.0.0:80
  session_ttl: 30d
users:
  - name: __ADMIN_USER__
    password: __PASS_HASH__
auth_attempts: 5
block_auth_min: 15
http_proxy: ""
language: ""
theme: auto
dns:
  bind_hosts:
    - 0.0.0.0
  port: 53
  anonymize_client_ip: false
  ratelimit: 20
  ratelimit_subnet_len_ipv4: 24
  ratelimit_subnet_len_ipv6: 56
  ratelimit_whitelist: []
  refuse_any: true
  upstream_dns:
    - __DNS_UPSTREAM__
  upstream_dns_file: ""
  bootstrap_dns:
    - 9.9.9.10
    - 149.112.112.10
  fallback_dns: []
  upstream_mode: load_balance
  fastest_timeout: 1s
  allowed_clients: []
  disallowed_clients: []
  blocked_hosts:
    - version.bind
    - id.server
    - hostname.bind
  trusted_proxies:
    - 127.0.0.0/8
    - ::1/128
  cache_enabled: true
  cache_size: 4194304
  cache_ttl_min: 0
  cache_ttl_max: 0
  cache_optimistic: false
  bogus_nxdomain: []
  aaaa_disabled: false
  enable_dnssec: true
  edns_client_subnet:
    custom_ip: ""
    enabled: false
    use_custom: false
  max_goroutines: 300
  handle_ddr: true
  ipset: []
  ipset_file: ""
  bootstrap_prefer_ipv6: false
  upstream_timeout: 10s
  private_networks: []
  use_private_ptr_resolvers: false
  local_ptr_upstreams: []
  use_dns64: false
  dns64_prefixes: []
  serve_http3: false
  use_http3_upstreams: false
  serve_plain_dns: true
  hostsfile_enabled: true
tls:
  enabled: false
  server_name: ""
  force_https: false
  port_https: 443
  port_dns_over_tls: 853
  port_dns_over_quic: 853
  port_dnscrypt: 0
  dnscrypt_config_file: ""
  certificate_chain: ""
  private_key: ""
  certificate_path: ""
  private_key_path: ""
  strict_sni_check: false
querylog:
  dir_path: ""
  ignored: []
  interval: 90d
  size_memory: 1000
  enabled: true
  ignored_enabled: false
  file_enabled: true
statistics:
  dir_path: ""
  ignored: []
  interval: 1d
  enabled: true
  ignored_enabled: false
filters:
  - enabled: true
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: false
    url: https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt
    name: AdAway Default Blocklist
    id: 2
whitelist_filters: []
user_rules: []
dhcp:
  enabled: false
  interface_name: ""
  local_domain_name: lan
  dhcpv4:
    gateway_ip: ""
    subnet_mask: ""
    range_start: ""
    range_end: ""
    lease_duration: 86400
    icmp_timeout_msec: 1000
    options: []
  dhcpv6:
    range_start: ""
    lease_duration: 86400
    ra_slaac_only: false
    ra_allow_slaac: false
filtering:
  blocking_ipv4: ""
  blocking_ipv6: ""
  blocked_services:
    schedule:
      time_zone: UTC
    ids: []
  protection_disabled_until: null
  safe_search:
    enabled: false
    bing: true
    duckduckgo: true
    ecosia: true
    google: true
    pixabay: true
    yandex: true
    youtube: true
  blocking_mode: default
  parental_block_host: family-block.dns.adguard.com
  safebrowsing_block_host: standard-block.dns.adguard.com
  rewrites: []
  safe_fs_patterns:
    - /opt/adguardhome/work/userfilters/*
  max_http_size: 256MB
  safebrowsing_cache_size: 1048576
  safesearch_cache_size: 1048576
  parental_cache_size: 1048576
  cache_time: 30
  filters_update_interval: 24
  blocked_response_ttl: 10
  filtering_enabled: true
  rewrites_enabled: true
  parental_enabled: false
  safebrowsing_enabled: false
  protection_enabled: true
clients:
  runtime_sources:
    whois: true
    arp: true
    rdns: true
    dhcp: true
    hosts: true
  persistent: []
log:
  enabled: true
  file: ""
  max_backups: 0
  max_size: 100
  max_age: 3
  compress: false
  local_time: false
  verbose: false
os:
  group: ""
  user: ""
  rlimit_nofile: 0
schema_version: 34
YAMLEOF

    sed -i '' "s|__ADMIN_USER__|${ADMIN_USER}|g" "${CONFDIR}/AdGuardHome.yaml"
    sed -i '' "s|__PASS_HASH__|${PASS_HASH}|g" "${CONFDIR}/AdGuardHome.yaml"
    sed -i '' "s|__DNS_UPSTREAM__|${DNS_UPSTREAM}|g" "${CONFDIR}/AdGuardHome.yaml"
    echo -e "${GREEN}AdGuardHome.yaml creado con usuario ${ADMIN_USER}${NC}"
else
    echo -e "${YELLOW}Sin preconfiguracion de usuario. Usa el wizard en http://localhost:${PORT_WIZARD}${NC}"
fi

echo ""
echo -e "${YELLOW}Iniciando AdGuard Home...${NC}"
cd "$SCRIPT_DIR"
docker compose up -d

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    AdGuard Home instalado!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
if [ "$CREATE_USER" = true ]; then
    echo -e "  Dashboard: ${CYAN}http://localhost:${PORT_DASHBOARD}${NC}"
    echo -e "  Usuario:   ${CYAN}${ADMIN_USER}${NC}"
else
    echo -e "  Setup wizard: ${CYAN}http://localhost:${PORT_WIZARD}${NC}"
    echo -e "  Dashboard:    ${CYAN}http://localhost:${PORT_DASHBOARD}${NC} (despues del wizard)"
fi
echo ""
echo -e "  DNS server: ${CYAN}localhost:${PORT_DNS}${NC}"
echo ""
echo -e "  Logs: docker compose logs -f"
echo -e "  Stop: docker compose stop"
echo -e "  Start: docker compose start"
echo -e "  Restart: docker compose restart"
echo ""
