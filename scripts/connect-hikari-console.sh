#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Wait for a BOOT #5 CDC ACM function already passed through to WSL by
# usbipd AutoBind.  It never uses a device serial number.
set -euo pipefail

timeout=${HIKARI_CONSOLE_TIMEOUT:-180}
selected=${HIKARI_CONSOLE_DEVICE:-}
deadline=$((SECONDS + timeout))

while [[ -z "$selected" || ! -c "$selected" ]]; do
  for node in /dev/ttyACM*; do
    [[ -c "$node" ]] || continue
    selected=$node
  done
  [[ -n "$selected" && -c "$selected" ]] && break
  (( SECONDS < deadline )) || {
    echo "Timed out waiting for BOOT #5 CDC ACM in /dev/ttyACM*" >&2
    exit 1
  }
  sleep 1
done

while :; do
  echo "Using $selected (HIKARI_CONSOLE_DEVICE overrides auto-discovery)." >&2
  if command -v picocom >/dev/null; then
    picocom --baud 115200 "$selected" || true
  elif command -v screen >/dev/null; then
    screen "$selected" 115200 || true
  else
    echo "No picocom or screen is installed; console device is $selected" >&2
    exit 2
  fi

  [[ ${HIKARI_CONSOLE_ONCE:-0} == 1 ]] && exit 0
  selected=${HIKARI_CONSOLE_DEVICE:-}
  echo "Console exited; waiting for a CDC ACM reconnect." >&2
  while [[ -z "$selected" || ! -c "$selected" ]]; do
    for node in /dev/ttyACM*; do
      [[ -c "$node" ]] || continue
      selected=$node
    done
    sleep 1
  done
done
