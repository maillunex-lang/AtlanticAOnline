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
start_server() {
    (
        cd "$(dirname "$server")"
        ATLANTIC_LOCAL_LOGIN_KEY="$1" ATLANTIC_LOCAL_LOGIN_KEY_SECOND="${2:-}" ATLANTIC_LOCAL_ACCOUNTS_FILE="${3:-}" exec stdbuf -oL -eL "$server" --headless -- --server --port="$port" --db=:memory:
    ) > "$work/server.log" 2>&1 &
    server_pid=$!
    attempt=0
    until grep -q "Сервер слушает порт $port, протокол v" "$work/server.log"; do
        kill -0 "$server_pid" 2>/dev/null || exit 1
        attempt=$((attempt + 1))
        [ "$attempt" -lt 100 ] || exit 1
        sleep 0.1
    done
}

start_server ""
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

# Restart with the loopback-only account enabled.
kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
login_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
start_server "$login_key"

session_probe() {
    secret=$1
    expected=$2
    shift 2
    ATLANTIC_SMOKE_SECRET="$secret" ATLANTIC_SMOKE_TOKEN_FILE="$work/token" \
        timeout 12 godot --headless --path . --script tools/smoke_enet_client.gd -- "$port" "$@" > "$work/client.log" 2>&1 || {
        cat "$work/client.log"
        exit 1
    }
    cat "$work/client.log"
    grep -q "^WP-70 ENet PASS: session $expected" "$work/client.log"
}

invalid_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
session_probe "$invalid_key" rejected --login --reject
session_probe "$login_key" rejected --login --incompatible
session_probe "$login_key" granted --login
old_token=$(cat "$work/token")
session_probe "$old_token" granted --resume
new_token=$(cat "$work/token")
session_probe "$old_token" rejected --resume --reject
session_probe "$new_token" granted --resume

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
second_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
start_server "$login_key" "$second_key"
ATLANTIC_SMOKE_SECRET="$login_key" ATLANTIC_SMOKE_SECRET_SECOND="$second_key" \
    timeout 120 godot --headless --path . --script tools/smoke_zone_presence.gd -- "$port" > "$work/presence.log" 2>&1 || {
    cat "$work/presence.log"
    exit 1
}
cat "$work/presence.log"
grep -q '^WP-70 presence PASS:' "$work/presence.log"
grep -q '^WP-70 dunes PASS:' "$work/presence.log"

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
start_server "$login_key" "$second_key"
ATLANTIC_SMOKE_SECRET="$login_key" \
    ATLANTIC_SMOKE_SECRET_SECOND="$second_key" \
    timeout 45 godot --headless --path . --script tools/smoke_dunes_client.gd -- "$port" > "$work/client_ui.log" 2>&1 || {
    cat "$work/client_ui.log"
    exit 1
}
cat "$work/client_ui.log"
grep -q '^WP-70 client PASS:' "$work/client_ui.log"
! grep -Eq 'SCRIPT ERROR|Parse Error' "$work/client_ui.log"

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
third_key=$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')
(
    umask 077
    printf '[{"name":"one","key":"%s"},{"name":"two","key":"%s"},{"name":"three","key":"%s"}]\n' \
        "$login_key" "$second_key" "$third_key" > "$work/accounts.json"
)
start_server "" "" "$work/accounts.json"
ATLANTIC_SMOKE_SECRET="$login_key" ATLANTIC_SMOKE_SECRET_SECOND="$second_key" ATLANTIC_SMOKE_SECRET_THIRD="$third_key" \
    timeout 45 godot --headless --path . --script tools/smoke_rome_auction.gd -- "$port" > "$work/auction.log" 2>&1 || {
    cat "$work/auction.log"
    exit 1
}
cat "$work/auction.log"
grep -q '^WP-90 auction PASS:' "$work/auction.log"
! grep -Eq 'SCRIPT ERROR|Parse Error' "$work/auction.log"

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
start_server "$login_key" "$second_key"
XDG_DATA_HOME="$work/local_profile" ATLANTIC_SMOKE_SECRET="$login_key" \
    timeout 30 godot --headless --path . --script tools/smoke_start_screen.gd -- "$port" > "$work/entry.log" 2>&1 || {
    cat "$work/entry.log"
    exit 1
}
cat "$work/entry.log"
grep -q '^WP-70 entry PASS:' "$work/entry.log"
! grep -Eq 'SCRIPT ERROR|Parse Error' "$work/entry.log"

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
start_server "" "" "$work/accounts.json"
ATLANTIC_SMOKE_FIRST="$login_key" ATLANTIC_SMOKE_SECOND="$second_key" ATLANTIC_SMOKE_THIRD="$third_key" \
    timeout 15 godot --headless --path . --script tools/smoke_pilot_accounts.gd -- "$port" > "$work/accounts.log" 2>&1 || {
    cat "$work/accounts.log"
    exit 1
}
cat "$work/accounts.log"
grep -q '^WP-70 accounts PASS:' "$work/accounts.log"
! grep -Eq 'SCRIPT ERROR|Parse Error' "$work/accounts.log"

kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=
(
    umask 077
    printf '[{"name":"one","key":"%s"},{"name":"two","key":"%s"}]\n' \
        "$login_key" "$login_key" > "$work/duplicate.json"
)
result=0
(
    cd "$(dirname "$server")"
    ATLANTIC_LOCAL_LOGIN_KEY= ATLANTIC_LOCAL_LOGIN_KEY_SECOND= ATLANTIC_LOCAL_ACCOUNTS_FILE="$work/duplicate.json" \
        timeout 5 "$server" --headless -- --server --port="$port" --db=:memory:
) > "$work/invalid.log" 2>&1 || result=$?
[ "$result" -eq 1 ]
grep -q 'Некорректная конфигурация локальных аккаунтов пилота' "$work/invalid.log"
