#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HELPER="/tmp/qsb-axui"

swiftc "$ROOT_DIR/script/axui.swift" -o "$HELPER"
exec "$HELPER" "$@"
