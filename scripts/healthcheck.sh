#!/usr/bin/env bash
# Health check for the Project Foundry stack.
# Pings each local llama-server and reports Hermes gateway service state.
# Exits non-zero if any inference server is down.
set -uo pipefail

PORTS=(8080 8081 8082 8083)
FAIL=0

echo "== inference servers =="
for p in "${PORTS[@]}"; do
  if curl -sf --max-time 3 "http://127.0.0.1:${p}/health" >/dev/null 2>&1; then
    echo "  ok    llama-server :${p}"
  else
    echo "  FAIL  llama-server :${p}"
    FAIL=1
  fi
done

echo "== hermes gateways =="
# Each agent profile runs as its own launchd gateway service.
launchctl list 2>/dev/null | awk '/ai\.hermes\.gateway/{print $3, "(pid " $1 ")"}' | while read -r line; do
  echo "  ${line}"
done

if [ "$FAIL" -ne 0 ]; then
  echo
  echo "One or more inference servers are down. See docs/04-inference-stack.md."
fi

exit "$FAIL"
