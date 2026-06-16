#!/bin/sh
set -eu

# Defaults. Do not put secrets here for public repositories.
BASE_URL="https://www.heyunidc.cn"
API_USERNAME=""
API_KEY=""
HEYUN_SERVICE_ID=""
TIMEOUT="15"
COOKIE_FILE="/tmp/heyun_vps_watchdog.cookie"
LOG_PATH="/tmp/heyun_vps_watchdog.log"

# Optional private config file. Copy heyun_vps_watchdog.conf.example to
# heyun_vps_watchdog.conf and keep that file out of git.
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CONFIG_FILE="${HEYUN_CONFIG_FILE:-$SCRIPT_DIR/heyun_vps_watchdog.conf}"
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

# Environment variables override defaults and the optional config file.
BASE_URL="${HEYUN_BASE_URL:-$BASE_URL}"
API_USERNAME="${HEYUN_API_USERNAME:-$API_USERNAME}"
API_KEY="${HEYUN_API_KEY:-${HEYUN_API_PASSWORD:-$API_KEY}}"
SERVICE_IDS_RAW="${*:-${HEYUN_SERVICE_ID:-$HEYUN_SERVICE_ID}}"
TIMEOUT="${HEYUN_TIMEOUT:-$TIMEOUT}"
COOKIE_FILE="${HEYUN_COOKIE_FILE:-$COOKIE_FILE}"
LOG_PATH="${HEYUN_LOG_PATH:-$LOG_PATH}"

if [ "${HEYUN_LOG_REDIRECTED:-0}" != "1" ]; then
  mkdir -p "$(dirname "$LOG_PATH")"
  export HEYUN_LOG_REDIRECTED=1
  exec "$0" "$@" >> "$LOG_PATH" 2>&1
fi

printf '\n[%s] run: start\n' "$(date '+%Y-%m-%d %H:%M:%S')"

login_body=""
login_resp=""
status_resp=""
start_resp=""

log() {
  printf '[%s] %s: %s\n' "$(date '+%H:%M:%S')" "$1" "$2"
}

json_get() {
  key="$1"
  file="$2"
  if command -v jsonfilter >/dev/null 2>&1; then
    jsonfilter -i "$file" -e "$key" 2>/dev/null || true
    return
  fi

  case "$key" in
    '@.jwt')
      sed -n 's/.*"jwt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1
      ;;
    '@.data.status')
      sed -n 's/.*"data"[[:space:]]*:[[:space:]]*{[^}]*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1
      ;;
    '@.data.des')
      sed -n 's/.*"data"[[:space:]]*:[[:space:]]*{[^}]*"des"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1
      ;;
    '@.msg')
      sed -n 's/.*"msg"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1
      ;;
    *)
      return 0
      ;;
  esac
}

require_env() {
  if [ -z "$API_USERNAME" ]; then
    log "错误" "API_USERNAME/HEYUN_API_USERNAME 不能为空"
    exit 2
  fi
  if [ -z "$API_KEY" ]; then
    log "错误" "API_KEY/HEYUN_API_KEY 不能为空"
    exit 2
  fi
  if [ -z "$SERVICE_IDS_RAW" ]; then
    log "错误" "HEYUN_SERVICE_ID 不能为空"
    exit 2
  fi
}

login() {
  login_body="/tmp/heyun_login_$$.json"
  login_resp="/tmp/heyun_login_resp_$$.json"
  trap 'rm -f "$login_body" "$login_resp" "$status_resp" "$start_resp"' EXIT

  printf '{"username":"%s","password":"%s"}' "$API_USERNAME" "$API_KEY" > "$login_body"
  curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -c "$COOKIE_FILE" \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Content-Type: application/json' \
    --data-binary "@$login_body" \
    "$BASE_URL/zjmf_api_login" > "$login_resp"

  JWT="$(json_get '@.jwt' "$login_resp")"
  if [ -z "$JWT" ]; then
    msg="$(json_get '@.msg' "$login_resp")"
    log "登录" "失败: ${msg:-$(cat "$login_resp")}"
    exit 1
  fi
  log "登录" "成功"
}

get_status() {
  service_id="$1"
  status_resp="/tmp/heyun_status_${service_id}_$$.json"
  curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -b "$COOKIE_FILE" \
    -H 'Accept: application/json, text/html, text/plain, */*' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "Authorization: JWT $JWT" \
    -H "Referer: $BASE_URL/service" \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
    --data "id=$service_id&func=status" \
    "$BASE_URL/provision/default" > "$status_resp"

  POWER_STATUS="$(json_get '@.data.status' "$status_resp")"
  POWER_DESC="$(json_get '@.data.des' "$status_resp")"
  if [ -z "$POWER_STATUS" ]; then
    msg="$(json_get '@.msg' "$status_resp")"
    log "状态" "unknown; ${msg:-$(cat "$status_resp")}"
    return 1
  fi

  case "$POWER_STATUS" in
    on|running|online|poweron|power_on)
      NORMALIZED_STATUS="running"
      ;;
    off|stopped|offline|poweroff|power_off|shutdown)
      NORMALIZED_STATUS="stopped"
      ;;
    *)
      NORMALIZED_STATUS="unknown"
      ;;
  esac

  log "状态" "$NORMALIZED_STATUS; 原始信息: $POWER_STATUS ${POWER_DESC:-}"
}

start_vps() {
  service_id="$1"
  start_resp="/tmp/heyun_start_${service_id}_$$.json"
  curl -sS --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" \
    -b "$COOKIE_FILE" \
    -H 'Accept: application/json, text/html, text/plain, */*' \
    -H 'X-Requested-With: XMLHttpRequest' \
    -H "Authorization: JWT $JWT" \
    -H "Referer: $BASE_URL/servicedetail?id=$service_id" \
    -H 'Content-Type: application/x-www-form-urlencoded; charset=UTF-8' \
    --data "id=$service_id&func=on" \
    "$BASE_URL/provision/default" > "$start_resp"

  msg="$(json_get '@.msg' "$start_resp")"
  log "开机" "${msg:-$(cat "$start_resp")}"
}

main() {
  require_env
  login

  OVERALL_STATUS=0
  SERVICE_IDS="$(printf '%s' "$SERVICE_IDS_RAW" | tr ',' ' ')"
  for service_id in $SERVICE_IDS; do
    log "实例" "开始检测 id=$service_id"
    if get_status "$service_id"; then
      if [ "$NORMALIZED_STATUS" = "stopped" ]; then
        start_vps "$service_id"
      fi
    else
      OVERALL_STATUS=1
    fi
  done

  return "$OVERALL_STATUS"
}

set +e
main
rc="$?"
set -e
printf '[%s] run: exit=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$rc"
exit "$rc"
