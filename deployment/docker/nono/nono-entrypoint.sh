#!/bin/sh
set -eu

tz="${TZ:-UTC}"
if [ -f "/usr/share/zoneinfo/${tz}" ]; then
  ln -sf "/usr/share/zoneinfo/${tz}" /etc/localtime
  echo "${tz}" > /etc/timezone
else
  echo "WARNING: unknown TZ=${tz}; keeping container timezone as-is" >&2
fi
export TZ="${tz}"

export NGINX_PORT="${NGINX_PORT:-8080}"
LOCAL_API_PROXY_PORT="${LOCAL_API_PROXY_PORT:-18317}"

backend="${CLIPROXY_API_BACKEND:-http://cli-proxy-api:8317}"
backend_authority="${backend#*://}"
backend_authority="${backend_authority%%/*}"
backend_host="${backend_authority%%:*}"
backend_port="${backend_authority##*:}"
if [ "${backend_host}" = "${backend_port}" ]; then
  backend_port=8317
fi

if ! getent hosts "${backend_host}" >/dev/null 2>&1; then
  echo "ERROR: cannot resolve CLIProxyAPI backend host ${backend_host}" >&2
  exit 1
fi

# nginx inside nono cannot use Docker DNS or raw egress to the API container; forward on loopback instead.
socat "TCP-LISTEN:${LOCAL_API_PROXY_PORT},fork,reuseaddr,bind=127.0.0.1" "TCP:${backend_host}:${backend_port}" &
socat_pid=$!
trap 'kill "${socat_pid}" 2>/dev/null || true' EXIT INT TERM

export CLIPROXY_API_BACKEND="http://127.0.0.1:${LOCAL_API_PROXY_PORT}"

TEMPLATE=/etc/nginx/templates/default.conf.template
OUTPUT=/etc/nginx/conf.d/default.conf

mkdir -p /etc/nginx/conf.d /etc/nginx/templates

envsubst '${NGINX_PORT} ${CLIPROXY_API_BACKEND}' < "${TEMPLATE}" > "${OUTPUT}"

if [ -e /etc/nginx/sites-enabled/default ]; then
  rm -f /etc/nginx/sites-enabled/default
fi

# Keep workers in the same user namespace as nono (www-data cannot use open_port IPC grants).
if [ -f /etc/nginx/nginx.conf ]; then
  sed -i 's/^user www-data;/user root;/' /etc/nginx/nginx.conf 2>/dev/null \
    || sed -i '' 's/^user www-data;/user root;/' /etc/nginx/nginx.conf
fi

# NONO_RUN_ARGS: optional extra nono run flags before "--" (word-split; unset or empty = no extra flags).
# shellcheck disable=SC2086
exec nono run --profile "${NONO_PROFILE:-management}" ${NONO_RUN_ARGS:-} -- "$@"
