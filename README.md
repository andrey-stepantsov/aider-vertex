# Aider-Vertex

A Nix-packaged distribution of **Aider**, pre-configured with the necessary build overrides for **Google Vertex AI** support on macOS and Linux.

## Features
- **Nix Powered**: Fully reproducible build environment.
- **Vertex Ready**: Includes patched dependencies for `google-cloud-sdk`, `watchfiles`, and `rpds-py`.
- **Transparent**: Passes all CLI arguments directly to the underlying Aider engine.

## Installation

Run directly without installation:
```bash
nix run github:your-username/aider-vertex -- --model vertex_ai/gemini-1.5-pro
```

Or install to your Nix profile:
```bash
nix profile install github:andrey-stepantsov/aider-vertex
```

## Configuration

Set the following environment variables to authenticate with Google Cloud:

```bash
export VERTEX_PROJECT="your-project-id"
export VERTEX_LOCATION="us-central1"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your-service-account.json"
```

## Examples

```bash
# Chat with Gemini 1.5 Pro
aider-vertex --model vertex_ai/gemini-1.5-pro

# Use Architect mode with Gemini 2.0 Flash
aider-vertex --architect --model vertex_ai/gemini-2.0-flash-exp
```


