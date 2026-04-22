# bash-sysadmin-scripts 🛠️

Colección de scripts Bash para administración de sistemas Linux en entornos productivos.  
Desarrollados y usados en producción como parte de mi rol como **SysAdmin Linux Jr**.

---

## 📂 Estructura

```
bash-sysadmin-scripts/
├── logs/
│   └── log-monitor.sh        # Monitoreo y análisis de /var/log/syslog
├── users/
│   └── user-audit.sh         # Gestión y auditoría de usuarios Linux
├── backup/
│   └── sftp-backup.sh        # Backup automatizado con rsync + rotación
└── wazuh/
    └── wazuh-check.sh        # Health check de agentes y manager Wazuh
```

---

## 🔧 Scripts

### `logs/log-monitor.sh` — Monitoreo de syslog

Analiza `/var/log/syslog` con opciones para filtrar errores o generar reportes.

```bash
chmod +x logs/log-monitor.sh

./logs/log-monitor.sh             # Últimas 50 líneas
./logs/log-monitor.sh --tail 100  # Últimas N líneas
./logs/log-monitor.sh --errors    # Solo errores y warnings
./logs/log-monitor.sh --report    # Reporte en ~/.sysadmin/reports/
```

---

### `users/user-audit.sh` — Gestión y auditoría de usuarios

Audita usuarios del sistema, privilegios sudo y gestión de grupos. Requiere root para operaciones de escritura.

```bash
chmod +x users/user-audit.sh

./users/user-audit.sh --audit          # Listar usuarios del sistema
./users/user-audit.sh --sudo           # Auditar acceso sudo (root)
./users/user-audit.sh --add usuario    # Crear usuario (root)
./users/user-audit.sh --del usuario    # Eliminar usuario (root)
./users/user-audit.sh --groups usuario # Ver grupos de un usuario
./users/user-audit.sh --inactive       # Usuarios sin login en 90 días (root)
```

Todas las acciones de escritura quedan registradas en `~/.sysadmin/user-audit.log`.

---

### `backup/sftp-backup.sh` — Backup con rsync

Realiza backups locales de directorios críticos con rotación automática.

```bash
chmod +x backup/sftp-backup.sh

./backup/sftp-backup.sh               # Backup con config default
./backup/sftp-backup.sh --dry-run     # Simular sin escribir
./backup/sftp-backup.sh --list        # Ver backups disponibles
./backup/sftp-backup.sh --restore YYYYMMDD  # Restaurar por fecha
./backup/sftp-backup.sh --clean       # Eliminar backups viejos (>30 días)
```

**Directorios respaldados por default:** `/etc`, `/home`, `/var/log`  
**Destino:** `/var/backups/sysadmin/`

---

### `wazuh/wazuh-check.sh` — Health check Wazuh

Verifica el estado del manager, agentes y eventos críticos en entornos con Wazuh SIEM/XDR.

```bash
chmod +x wazuh/wazuh-check.sh

./wazuh/wazuh-check.sh             # Estado de servicios
./wazuh/wazuh-check.sh --status    # Estado detallado
./wazuh/wazuh-check.sh --agents    # Estado de agentes registrados
./wazuh/wazuh-check.sh --logs      # Eventos críticos en ossec.log
./wazuh/wazuh-check.sh --report    # Reporte completo en ~/.sysadmin/wazuh-reports/
```

---

## ⚙️ Requisitos

| Herramienta | Uso |
|---|---|
| `bash >= 4.0` | Todos los scripts |
| `rsync` | sftp-backup.sh |
| `systemctl` | wazuh-check.sh |
| `lastlog` | user-audit.sh |
| `sqlite3` | wazuh-check.sh (opcional) |

---

## 🚀 Instalación rápida

```bash
git clone https://github.com/Rickemtz/bash-sysadmin-scripts.git
cd bash-sysadmin-scripts
chmod +x **/*.sh
```

---

## ⚠️ Notas

- Los scripts de gestión de usuarios y backup requieren `sudo` o usuario `root`.
- Adapta las rutas en `sftp-backup.sh` (`SOURCE_DIRS`, `BACKUP_ROOT`) según tu entorno.
- `wazuh-check.sh` asume instalación estándar de Wazuh en `/var/ossec`.

---

*Erick Martínez — [@Rickemtz](https://github.com/Rickemtz)*
