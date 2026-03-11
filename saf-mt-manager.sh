#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
#  SAF -> MT Manager Bridge  (FTP server for Termux)
#  Requires: python3.x -m pip install pyftpdlib
#
#  Usage:
#    ./saf-mt-manager.sh          # interactive menu
#    ./saf-mt-manager.sh start    # start with output
#    ./saf-mt-manager.sh stop     # stop server
#    ./saf-mt-manager.sh status   # check status
#    ./saf-mt-manager.sh silent   # start silently (for .bashrc/.zshrc)
# ============================================================

# ---------- Config ------------------------------------------
HOST="127.0.0.1"
PORT="8021"
ROOT_DIR="/data/data/com.termux"
LOGFILE="$HOME/.saf-mt-manager.log"
PIDFILE="$HOME/.saf-mt-manager.pid"
USERNAME=""
PASSWORD=""
# ------------------------------------------------------------

LAUNCHER="$HOME/.saf-mt-manager-server.py"

# Auto-detect python3.x binary
detect_python() {
  for bin in /data/data/com.termux/files/usr/bin/python3*; do
    # skip if glob didn't match anything
    [ -x "$bin" ] || continue
    # skip if it's not a versioned binary (e.g. skip python3-config)
    echo "$bin" | grep -qE 'python3\.[0-9]+$' || continue
    echo "$bin"
    return 0
  done
  echo ""
}

PYTHON=$(detect_python)

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
server.serve_forever()
PYEOF
}

port_in_use() {
  # Returns 0 (true) if port is already bound
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -q ":${PORT} "
  elif command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | grep -q ":${PORT} "
  else
    # fallback: try to connect
    (echo "" > /dev/tcp/${HOST}/${PORT}) 2>/dev/null
  fi
}

do_start() {
  if [ -z "$PYTHON" ]; then
    echo "[!] No python3.x found in Termux. Install Python first: pkg install python"
    exit 1
  fi

  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "[!] Already running (PID $(cat "$PIDFILE"))."
    print_connection_info
    return
  fi

  write_launcher

  echo "[*] Starting FTP server with $PYTHON ..."
  "$PYTHON" "$LAUNCHER" > "$LOGFILE" 2>&1 &
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

do_silent() {
  # Completely silent: start only if port is free, otherwise do nothing
  [ -z "$PYTHON" ] && return
  port_in_use && return
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null && return

  write_launcher
  "$PYTHON" "$LAUNCHER" > "$LOGFILE" 2>&1 &
  echo $! > "$PIDFILE"
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
  echo "  Py   : $PYTHON"
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
  echo "  Root : $ROOT_DIR"
  echo "  URL  : ftp://$HOST:$PORT"
  echo "  Py   : ${PYTHON:-NOT FOUND}"
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
  silent) do_silent ;;
  *)      interactive_menu ;;
esac
