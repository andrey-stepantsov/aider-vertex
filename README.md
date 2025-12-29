# Aider-Vertex

**Aider-Vertex** is a specialized distribution of [Aider](https://github.com/paul-gauthier/aider) engineered for Enterprise and Cloud-Native environments. 

It solves the "Python Dependency Hell" of local AI development by packaging the entire runtime—including OS, System Libraries, and Google Cloud SDKs—into a single immutable artifact.

## The Power of 2x ZDR
This distribution is built on two core philosophies:

### 1. Zero Dependency Runtime (ZDR)
Stop debugging `pip install` errors. Aider-Vertex bundles everything required to run complex AI coding workflows.
- **No Local Python:** You do not need Python, Pip, or Poetry installed.
- **No System Pollution:** Your host OS remains clean. No conflict with system libraries.
- **Instant On:** `docker run` and you are coding in seconds.

### 2. Zero Data Retention (Privacy Ready)
Unlike public API keys which may expose your code to training data, Aider-Vertex forces the use of Google's **Vertex AI** API.
- **No Training:** By default, Google Cloud **does not** use data sent to Vertex AI to train its foundation models.
- **Enterprise Compliance:** Inherits your Google Cloud Project's data residency (GDPR/HIPAA) and VPC Service Controls.

> **Note on True ZDR:** While Google does not train on your data by default, achieving strict **Zero Data Retention** (where no request logs or caches are stored) requires configuring your [GCP Project settings](https://cloud.google.com/vertex-ai/docs/data-governance) to explicitly disable logging and caching.

---

## Installation

### 🐳 Run with Docker (Recommended)
This is the **Zero Dependency** method. You only need Docker.

**Note:** You must mount your Google Cloud credentials so the container can authenticate securely.

```bash
docker run -it --rm \
  -v $(pwd):/data \
  -v /path/to/your/credentials.json:/root/auth.json \
  -e GOOGLE_APPLICATION_CREDENTIALS=/root/auth.json \
  -e VERTEXAI_PROJECT="your-project-id" \
  -e VERTEXAI_LOCATION="us-central1" \
  ghcr.io/andrey-stepantsov/aider-vertex:latest \
  --model vertex_ai/gemini-2.5-flash
```

### Run with Nix
If you are a Nix user, you can run the flake directly:

    nix run github:andrey-stepantsov/aider-vertex -- --architect --model vertex_ai/gemini-2.5-flash

## Features & Compatibility
- **Multi-Platform:** Verified on **macOS (Silicon)**, **Ubuntu**, and **CentOS 7**.
- **Vertex Patched:** Includes critical fixes for `google-cloud-aiplatform` and `rpds-py` crashes.
- **Git Aware:** Includes a full internal Git installation for repo management.

## Configuration

### 1. Authenticate
    gcloud auth application-default login
    # Or export GOOGLE_APPLICATION_CREDENTIALS="/path/to/creds.json"

### 2. Set Project
    export VERTEXAI_PROJECT="your-project-id"
    export VERTEXAI_LOCATION="us-central1"

## Maintenance
To update the underlying Aider engine or this wrapper:

1. **Update Versions:**
   - Update `version` in `pyproject.toml`.
   - Update `WRAPPER_VERSION` in `aider_vertex/main.py` to match.
2. **Refresh Lockfile:**
   ```bash
   nix shell nixpkgs#poetry -c poetry update
   ```
3. **Release:**
   Tag a new release (e.g., `v1.0.x`) to automatically trigger the Docker build pipeline.

## License
MIT License.