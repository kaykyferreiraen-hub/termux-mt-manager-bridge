#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  SAF → MT Manager Bridge  (FTP server for Termux $HOME)
#  Requires: python3.13 -m pip install pyftpdlib
# ============================================================

# ---------- Config ------------------------------------------
HOST="127.0.0.1"
PORT="8021"
ROOT_DIR="$HOME"
LOGFILE="$HOME/.saf-mt-manager.log"
PIDFILE="$HOME/.saf-mt-manager.pid"
USERNAME=""
PASSWORD=""
# ------------------------------------------------------------

LAUNCHER="$HOME/.saf-mt-manager-server.py"

write_launcher() {
  if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
    AUTH_BLOCK="authorizer.add_user('${USERNAME}', '${PASSWORD}', '${ROOT_DIR}', perm='elradfmwMT')"
  else
    AUTH_BLOCK="authorizer.add_anonymous('${ROOT_DIR}', perm='elradfmwMT')"
  fi

  cat > "$LAUNCHER" <<PYEOF
from pyftpdlib.handlers import FTPHandler
from pyftpdlib.servers import FTPServer
from pyftpdlib.authorizers import DummyAuthorizer

authorizer = DummyAuthorizer()
${AUTH_BLOCK}

handler = FTPHandler
handler.authorizer = authorizer
handler.passive_ports = range(60000, 60100)

server = FTPServer(('${HOST}', ${PORT}), handler)
print('FTP running on ftp://${HOST}:${PORT}', flush=True)
server.serve_forever()
PYEOF
}

do_start() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[!] Already running (PID $(cat "$PIDFILE"))."
    print_connection_info
    return
  fi

  write_launcher

  echo "[*] Starting FTP server..."
  python3.13 "$LAUNCHER" > "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"

  sleep 2

  if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[+] Server started (PID $(cat "$PIDFILE"))."
    print_connection_info
  else
    echo "[!] Failed to start. Log:"
    cat "$LOGFILE"
    rm -f "$PIDFILE"
    exit 1
  fi
}

do_stop() {
  if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
      kill "$PID"
      rm -f "$PIDFILE"
      echo "[+] Server stopped (PID $PID)."
    else
      echo "[!] PID $PID not running. Cleaning up."
      rm -f "$PIDFILE"
    fi
  else
    echo "[!] Not running."
  fi
}

do_status() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[+] Running (PID $(cat "$PIDFILE"))"
    print_connection_info
  else
    echo "[-] Not running."
  fi
}

print_connection_info() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  MT Manager FTP Connection"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Host : $HOST"
  echo "  Port : $PORT"
  echo "  Path : $ROOT_DIR"
  if [ -n "$USERNAME" ]; then
    echo "  User : $USERNAME"
  else
    echo "  Auth : Anonymous (no password)"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  In MT Manager sidebar:"
  echo "  Tap + -> FTP -> Host: $HOST"
  echo "  Port: $PORT  Path: /"
  echo "  Leave user/pass blank -> Save"
  echo ""
}

interactive_menu() {
  echo ""
  echo "  SAF -> MT Manager Bridge (FTP)"
  echo "  Root: $ROOT_DIR  |  ftp://$HOST:$PORT"
  echo ""
  echo "  [1] Start server"
  echo "  [2] Stop server"
  echo "  [3] Status"
  echo "  [4] Connection info"
  echo "  [q] Quit"
  echo ""
  printf "  Choice: "
  read -r choice
  case "$choice" in
    1) do_start ;;
    2) do_stop ;;
    3) do_status ;;
    4) print_connection_info ;;
    q|Q) exit 0 ;;
    *) echo "Invalid choice." ;;
  esac
}

case "${1:-menu}" in
  start)  do_start ;;
  stop)   do_stop ;;
  status) do_status ;;
  info)   print_connection_info ;;
  *)      interactive_menu ;;
esac
