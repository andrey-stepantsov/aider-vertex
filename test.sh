#!/usr/bin/env bash
set -e

echo "--- Testing Aider-Vertex (Devbox + Poetry) ---"

# 1. Check for credentials
if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    echo "Error: GOOGLE_APPLICATION_CREDENTIALS not set. Check your .env file."
    exit 1
fi

# 2. Run Aider using Poetry
# Uses the Dec 2025 Gemini 3 Flash model
echo "/exit" | poetry run aider \
    --model vertex_ai/gemini-3-flash-preview \
    --no-git \
    --no-auto-commits \
    --message "Vertex Check: Respond with 'OK'."

echo "Connectivity test successful."