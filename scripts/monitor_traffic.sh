#!/usr/bin/env bash
# ============================================================
# monitor_traffic.sh — Monitor de tráfego em tempo real
# Cobre: rede geral, IMAP, Docker/WA Proxy, HTTP/HTTPS, DNS
# Uso: chmod +x monitor_traffic.sh && ./monitor_traffic.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

LOG_DIR="$HOME/ai-infra/traffic_logs"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

banner() {
  echo -e "${BOLD}${CYAN}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║       MONITOR DE TRÁFEGO EM TEMPO REAL               ║"
  echo "║  Selecione o modo de monitoramento desejado          ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

menu() {
  echo -e "${BOLD}Escolha o modo:${NC}"
  echo -e " ${GREEN}1)${NC} 🌐  Tráfego geral — todos os pacotes (nettop)"
  echo -e " ${GREEN}2)${NC} 📧  IMAP — iCloud Mail porta 993 (tcpdump)"
  echo -e " ${GREEN}3)${NC} 🐳  Docker / WhatsApp Proxy (tcpdump portas 80/443/5222/8080/8443)"
  echo -e " ${GREEN}4)${NC} 🔍  HTTP/HTTPS por processo (mitmproxy interativo)"
  echo -e " ${GREEN}5)${NC} 🔎  DNS — domínios consultados em tempo real (tcpdump)"
  echo -e " ${GREEN}6)${NC} 📊  Conexões ativas agora (netstat + lsof)"
  echo -e " ${GREEN}7)${NC} 🚀  TUDO — abre abas separadas no Terminal (recomendado)"
  echo -e " ${GREEN}0)${NC} ❌  Sair"
  echo ""
}

check_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo -e "${YELLOW}⚠️  tcpdump requer sudo. Autentique-se:${NC}"
    sudo -v
  fi
}

# --- Modos individuais ---

mode_general() {
  echo -e "${CYAN}▶ Iniciando monitor geral de rede (nettop)...${NC}"
  echo -e "${YELLOW}  Pressione 'q' para sair | 's' para ordenar | 'h' para ajuda${NC}\n"
  nettop -P -k rx_dupe,rx_ooo,net_snd_wnd -t wifi -t wired
}

mode_imap() {
  check_sudo
  local logfile="$LOG_DIR/imap_${TIMESTAMP}.pcap"
  echo -e "${CYAN}▶ Capturando tráfego IMAP (porta 993) — iCloud Mail...${NC}"
  echo -e "${YELLOW}  Log salvo em: $logfile${NC}"
  echo -e "${YELLOW}  Pressione Ctrl+C para parar\n${NC}"
  sudo tcpdump -i any -w "$logfile" \
    'tcp port 993' \
    2>/dev/null &
  # Exibe em tempo real no terminal também
  sudo tcpdump -i any -l -A -nn \
    'tcp port 993' 2>/dev/null | grep --color=always -E "WROTE|READ|OK|BAD|IDLE|EXPUNGE|LOGIN|AUTH|host:|."
}

mode_docker() {
  check_sudo
  local logfile="$LOG_DIR/docker_proxy_${TIMESTAMP}.pcap"
  echo -e "${CYAN}▶ Capturando tráfego Docker/WhatsApp Proxy...${NC}"
  echo -e "${YELLOW}  Portas: 80, 443, 5222, 8080, 8443, 8222, 8199${NC}"
  echo -e "${YELLOW}  Log salvo em: $logfile${NC}"
  echo -e "${YELLOW}  Pressione Ctrl+C para parar\n${NC}"
  sudo tcpdump -i any -w "$logfile" \
    'tcp port 80 or tcp port 443 or tcp port 5222 or tcp port 8080 or tcp port 8443 or tcp port 8222 or tcp port 8199' \
    2>/dev/null &
  # Exibe resumo em tempo real
  sudo tcpdump -i any -l -nn -q \
    'tcp port 80 or tcp port 443 or tcp port 5222 or tcp port 8080 or tcp port 8443 or tcp port 8222 or tcp port 8199' \
    2>/dev/null | awk '{print strftime("[%H:%M:%S]"), $0}'
}

