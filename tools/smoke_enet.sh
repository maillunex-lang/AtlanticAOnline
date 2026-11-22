#!/bin/sh
set -eu

server=$(realpath "$1")
port=${2:-17777}
work=$(mktemp -d)
server_pid=
cleanup() {
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    cat "$work/server.log"
    rm -rf "$work"
}
trap cleanup EXIT
(
    cd "$(dirname "$server")"
    exec stdbuf -oL -eL "$server" --headless -- --server --port="$port" --db=:memory:
) > "$work/server.log" 2>&1 &
server_pid=$!
attempt=0
until grep -q "Сервер слушает порт $port, протокол v" "$work/server.log"; do
    kill -0 "$server_pid" 2>/dev/null || exit 1
    attempt=$((attempt + 1))
    [ "$attempt" -lt 100 ] || exit 1
    sleep 0.1
done
grep -q "Серверная SQLite готова, схема v" "$work/server.log"
timeout 12 godot --headless --path . --script tools/smoke_enet_client.gd -- "$port" > "$work/client.log" 2>&1 || {
    cat "$work/client.log"
    exit 1
}
cat "$work/client.log"
grep -q '^WP-02 ENet PASS: protocol v' "$work/client.log"
timeout 12 godot --headless --path . --script tools/smoke_enet_client.gd -- "$port" --incompatible > "$work/client.log" 2>&1 || {
    cat "$work/client.log"
    exit 1
}
cat "$work/client.log"
grep -q '^WP-02 ENet PASS: incompatible version rejected' "$work/client.log"
grep -q 'Несовместимый протокол:' "$work/server.log"
