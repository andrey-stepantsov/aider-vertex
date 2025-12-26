# Project Conventions & Architecture

## Core Philosophy
This project uses a **modular Nix Flake** structure to support cross-platform development (macOS and Linux) for a Python application managed by Poetry.

## 1. Nix & Flake Structure
* **Main Entry:** `flake.nix` handles the base environment, `devShells`, and standard packaging logic.
* **Overrides:** All Python package overrides (fixing build failures, broken metadata, missing wheels) MUST go into `overrides.nix`.
* **Modularity:** Do not inline massive build logic into `flake.nix` if it can be placed in `overrides.nix`.

## 2. Cross-Platform Rules (CRITICAL)
* **Do Not Break macOS:** We develop on macOS. Any fix for Linux MUST be guarded by `if pkgs.stdenv.isLinux`.
* **Hybrid Strategy:**
    * **macOS:** Prefer wheels (`preferWheel = true`) to avoid compiling heavy Rust/C++ deps locally.
    * **Linux:** We often need to build from source or fetch specific manylinux wheels manually because `poetry2nix` defaults might fail.

## 3. Package Overrides Guidelines
When fixing a package in `overrides.nix`:
* **Hashes:** ALWAYS use **SRI hashes** (Base64, starting with `sha256-`). Do NOT use Hex strings.
    * *Correct:* `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`
    * *Incorrect:* `5b3a5c8089eed498...`
* **Fetching Wheels:** If `poetry2nix` fails to find a wheel, manually fetch it using `pkgs.fetchPypi` with the exact version, abi, and platform tags found in `poetry.lock`.
* **Rust Packages:** Packages like `tokenizers`, `rpds-py`, `pydantic-core` often require `nativeBuildInputs` like `rustPlatform.maturinBuildHook` and `cargoDeps` when building from source on Linux.

## 4. The Agentic CI Loop
We use a custom script to allow AI agents to "see" build failures on GitHub Actions (since we cannot replicate Linux failures locally on macOS).

* **Script:** `./ci-loop.sh`
* **Workflow:**
    1.  Make changes to `overrides.nix`.
    2.  Run `./ci-loop.sh` (this commits, pushes to `agent/` branch, and streams logs).
    3.  Analyze the logs printed to the terminal.
    4.  Repeat.