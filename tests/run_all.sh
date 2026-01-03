#!/bin/bash
set -e

echo "🚀 Running Full Regression Suite..."

echo "---------------------------------------------------"
echo "👉 [Unit] Docker Path Rewrite"
bash ./tests/unit/test_docker_rewrite.sh

echo "---------------------------------------------------"
echo "👉 [Unit] Header Weaving"
bash ./tests/unit/test_header_weaving.sh

echo "---------------------------------------------------"
echo "👉 [Unit] Naming Normalization"
bash ./tests/unit/test_naming_normalization.sh

echo "---------------------------------------------------"
echo "👉 [Integration] Architecture & Orchestrator"
# FIX: Explicit interpreter invocation for Docker compatibility
bash ./tests/integration/test_architecture.sh

echo "---------------------------------------------------"
echo "✅ All automated tests passed."