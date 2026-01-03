#!/bin/bash
set -e

echo "🚀 Running Full Regression Suite..."

echo "---------------------------------------------------"
echo "👉 [Unit] Docker Path Rewrite"
./tests/unit/test_docker_rewrite.sh

echo "---------------------------------------------------"
echo "👉 [Unit] Header Weaving"
./tests/unit/test_header_weaving.sh

echo "---------------------------------------------------"
echo "👉 [Integration] Architecture & Orchestrator"
./tests/integration/test_architecture.sh

echo "---------------------------------------------------"
echo "✅ All automated tests passed."