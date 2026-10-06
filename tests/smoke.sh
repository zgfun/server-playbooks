#!/usr/bin/env bash
# Runs site.yml against a fresh Ubuntu 24.04 container and then runs it again
# to prove it is idempotent (second run must report changed=0).
# Service-level tasks are skipped: a plain container has no systemd.
set -euo pipefail
cd "$(dirname "$0")/.."
name=ansible-test
docker rm -f "$name" >/dev/null 2>&1 || true
docker run -d --name "$name" ubuntu:24.04 sleep infinity >/dev/null
docker exec "$name" bash -c "apt-get update -qq && apt-get install -y -qq python3 >/dev/null"
run() { ansible-playbook -i tests/inventory.docker.yml site.yml --skip-tags service "$@"; }
run
echo "--- second run, expecting changed=0"
run | tee /tmp/ansible-second-run.txt
grep -E "ansible-test\s*:.*changed=0" /tmp/ansible-second-run.txt && echo "IDEMPOTENT: ok"
docker rm -f "$name" >/dev/null
