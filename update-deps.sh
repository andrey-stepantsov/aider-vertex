#!/usr/bin/env bash
# Update dependencies and immediately remove the poison pill
poetry lock "$@"
if [ -f poetry.lock ]; then
    sed -i '/riscv64/d' poetry.lock
    echo "✅ poetry.lock sanitized (riscv64 removed)"
fi