#!/usr/bin/env sh
set -eu

PORT="${PORT:-8000}"
exec php -S "0.0.0.0:${PORT}" -t public
