#!/usr/bin/env bash
# =============================================================================
# sftp-backup.sh — Backup automatizado con rsync + rotación local
# Uso: ./sftp-backup.sh [--config FILE] [--dry-run] [--restore FECHA]
# =============================================================================

set -euo pipefail

# --- CONFIG DEFAULT (sobreescribible con --config) ---
BACKUP_NAME="backup"
SOURCE_DIRS=("/etc" "/home" "/var/log")
BACKUP_ROOT="/var/backups/sysadmin"
RETENTION_DAYS=30
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="$BACKUP_ROOT/${BACKUP_NAME}_$TIMESTAMP"
LOG_FILE="$BACKUP_ROOT/backup.log"
DRY_RUN=false

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

log() {
    local level="$1"; shift
    local msg="$*"
    local ts; ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}

usage() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "  --config FILE     Cargar configuración desde archivo"
    echo "  --dry-run         Simular backup sin escribir archivos"
    echo "  --list            Listar backups disponibles"
    echo "  --restore FECHA   Restaurar backup de una fecha (formato: YYYYMMDD)"
    echo "  --clean           Eliminar backups con más de $RETENTION_DAYS días"
    exit 0
}

load_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        echo -e "${RED}[ERROR]${NC} Archivo de configuración no encontrado: $config_file"
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$config_file"
    log "INFO" "Configuración cargada desde: $config_file"
}

check_space() {
    local available; available=$(df -BM "$BACKUP_ROOT" 2>/dev/null | awk 'NR==2 {gsub("M",""); print $4}' || echo 0)
    if [[ "$available" -lt 500 ]]; then
        log "WARN" "Espacio disponible bajo en $BACKUP_ROOT: ${available}MB"
    fi
}

run_backup() {
    mkdir -p "$BACKUP_DIR" "$BACKUP_ROOT"
    log "INFO" "Iniciando backup → $BACKUP_DIR"

    local rsync_opts=(-avh --delete --exclude='*.tmp' --exclude='*.cache')
    $DRY_RUN && rsync_opts+=(--dry-run)

    local success=0 failed=0
    for src in "${SOURCE_DIRS[@]}"; do
        if [[ ! -d "$src" ]]; then
            log "WARN" "Directorio no encontrado, omitiendo: $src"
            ((failed++)); continue
        fi
        local dest="$BACKUP_DIR$(dirname "$src")"
        mkdir -p "$dest"
        if rsync "${rsync_opts[@]}" "$src" "$dest/" >> "$LOG_FILE" 2>&1; then
            log "INFO" "OK → $src"
            ((success++))
        else
            log "ERROR" "Falló → $src"
            ((failed++))
        fi
    done

    local size; size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 || echo "N/A")
    log "INFO" "Backup completado. Exitosos: $success | Fallidos: $failed | Tamaño: $size"

    if ! $DRY_RUN; then
        echo "$TIMESTAMP" > "$BACKUP_ROOT/latest.txt"
        log "INFO" "Referencia 'latest' actualizada."
    fi
}

list_backups() {
    echo -e "${CYAN}=== Backups disponibles en $BACKUP_ROOT ===${NC}"
    echo ""
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        echo "  Sin backups encontrados."
        return
    fi
    printf "%-35s %10s %s\n" "NOMBRE" "TAMAÑO" "FECHA"
    echo "------------------------------------------------------------"
    find "$BACKUP_ROOT" -maxdepth 1 -type d -name "${BACKUP_NAME}_*" \
        | sort -r \
        | while read -r dir; do
            local name; name=$(basename "$dir")
            local size; size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local date_raw; date_raw=$(echo "$name" | grep -oP '\d{8}')
            local date_fmt; date_fmt=$(date -d "$date_raw" '+%d/%m/%Y' 2>/dev/null || echo "$date_raw")
            printf "%-35s %10s %s\n" "$name" "$size" "$date_fmt"
        done
}

restore_backup() {
    local fecha="$1"
    local target; target=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "${BACKUP_NAME}_${fecha}*" | head -1)
    if [[ -z "$target" ]]; then
        echo -e "${RED}[ERROR]${NC} No se encontró backup para la fecha: $fecha"
        exit 1
    fi
    echo -e "${YELLOW}ADVERTENCIA:${NC} Se restaurará desde: $target"
    read -rp "¿Confirmar restauración? (s/N): " confirm
    [[ ! "$confirm" =~ ^[sS]$ ]] && { echo "Cancelado."; exit 0; }
    rsync -avh --delete "$target/" / >> "$LOG_FILE" 2>&1
    log "INFO" "Restauración completada desde: $target"
}

clean_old() {
    echo -e "${YELLOW}Eliminando backups con más de $RETENTION_DAYS días...${NC}"
    local count=0
    find "$BACKUP_ROOT" -maxdepth 1 -type d -name "${BACKUP_NAME}_*" -mtime "+$RETENTION_DAYS" \
        | while read -r old; do
            rm -rf "$old"
            log "INFO" "Eliminado: $old"
            ((count++))
        done
    echo -e "${GREEN}[OK]${NC} Limpieza completada."
}

main() {
    mkdir -p "$BACKUP_ROOT"

    [[ $# -eq 0 ]] && { run_backup; exit 0; }

    case "$1" in
        --config)   load_config "${2:-}"; run_backup ;;
        --dry-run)  DRY_RUN=true; run_backup ;;
        --list)     list_backups ;;
        --restore)  [[ -z "${2:-}" ]] && usage; restore_backup "$2" ;;
        --clean)    clean_old ;;
        --help|-h)  usage ;;
        *)          echo "Opción desconocida: $1"; usage ;;
    esac
}

main "$@"
