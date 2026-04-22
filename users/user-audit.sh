#!/usr/bin/env bash
# =============================================================================
# user-audit.sh — Gestión y auditoría de usuarios Linux
# Uso: ./user-audit.sh [--audit] [--sudo] [--add USER] [--del USER] [--groups USER]
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
AUDIT_LOG="$HOME/.sysadmin/user-audit.log"

log_action() {
    mkdir -p "$(dirname "$AUDIT_LOG")"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $(whoami) → $*" >> "$AUDIT_LOG"
}

usage() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "  --audit           Listar todos los usuarios del sistema"
    echo "  --sudo            Auditar usuarios con privilegios sudo"
    echo "  --add USER        Crear nuevo usuario"
    echo "  --del USER        Eliminar usuario (con confirmación)"
    echo "  --groups USER     Ver grupos de un usuario"
    echo "  --inactive        Listar usuarios sin login reciente (90 días)"
    exit 0
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}[ERROR]${NC} Este comando requiere privilegios root."
        exit 1
    fi
}

audit_users() {
    echo -e "${CYAN}=== Usuarios del sistema ===${NC}"
    echo ""
    printf "%-20s %-6s %-20s %s\n" "USUARIO" "UID" "SHELL" "ÚLTIMO LOGIN"
    echo "------------------------------------------------------------------------"
    while IFS=: read -r user _ uid _ _ _ shell; do
        if [[ "$uid" -ge 1000 && "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
            last_login=$(lastlog -u "$user" 2>/dev/null | awk 'NR==2 {if ($2=="**Never") print "Nunca"; else print $4,$5,$6,$7,$8}' || echo "N/A")
            printf "%-20s %-6s %-20s %s\n" "$user" "$uid" "$shell" "$last_login"
        fi
    done < /etc/passwd
}

audit_sudo() {
    echo -e "${YELLOW}=== Usuarios con acceso sudo ===${NC}"
    echo ""
    echo -e "${YELLOW}-- Grupo sudo/wheel --${NC}"
    getent group sudo wheel 2>/dev/null | awk -F: '{print $4}' | tr ',' '\n' | sort -u | grep -v '^$' || echo "  (vacío)"
    echo ""
    echo -e "${YELLOW}-- Entradas en /etc/sudoers --${NC}"
    grep -v "^#\|^$\|^Defaults\|^%" /etc/sudoers 2>/dev/null || echo "  Sin entradas individuales."
    echo ""
    echo -e "${YELLOW}-- Archivos en /etc/sudoers.d/ --${NC}"
    ls /etc/sudoers.d/ 2>/dev/null || echo "  (vacío)"
    log_action "Auditoría sudo ejecutada"
}

add_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} El usuario '$username' ya existe."
        exit 1
    fi
    echo -e "${GREEN}Creando usuario: $username${NC}"
    read -rp "¿Agregar al grupo sudo? (s/N): " sudo_confirm
    useradd -m -s /bin/bash "$username"
    passwd "$username"
    if [[ "$sudo_confirm" =~ ^[sS]$ ]]; then
        usermod -aG sudo "$username"
        echo -e "${GREEN}[OK]${NC} '$username' agregado al grupo sudo."
    fi
    echo -e "${GREEN}[OK]${NC} Usuario '$username' creado correctamente."
    log_action "Usuario creado: $username"
}

del_user() {
    local username="$1"
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} El usuario '$username' no existe."
        exit 1
    fi
    echo -e "${RED}ADVERTENCIA:${NC} Esto eliminará al usuario '$username' y su directorio home."
    read -rp "¿Confirmar eliminación? Escribe el nombre de usuario: " confirm
    if [[ "$confirm" != "$username" ]]; then
        echo "Cancelado."
        exit 0
    fi
    userdel -r "$username" 2>/dev/null || userdel "$username"
    echo -e "${GREEN}[OK]${NC} Usuario '$username' eliminado."
    log_action "Usuario eliminado: $username"
}

show_groups() {
    local username="$1"
    if ! id "$username" &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Usuario '$username' no encontrado."
        exit 1
    fi
    echo -e "${CYAN}=== Grupos de '$username' ===${NC}"
    id "$username"
    echo ""
    groups "$username"
}

inactive_users() {
    echo -e "${YELLOW}=== Usuarios sin login en los últimos 90 días ===${NC}"
    lastlog --time 90 2>/dev/null | grep -v "^Usuario\|^Username\|Never logged" || echo "Sin usuarios inactivos."
}

main() {
    [[ $# -eq 0 ]] && usage

    case "$1" in
        --audit)    audit_users ;;
        --sudo)     check_root; audit_sudo ;;
        --add)      check_root; [[ -z "${2:-}" ]] && usage; add_user "$2" ;;
        --del)      check_root; [[ -z "${2:-}" ]] && usage; del_user "$2" ;;
        --groups)   [[ -z "${2:-}" ]] && usage; show_groups "$2" ;;
        --inactive) check_root; inactive_users ;;
        --help|-h)  usage ;;
        *)          echo "Opción desconocida: $1"; usage ;;
    esac
}

main "$@"
