# Project Build Conventions & Nix Strategy

## Core Philosophy
This project uses a **hybrid build strategy** via `poetry2nix` to ensure stability across Linux and macOS (Darwin).

### 1. macOS (Darwin) Strategy: "Force Wheels"
**Rule:** For complex packages involving C extensions, Rust code, or heavy compilation, we **MUST** force the use of pre-compiled binary wheels.

* **Why:** Compiling these libraries (e.g., `numpy`, `scipy`, `tiktoken`, `watchfiles`) from source on macOS/Nix is notoriously fragile due to Apple SDK headers, Accelerate framework linking, and Rust toolchain issues.
* **Mechanism:** In `flake.nix`, we override packages to use `format = "wheel"` or `preferWheel = true` and explicitly provide the `sha256` hash for the macOS binary.
* **Target Packages:** `numpy`, `scipy`, `shapely`, `tiktoken`, `watchfiles`, `rpds-py`, `hf-xet`, `jiter`.

### 2. Linux Strategy: "Source Preference"
**Rule:** On Linux, we default to building from source (sdist) to leverage Nix's reproducibility capabilities.

* **Mechanism:** Standard `poetry2nix` overrides, adding native build inputs like `setuptools`, `maturin`, `cmake`, or `autoPatchelfHook`.
* **Exceptions:** Pure Python packages that fail to build with `poetry-core` may use wheels unconditionally.

---

## Maintenance Guide (The "Fail-Update" Loop)

When you update dependencies in `pyproject.toml` / `poetry.lock`, expect the macOS build to fail. This is normal.

**The Update Loop:**
1.  **Run Build:** `nix build`
2.  **Catch Mismatch:** The build will fail with `hash mismatch in fixed-output derivation`.
3.  **Update Hash:**
    * Copy the `got: sha256-...` hash from the error message.
    * Update the corresponding package's hash in `flake.nix` (in the `else` / macOS block).
4.  **Repeat:** Do this until all wheel hashes are updated.

---

## Common Package Overrides

| Package | Linux Strategy | macOS Strategy | Reason |
| :--- | :--- | :--- | :--- |
| **`tiktoken`** | Build from GitHub source (needs `Cargo.lock`) | **Force Wheel** | Rust build fails on Mac; PyPI sdist lacks lockfile. |
| **`watchfiles`** | Build from source | **Force Wheel** | Rust compilation issues. |
| **`numpy` / `scipy`** | Build from source | **Force Wheel** | Compilation is slow & fragile on Mac. |
| **`google-*`** | Patch metadata (`license-files`) + inject `setuptools` | Same | Build backend compliance issues. |
| **`regex`** | Patch metadata (`license-files`) | Same | Build backend compliance issues. |

## Troubleshooting

* **`ModuleNotFoundError: No module named 'maturin'`**: You are accidentally trying to build a Rust package from source on macOS. **Stop.** Check `flake.nix` and ensure you are forcing the wheel for that package.
* **`do not know how to unpack source archive... .whl`**: You are applying a source-build override (like `cargoDeps`) to a binary wheel. Ensure your override logic uses `if pkgs.stdenv.isLinux` correctly.