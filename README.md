# Aider-Vertex (v1.3.0)

**Aider-Vertex** is a specialized fork of [Aider](https://aider.chat) designed for high-performance, hermetic C/C++ development using Google's **Vertex AI (Gemini 2.5)** models.

It introduces a **Triple-Head Architecture** that separates the AI's "Context View" from the actual source code, allowing for safe, hallucination-free editing of complex monorepos without polluting the source tree.

## 🚀 Key Features

* **Triple-Head Architecture:**
    * **Source Head:** Your actual git repo (untouched).
    * **View Head:** A temporary, ephemeral "virtual view" containing only the relevant source files and their headers.
    * **Build Head:** An isolated build environment (Docker/Nix) linked to the View Head.
* **Header Weaving:** Automatically detects `#include` directives in your C files and symlinks the correct headers into the Virtual View, ensuring the AI (and LSP) can "see" definitions without needing the entire repo.
* **Hermetic Toolchain:** Fully packaged with Nix. Zero dependencies on the host system other than Nix itself.
* **Vertex AI Integration:** Optimized for `gemini-2.5-pro` and `gemini-2.5-flash` on Google Cloud Vertex AI.

## 📦 Installation & Build

### Option 1: Using Nix (Recommended for Devs)

Enter the hermetic development shell. This provides `python3`, `gcc`, `jq`, and all project tools.

```bash
nix develop
# You are now in a shell with 'aider-vertex', 'weave-view', and test tools available.
```

### Option 2: Building the Docker Image

The project builds a hermetic Docker image containing the full toolchain.

**On Linux (Native):**
```bash
nix build .#docker
docker load < result
```

**On macOS (Apple Silicon / M1+):**
Since macOS cannot build Linux binaries natively, use this bootstrap command:

```bash
docker run --rm \
    --platform linux/arm64 \
    -v "$(pwd):/app" -w /app \
    nixos/nix \
    bash -c "nix --extra-experimental-features 'nix-command flakes' build .#docker > /dev/null && cat result" > aider-vertex-docker.tar.gz

docker load < aider-vertex-docker.tar.gz
```

### Option 3: Pull from GitHub Container Registry (Fastest)

If you do not want to build the image yourself, you can pull the pre-built release:

```bash
docker pull ghcr.io/andrey-stepantsov/aider-vertex:latest

```

*(Note: Replace `<YOUR_USERNAME>` with your GitHub username or organization).*

## 🧪 Testing

The project includes a comprehensive regression suite that verifies path rewriting, header weaving, and the Triple-Head architecture.

**Run Locally (macOS/Linux):**
```bash
./tests/run_all.sh
```

**Run in Docker (Release Verification):**
This verifies the image behaves correctly in a containerized environment (simulating CI/Production).

```bash
docker run --rm \
  --platform linux/arm64 \
  --entrypoint /bin/bash \
  -v "$(pwd):/data" \
  aider-vertex:latest \
  -c "./tests/run_all.sh"
```

## 🛠 Usage

### 1. The `dev` Orchestrator
The primary entry point is the `dev` script. It creates a Virtual View for your target and launches Aider.

```bash
# Edit a specific file/module
./dev path/to/target_file.c

# The tool will:
# 1. Create directory 'view-target_file'
# 2. Symlink the source file there
# 3. Weave required headers into 'view-target_file/_sys/includes'
# 4. Launch Aider inside the view
```

### 2. Manual View Creation
You can manually create views for inspection:

```bash
# Create a view for 'src/main.c'
bin/weave-view main src/main.c

# Inspect the result
ls -R view-main/
```

## 🏗 Architecture

```text
[ HOST FILESYSTEM ]        [ VIRTUAL VIEW ]             [ AI AGENT ]
/repo                      /view-target                 (Aider)
├── src/                   ├── src/                     See:
│   └── main.c  <---link---|   └── main.c               - main.c
├── include/               └── _sys/                    - _sys/includes/foo.h
│   └── foo.h   <---link-------includes/
│                               └── foo.h
```

The AI *thinks* it is editing a small, self-contained project. In reality, it is editing symlinks that point back to your monorepo.

## 📜 License
Apache 2.0

