# AdGuard Home - Instalador Docker (Windows PowerShell)

$ErrorActionPreference = "Stop"

function Write-Color($text, $color) {
    Write-Host $text -ForegroundColor $color
}

Clear-Host
Write-Color "========================================" Cyan
Write-Color "    AdGuard Home - Instalador Docker    " Cyan
Write-Color "            (Windows)                   " Cyan
Write-Color "========================================" Cyan
Write-Host ""

$PORT_DASHBOARD = Read-Host "Puerto para el dashboard (default: 8080)"
if ([string]::IsNullOrEmpty($PORT_DASHBOARD)) { $PORT_DASHBOARD = "8080" }
while ($PORT_DASHBOARD -eq "3000" -or $PORT_DASHBOARD -eq "80") {
    Write-Color "Puerto $PORT_DASHBOARD esta en uso. Elige otro (ej: 8080, 8888, 9000):" Red
    $PORT_DASHBOARD = Read-Host "Puerto para el dashboard"
}

$PORT_WIZARD = Read-Host "Puerto para el setup wizard (default: 3001)"
if ([string]::IsNullOrEmpty($PORT_WIZARD)) { $PORT_WIZARD = "3001" }
while ($PORT_WIZARD -eq "3000" -or $PORT_WIZARD -eq "80") {
    Write-Color "Puerto $PORT_WIZARD esta en uso. Elige otro (ej: 3001, 3002, 8081):" Red
    $PORT_WIZARD = Read-Host "Puerto para el setup wizard"
}

$PORT_DNS = Read-Host "Puerto DNS (default: 53)"
if ([string]::IsNullOrEmpty($PORT_DNS)) { $PORT_DNS = "53" }

$PORT_HTTPS = Read-Host "Puerto HTTPS (default: 443, deja vacio para omitir)"

$ADMIN_USER = Read-Host "Nombre de usuario admin"
while ([string]::IsNullOrEmpty($ADMIN_USER)) {
    Write-Color "El nombre de usuario no puede estar vacio." Red
    $ADMIN_USER = Read-Host "Nombre de usuario admin"
}

$ADMIN_PASS = Read-Host "Contrasena admin" -AsSecureString
$ADMIN_PASS_plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADMIN_PASS)
)
while ([string]::IsNullOrEmpty($ADMIN_PASS_plain)) {
    Write-Color "La contrasena no puede estar vacia." Red
    $ADMIN_PASS = Read-Host "Contrasena admin" -AsSecureString
    $ADMIN_PASS_plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADMIN_PASS)
    )
}

$DNS_UPSTREAM = Read-Host "Upstream DNS (default: https://dns.quad9.net/dns-query)"
if ([string]::IsNullOrEmpty($DNS_UPSTREAM)) { $DNS_UPSTREAM = "https://dns.quad9.net/dns-query" }

Write-Host ""
Write-Color "Resumen de configuracion:" Yellow
Write-Color "  Dashboard:    http://localhost:$PORT_DASHBOARD" Green
Write-Color "  Setup wizard: http://localhost:$PORT_WIZARD" Green
Write-Color "  DNS:          $PORT_DNS" Green
Write-Color "  Admin user:   $ADMIN_USER" Green
Write-Color "  DNS upstream: $DNS_UPSTREAM" Green
Write-Host ""

$CONFIRM = Read-Host "Continuar? (s/n)"
if ($CONFIRM -ne "s" -and $CONFIRM -ne "S") {
    Write-Host "Instalacion cancelada."
    exit 0
}

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$WORKDIR = Join-Path $SCRIPT_DIR "workdir"
$CONFDIR = Join-Path $SCRIPT_DIR "confdir"

New-Item -ItemType Directory -Force -Path $WORKDIR | Out-Null
New-Item -ItemType Directory -Force -Path $CONFDIR | Out-Null

# Generar hash de contrasena (compatible con AdGuard)
$SecureStringAsPlainText = $ADMIN_PASS_plain
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ADMIN_PASS)
$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Usarhtpasswd si esta disponible, sino dejar vacio para configurar via wizard
$PASS_HASH = ""
try {
    $PASS_HASH = & htpasswd -Bbn $ADMIN_USER $ADMIN_PASS_plain 2>$null | ForEach-Object { ($_ -split ":", 2)[1] }
} catch {}

$CREATE_USER = $false
if (-not [string]::IsNullOrEmpty($PASS_HASH)) {
    $CREATE_USER = $true
}

# Crear docker-compose.yml
$composeContent = @"
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
"@

if (-not [string]::IsNullOrEmpty($PORT_HTTPS)) {
    $composeContent += "`n      - `"${PORT_HTTPS}:443/tcp`""
}

$composeContent += @"

    volumes:
      - "./workdir:/opt/adguardhome/work"
      - "./confdir:/opt/adguardhome/conf"
    cap_add:
      - NET_ADMIN
"@

$composeContent | Out-File -FilePath (Join-Path $SCRIPT_DIR "docker-compose.yml") -Encoding UTF8
Write-Color "docker-compose.yml creado" Green

# Crear configuracion si hay usuario
if ($CREATE_USER) {
    $yamlContent = @"
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
  - name: $ADMIN_USER
    password: $PASS_HASH
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
    - $DNS_UPSTREAM
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
"@

    $yamlContent | Out-File -FilePath (Join-Path $CONFDIR "AdGuardHome.yaml") -Encoding UTF8
    Write-Color "AdGuardHome.yaml creado con usuario $ADMIN_USER" Green
} else {
    Write-Color "Sin preconfiguracion de usuario. Usa el wizard en http://localhost:$PORT_WIZARD" Yellow
}

Write-Host ""
Write-Color "Iniciando AdGuard Home..." Yellow
Set-Location $SCRIPT_DIR
docker compose up -d

Write-Host ""
Write-Color "========================================" Green
Write-Color "    AdGuard Home instalado!" Green
Write-Color "========================================" Green
Write-Host ""
if ($CREATE_USER) {
    Write-Color "  Dashboard: http://localhost:$PORT_DASHBOARD" Cyan
    Write-Color "  Usuario:   $ADMIN_USER" Cyan
} else {
    Write-Color "  Setup wizard: http://localhost:$PORT_WIZARD" Cyan
    Write-Color "  Dashboard:    http://localhost:$PORT_DASHBOARD (despues del wizard)" Cyan
}
Write-Host ""
Write-Color "  DNS server: localhost:$PORT_DNS" Cyan
Write-Host ""
Write-Color "  Logs: docker compose logs -f" Gray
Write-Color "  Stop: docker compose stop" Gray
Write-Color "  Start: docker compose start" Gray
Write-Color "  Restart: docker compose restart" Gray
Write-Host ""
