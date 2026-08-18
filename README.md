# AdGuard Home - Instalador Docker

Servidor DNS con bloqueo de anuncios para toda la red doméstica.

## Requisitos previos

| Sistema | Docker | Docker Compose |
|---------|--------|----------------|
| **Linux** | [Instalar Docker](https://docs.docker.com/engine/install/) | Viene incluido con Docker Desktop o instalar `docker-compose` |
| **Mac** | [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) | Incluido |
| **Windows** | [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) | Incluido |

## Instalación rápida

### Linux / Mac

```bash
chmod +x install.sh
./install.sh
```

### Windows (PowerShell)

```powershell
.\install.sh
```

> **Nota:** En Windows necesitas WSL2 habilitado y Docker Desktop configurado para usar WSL2.

## Puertos sugeridos

El instalador te preguntará por los puertos. Aquí van recomendaciones:

| Servicio | Puerto sugerido | Descripción |
|----------|----------------|-------------|
| Dashboard | `8080` | Interfaz web principal |
| Setup Wizard | `3001` | Asistente de configuración inicial |
| DNS | `53` | Resolución de nombres (estándar) |
| HTTPS | `443` | Opcional, para DNS sobre HTTPS |

> **Importante:** Evita usar los puertos **3000** y **80** si ya están ocupados.

## Después de la instalación

### Acceder al dashboard

```
http://localhost:8080
```

### Comandos útiles

```bash
# Ver logs en tiempo real
docker compose logs -f

# Detener AdGuard
docker compose stop

# Iniciar AdGuard
docker compose start

# Reiniciar
docker compose restart

# Detener y eliminar contenedor
docker compose down
```

## Configurar tus dispositivos

Una vez instalado, configura tu router o dispositivos para usar AdGuard como DNS:

1. Abre el dashboard: `http://localhost:8080`
2. Ve a **Settings** → **DNS settings**
3. Configura el DNS upstream (Quad9, Cloudflare, etc.)
4. En tu router o dispositivos, cambia el DNS a la IP de tu servidor

### En Mac

**Preferencias del Sistema** → **Red** → **Avanzado** → **DNS** → Agregar `IP_DEL_SERVIDOR`

### En Windows

**Configuración** → **Red e Internet** → **Propiedades del adaptador** → **DNS** → Manual → Agregar `IP_DEL_SERVIDOR`

### En Linux

Edita `/etc/resolv.conf` o configura NetworkManager:

```bash
# Usando nmcli
nmcli con mod "TuConexion" ipv4.dns "IP_DEL_SERVIDOR"
nmcli con mod "TuConexion" ipv4.ignore-auto-dns yes
```

## Estructura de archivos

```
adguard/
├── install.sh          # Script de instalación
├── docker-compose.yml  # Generado por install.sh
├── workdir/            # Datos de AdGuard (generado)
└── confdir/            # Configuración (generado)
```

## Solución de problemas

### El puerto 53 ya está ocupado

```bash
# En Mac/Linux, desactiva el DNS stub del sistema:
sudo mkdir -p /etc/systemd/resolved.conf.d
echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf.d/no-stub.conf
sudo systemctl restart systemd-resolved
```

### No puedo acceder al dashboard

1. Verifica que el contenedor esté corriendo: `docker ps`
2. Revisa los logs: `docker compose logs`
3. Asegúrate de que el puerto no esté bloqueado por un firewall

### El DNS no resuelve

1. Verifica que el puerto 53 esté libre: `lsof -i :53` (Mac/Linux)
2. Asegúrate de que AdGuard esté usando los DNS upstream correctos

## Licencia

MIT
