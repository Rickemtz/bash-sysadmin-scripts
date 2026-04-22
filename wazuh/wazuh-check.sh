#!/usr/bin/env bash
# =============================================================================
# wazuh-check.sh — Health check de agentes y manager Wazuh
# Uso: ./wazuh-check.sh [--status] [--agents] [--logs] [--report]
# =============================================================================

set -euo pipefail

WAZUH_DIR="/var/ossec"
WAZUH_LOG="$WAZUH_DIR/logs/ossec.log"
WAZUH_AGENT_LIST="$WAZUH_DIR/bin/agent_control"
REPORT_DIR="$HOME/.sysadmin/wazuh-reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

usage() {
    echo "Uso: $0 [OPCIÓN]"
    echo ""
    echo "  --status    Estado del manager y servicios Wazuh"
    echo "  --agents    Listar agentes y su estado de conexión"
    echo "  --logs      Últimos eventos críticos en ossec.log"
    echo "  --report    Generar reporte completo"
    exit 0
}

check_wazuh_installed() {
    if [[ ! -d "$WAZUH_DIR" ]]; then
        echo -e "${RED}[ERROR]${NC} Wazuh no encontrado en $WAZUH_DIR"
        exit 1
    fi
}

show_status() {
    echo -e "${CYAN}=== Estado de servicios Wazuh ===${NC}"
    echo ""
    local services=("wazuh-manager" "wazuh-agent" "wazuh-indexer" "wazuh-dashboard")
    for svc in "${services[@]}"; do
        if systemctl list-units --type=service 2>/dev/null | grep -q "$svc"; then
            local status; status=$(systemctl is-active "$svc" 2>/dev/null || echo "inactivo")
            if [[ "$status" == "active" ]]; then
                echo -e "  ${GREEN}●${NC} $svc — $status"
            else
                echo -e "  ${RED}●${NC} $svc — $status"
            fi
        fi
    done

    echo ""
    echo -e "${CYAN}--- Procesos Wazuh activos ---${NC}"
    pgrep -la "ossec\|wazuh" 2>/dev/null || echo "  Sin procesos detectados."
}

list_agents() {
    echo -e "${CYAN}=== Agentes registrados ===${NC}"
    echo ""
    if [[ -x "$WAZUH_AGENT_LIST" ]]; then
        "$WAZUH_AGENT_LIST" -l 2>/dev/null || echo "  Sin agentes o sin permisos."
    else
        echo -e "${YELLOW}[INFO]${NC} agent_control no disponible. Leyendo base de datos local..."
        if [[ -f "$WAZUH_DIR/var/db/agents.db" ]]; then
            sqlite3 "$WAZUH_DIR/var/db/agents.db" \
                "SELECT id, name, ip, connection_status, last_keepalive FROM agent ORDER BY id;" \
                2>/dev/null | column -t -s '|' || echo "  Sin datos disponibles."
        else
            echo "  Base de datos de agentes no encontrada."
        fi
    fi
}

show_logs() {
    echo -e "${CYAN}=== Eventos críticos recientes (ossec.log) ===${NC}"
    echo ""
    if [[ ! -f "$WAZUH_LOG" ]]; then
        echo -e "${RED}[ERROR]${NC} Log no encontrado: $WAZUH_LOG"
        return
    fi

    echo -e "${RED}-- Errores --${NC}"
    grep -i "error\|critical" "$WAZUH_LOG" | tail -n 15 || echo "  Sin errores recientes."

    echo ""
    echo -e "${YELLOW}-- Warnings --${NC}"
    grep -i "warn" "$WAZUH_LOG" | tail -n 10 || echo "  Sin warnings."

    echo ""
    echo -e "${GREEN}-- Últimas 10 líneas del log --${NC}"
    tail -n 10 "$WAZUH_LOG"
}

generate_report() {
    mkdir -p "$REPORT_DIR"
    local report="$REPORT_DIR/wazuh_report_$TIMESTAMP.txt"

    {
        echo "========================================"
        echo "  REPORTE WAZUH — $(date)"
        echo "========================================"
        echo ""
        show_status
        echo ""
        list_agents
        echo ""
        show_logs
        echo ""
        echo "========================================"
        echo "  Generado por wazuh-check.sh"
        echo "========================================"
    } > "$report" 2>&1

    echo -e "${GREEN}[OK]${NC} Reporte guardado en: $report"
    cat "$report"
}

main() {
    check_wazuh_installed
    [[ $# -eq 0 ]] && { show_status; exit 0; }

    case "$1" in
        --status)  show_status ;;
        --agents)  list_agents ;;
        --logs)    show_logs ;;
        --report)  generate_report ;;
        --help|-h) usage ;;
        *)         echo "Opción desconocida: $1"; usage ;;
    esac
}

main "$@"