mode_http_proxy() {
  echo -e "${CYAN}▶ Iniciando mitmproxy para captura HTTP/HTTPS...${NC}"
  echo -e "${YELLOW}  Configure seu app/sistema para usar proxy: 127.0.0.1:8080${NC}"
  echo -e "${YELLOW}  Instale o certificado CA do mitmproxy se necessário${NC}"
  echo -e "${YELLOW}  Pressione 'q' para sair do mitmproxy\n${NC}"
  mitmproxy \
    --set flow_detail=3 \
    --set console_layout=horizontal \
    --save-stream-file "$LOG_DIR/http_${TIMESTAMP}.mitm"
}

mode_dns() {
  check_sudo
  local logfile="$LOG_DIR/dns_${TIMESTAMP}.log"
  echo -e "${CYAN}▶ Monitorando consultas DNS em tempo real...${NC}"
  echo -e "${YELLOW}  Log salvo em: $logfile${NC}"
  echo -e "${YELLOW}  Pressione Ctrl+C para parar\n${NC}"
  sudo tcpdump -i any -l -nn \
    'udp port 53 or tcp port 53' 2>/dev/null \
    | tee "$logfile" \
    | awk '
      /A\?/ || /AAAA\?/ || /CNAME\?/ || /MX\?/ {
        match($0, /[A-Za-z0-9._-]+\?/, arr)
        if (arr[0]) printf "\033[0;36m[DNS]\033[0m %s → %s\n", strftime("%H:%M:%S"), arr[0]
      }
    '
}

mode_connections() {
  echo -e "${CYAN}▶ Conexões TCP ativas agora:${NC}\n"
  echo -e "${BOLD}── netstat (ESTABLISHED) ──────────────────────────────${NC}"
  netstat -an | grep ESTABLISHED | awk '{print $4, "→", $5}' | sort -u | head -50

  echo -e "\n${BOLD}── lsof — processos e conexões de rede ───────────────${NC}"
  sudo lsof -i -n -P 2>/dev/null | grep -E "ESTABLISHED|LISTEN" | \
    awk '{printf "%-25s %-8s %s\n", $1, $2, $9}' | sort -u | head -50

  echo -e "\n${BOLD}── Docker — portas expostas ───────────────────────────${NC}"
  docker ps --format "table {{.Names}}\t{{.Ports}}" 2>/dev/null || echo "Docker não rodando"
}

mode_all() {
  echo -e "${CYAN}▶ Abrindo monitoramento completo em abas do Terminal...${NC}\n"
  osascript <<'APPLESCRIPT'
    tell application "Terminal"
      activate
      -- Aba 1: Monitor geral
      do script "echo '🌐 MONITOR GERAL'; nettop -P -t wifi -t wired"
      -- Aba 2: DNS
      do script "echo '🔎 DNS'; sudo tcpdump -i any -l -nn 'udp port 53' 2>/dev/null | awk '/A\\?/{print strftime(\"[%H:%M:%S]\"), $0}'"
      -- Aba 3: IMAP
      do script "echo '📧 IMAP 993'; sudo tcpdump -i any -l -nn -q 'tcp port 993' 2>/dev/null"
      -- Aba 4: Docker/Proxy
      do script "echo '🐳 DOCKER/PROXY'; sudo tcpdump -i any -l -nn -q 'tcp port 80 or tcp port 443 or tcp port 5222 or tcp port 8080 or tcp port 8443' 2>/dev/null"
      -- Aba 5: Conexões ativas (refresh a cada 3s)
      do script "echo '📊 CONEXOES ATIVAS'; while true; do clear; netstat -an | grep ESTABLISHED | head -30; sleep 3; done"
    end tell
APPLESCRIPT
  echo -e "${GREEN}✅ 5 abas abertas no Terminal!${NC}"
}

# --- Main ---
banner
while true; do
  menu
  read -rp "$(echo -e "${BOLD}Opção:${NC} ")" choice
  echo ""
  case "$choice" in
    1) mode_general ;;
    2) mode_imap ;;
    3) mode_docker ;;
    4) mode_http_proxy ;;
    5) mode_dns ;;
    6) mode_connections ;;
    7) mode_all ;;
    0) echo -e "${GREEN}Saindo...${NC}"; exit 0 ;;
    *) echo -e "${RED}Opção inválida${NC}\n" ;;
  esac
  echo -e "\n${YELLOW}Pressione Enter para voltar ao menu...${NC}"
  read -r
  clear
  banner
done
