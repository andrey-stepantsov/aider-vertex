#!/usr/bin/env bash
set -e

echo "🔒 Locking dependencies with Poetry..."
poetry lock "$@"

if [ -f poetry.lock ]; then
    echo "🧹 Sanitizing poetry.lock (removing riscv64 hashes)..."
    
    # Cross-platform sed compatible with macOS (BSD) and Linux (GNU)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' '/riscv64/d' poetry.lock
    else
        sed -i '/riscv64/d' poetry.lock
    fi
    
    echo "✅ poetry.lock sanitized."
else
    echo "⚠️  No poetry.lock found!"
fi