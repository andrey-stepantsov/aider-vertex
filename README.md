# Aider-Vertex

A specialized environment for [Aider](https://aider.chat/) with Google Vertex AI support, managed via Devbox and Poetry.

## 🔐 Credentials Setup

This project uses an external Service Account for security.

1. Locate your Service Account JSON (e.g., `~/.config/aider/gen-lang-client-*.json`).
2. Create a `.env` file in this root directory (this file is git-ignored):
   ~~~bash
   GOOGLE_APPLICATION_CREDENTIALS="/Users/stepants/.config/aider/your-key-file.json"
   VERTEXAI_PROJECT="gen-lang-client-0140206225"
   VERTEXAI_LOCATION="us-central1"
   ~~~

## 🚀 Development Workflow

1. **Enter Environment**: Run `devbox shell`.
2. **Install Deps**: Run `poetry install` inside the shell.
3. **Run Test**: Execute `./test.sh` to verify Vertex AI connectivity.