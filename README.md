# Aider-Vertex

A Nix-packaged distribution of **Aider**, pre-configured with the necessary build overrides for **Google Vertex AI** support on macOS and Linux.

This package bridges the gap between Aider's rapid development cycle and the specific requirements of the Google Cloud SDK, ensuring a reproducible environment without the usual Python dependency conflicts.

## Features
- **Nix Powered**: Fully reproducible build environment for Intel/Silicon Macs and Linux.
  - **Multi-platform**: Verified on **macOS (Apple Silicon)**, **Ubuntu**, and **CentOS 7**.
- **Vertex Ready**: Includes patched dependencies for `google-cloud-aiplatform`, `watchfiles`, and `rpds-py`.
- **Cutting Edge**: Currently tracks **Aider v0.86.1** with Tree-sitter and Architect mode support.
- **Docker Ready**: Available as a zero-dependency container image.
- **Transparent**: Passes all CLI arguments directly to the underlying Aider engine.

## Installation

### 🐳 Run with Docker (Recommended for non-Nix users)
You can run Aider-Vertex immediately without installing Nix, Python, or Git:

```bash
docker run -it --rm \
  -v $(pwd):/data \
  -e GOOGLE_APPLICATION_CREDENTIALS=/data/your-creds.json \
  -e VERTEXAI_PROJECT="your-project-id" \
  -e VERTEXAI_LOCATION="us-central1" \
  ghcr.io/andrey-stepantsov/aider-vertex:latest
```

### Run directly with Nix
If you have Nix installed with Flakes enabled, you can run it instantly:

    nix run github:andrey-stepantsov/aider-vertex -- --architect --model vertex_ai/gemini-2.5-flash

### Install to Nix Profile
To make the `aider-vertex` command available globally:

    nix profile install github:andrey-stepantsov/aider-vertex

## Configuration

Before running, ensure you have authenticated with Google Cloud and set your project details.

### 1. Authenticate
    gcloud auth login
    gcloud auth application-default login
    
Or, you could bring pre-made credentials and set the environment with:
    
    export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"  

### 2. Set Environment Variables
    export VERTEXAI_PROJECT="your-project-id"
    export VERTEXAI_LOCATION="us-central1"

*Note: Model availability depends on your `VERTEX_LOCATION`. Check the Vertex AI Console to confirm which models are enabled for your project.*

## Usage Examples

**Chat with Gemini 2.5 Pro:**
    aider-vertex --model vertex_ai/gemini-2.5-flash

**Architect Mode with Gemini 3 Preview:**
    aider-vertex --architect --model vertex_ai/gemini-3-pro-preview

**Check Version:**
    aider-vertex --version

---

## Maintenance (For the Maintainer)
To update the underlying Aider engine or add new dependencies:

1. **Update Versions**: 
   - Update `version` in `pyproject.toml`.
   - Update `WRAPPER_VERSION` in `aider_vertex/main.py` to match.
2. **Refresh the Lockfile**:
    nix shell nixpkgs#poetry nixpkgs#python311 -c poetry update aider-chat
3. **Rebuild and Verify**:
    # Uses ./ci-loop.sh or manual build
    nix build . -L
    ./result/bin/aider-vertex --version
4. **Release**:
   Pushing to `main` automatically publishes the `latest` Docker image.
   Pushing a tag creates a versioned release:
   
    git tag -a v1.0.x -m "Release v1.0.x: Wrapping Aider v0.86.1"
    git push origin main --follow-tags

---

## License
This project is licensed under the MIT License.

## Future Iterations (Roadmap)
The goal is to evolve Aider-Vertex from a simple wrapper into a robust AI research and development environment.

🟢 Phase 1: Document Intelligence (Next Up)
PDF Extraction: Integrate pypdf to allow Aider to "read" local PDF specifications and whitepapers.

Office Support: Add python-docx to handle enterprise documentation.

Pandoc Integration: Leverage nixpkgs#pandoc to convert complex documents into LLM-friendly Markdown.

🟡 Phase 2: Enhanced Web Research
Dynamic Scraping: Evaluate playwright for Javascript-heavy documentation sites.

Search Integration: Explore adding search tool capabilities for real-time library discovery.

🔴 Phase 3: Vertex-Native Extensions
Image Context: Optimize the pipeline for sending local screenshots and diagrams to Gemini's multi-modal endpoint.

Context Caching: Implement logic to leverage Vertex AI's context caching for massive codebases (reducing token costs).
