#!/bin/bash
set -e

echo "🚀 Running Full Regression Suite..."

echo "---------------------------------------------------"
./tests/unit/test_docker_rewrite.sh
echo "---------------------------------------------------"
./tests/integration/test_architecture.sh
echo "---------------------------------------------------"

echo "✅ All automated tests passed."
