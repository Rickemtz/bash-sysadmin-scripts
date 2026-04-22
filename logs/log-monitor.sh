#!/usr/bin/env bash
# =============================================================================
# log-monitor.sh — Monitoreo y análisis de /var/log/syslog
# Uso: ./log-monitor.sh [--tail N] [--errors] [--report]
# =============================================================================

set -euo pipefail

LOG_FILE="/var/log/syslog"
REPORT_DIR="$HOME/.sysadmin/reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TAIL_LINES=50
MODE="tail"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'

usage() {
    echo "Uso: $0 [--tail N] [--errors] [--report]"
    echo "  --tail N    Mostrar las últimas N líneas (default: 50)"
    echo "  --errors    Filtrar solo errores y warnings"
    echo "  --report    Generar reporte resumido en $REPORT_DIR"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tail) TAIL_LINES="$2"; shift 2 ;;
            --errors) MODE="errors" ;;
            --report) MODE="report" ;;
            --help|-h) usage ;;
            *) echo "Opción desconocida: $1"; usage ;;
        esac
        shift 2>/dev/null || break
    done
}

check_permissions() {
    if [[ ! -r "$LOG_FILE" ]]; then
        echo -e "${RED}[ERROR]${NC} Sin permisos para leer $LOG_FILE. Intenta con sudo."
        exit 1
    fi
}

show_tail() {
    echo -e "${GREEN}=== Últimas $TAIL_LINES líneas de $LOG_FILE ===${NC}"
    tail -n "$TAIL_LINES" "$LOG_FILE"
}

show_errors() {
    echo -e "${RED}=== Errores y Warnings en $LOG_FILE ===${NC}"
    echo ""
    echo -e "${YELLOW}-- ERRORES --${NC}"
    grep -i "error\|fail\|critical" "$LOG_FILE" | tail -n 30 || echo "Sin errores recientes."
    echo ""
    echo -e "${YELLOW}-- WARNINGS --${NC}"
    grep -i "warn" "$LOG_FILE" | tail -n 20 || echo "Sin warnings recientes."
}

generate_report() {
    mkdir -p "$REPORT_DIR"
    REPORT="$REPORT_DIR/syslog_report_$TIMESTAMP.txt"

    {
        echo "========================================"
        echo "  REPORTE DE SYSLOG — $(date)"
        echo "========================================"
        echo ""
        echo "--- RESUMEN ---"
        echo "Total de líneas:   $(wc -l < "$LOG_FILE")"
        echo "Errores:           $(grep -ci "error" "$LOG_FILE" || true)"
        echo "Warnings:          $(grep -ci "warn" "$LOG_FILE" || true)"
        echo "Fallos críticos:   $(grep -ci "critical\|fail" "$LOG_FILE" || true)"
        echo ""
        echo "--- SERVICIOS CON MÁS EVENTOS ---"
        grep -oP '(?<=\] )\S+(?=\[)' "$LOG_FILE" 2>/dev/null \
            | sort | uniq -c | sort -rn | head -10 || true
        echo ""
        echo "--- ÚLTIMOS 10 ERRORES ---"
        grep -i "error" "$LOG_FILE" | tail -n 10 || echo "Sin errores."
        echo ""
        echo "========================================"
        echo "  Reporte generado por log-monitor.sh"
        echo "========================================"
    } > "$REPORT"

    echo -e "${GREEN}[OK]${NC} Reporte generado: $REPORT"
    cat "$REPORT"
}

main() {
    parse_args "$@"
    check_permissions

    case "$MODE" in
        tail)   show_tail ;;
        errors) show_errors ;;
        report) generate_report ;;
    esac
}

main "$@"
