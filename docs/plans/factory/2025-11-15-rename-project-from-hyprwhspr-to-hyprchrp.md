## Goal
Rename the project from **hyprwhspr** to **hyprchrp** consistently across code, scripts, services, config paths, and documentation. Update the README.md to make it clear that hyprchrp is a fork of hyprwhspr that adds parakeet v3 functionality while maintaining Whisper functionality. 

---
## High-level approach
1. **Establish naming decisions** for all externally visible surfaces (binary name, systemd unit, install dir, config dirs, Waybar module ID, env vars, GitHub URLs).
2. **Refactor code & scripts** to use the new name (`hyprchrp`) everywhere, with a few compatibility shims where it’s cheap and helpful.
3. **Update docs** (README, CLAUDE, comments) to match the new name and new paths.
4. **Validate** by running lightweight checks (Python import/compile, launcher, and existing helper scripts) rather than a full test suite.

If you confirm this plan, I’ll implement the changes step by step and keep things running during the transition.

---
## Naming decisions
**Canonical new name:**
- Project / marketing: **HyprChrp** (docs text), code-level identifier: `hyprchrp`.
- CLI binary: `hyprchrp` (with an optional legacy `hyprwhspr` wrapper).
- Systemd unit: `hyprchrp.service`.
- Install prefix: `/usr/lib/hyprchrp`.
- User config dir: `~/.config/hyprchrp`.
- User data dir (venv, models, temp): `~/.local/share/hyprchrp/…`.
- User state dir: `~/.local/state/hyprchrp`.
- Env vars: `HYPRCHRP_ROOT`, `HYPRCHRP_CUDA_HOST` (while still honoring the old ones where reasonable).
- Waybar custom module: `custom/hyprchrp` and `#custom-hyprchrp`.

No backwards compatibility is required. This should be a strict break.

---
## Concrete changes by area

### 1. Project metadata & packaging
- **`pyproject.toml`**
  - Change `[project] name` from `"hyprwhspr"` to `"hyprchrp"`.
  - Optionally update `description` to mention HyprChrp by name.
- **`uv.lock`**
  - Update the top-level package entry name from `hyprwhspr` to `hyprchrp` (or regenerate the lockfile after the rename).
- **Repository naming in docs**
  - In `README.md`, update all GitHub URLs and commands:
    - `git clone https://github.com/goodroot/hyprwhspr.git` → `.../hyprchrp.git`.
    - `cd hyprwhspr` → `cd hyprchrp`.
    - Issue URLs from `/goodroot/hyprwhspr/...` → `/goodroot/hyprchrp/...`.

(We’ll leave the actual repo rename on GitHub to you; I’ll just update references.)

### 2. CLI launcher and environment
- **Rename primary launcher script**
  - Move `bin/hyprwhspr` → `bin/hyprchrp`.
  - Inside the script:
    - Update comments and any printed strings.
    - Change `USER_VENV` path to `${XDG_DATA_HOME:-$HOME/.local/share}/hyprchrp/venv`.
    - Export `HYPRCHRP_ROOT` instead of `HYPRWHSPR_ROOT` (and optionally still export the old one as an alias for now).
    - Update error messages to say `hyprchrp`.
- **Legacy wrapper (optional but recommended)**
  - Add a new `bin/hyprwhspr` that:
    - Prints a short deprecation message (“hyprwhspr has been renamed to hyprchrp; please update your scripts.”).
    - `exec`s the new launcher (`hyprchrp`) so existing shortcuts/aliases keep working.

### 3. Core Python code
- **`lib/main.py`**
  - Update module docstring to `hyprchrp - ...`.
  - Change console banner: `HYPRWHSPR STARTING UP!` → `HYPRCHRP STARTING UP!`.
  - Rename `class hyprwhsprApp` to something like `HyprChrpApp` (or `HyprchrpApp`); update all internal references (`app = HyprChrpApp()`, docstrings, log messages).
  - Update all printed messages from `hyprwhspr` → `hyprchrp`.
  - `_write_recording_status`:
    - Primary path: `~/.config/hyprchrp/recording_status`.
    - Optionally: also remove an old `~/.config/hyprwhspr/recording_status` file if it exists to keep things clean.

- **Config and data paths (`lib/src/config_manager.py`)**
  - Change `self.config_dir` from `~/.config/hyprwhspr` to `~/.config/hyprchrp`.
  - `get_temp_directory`: switch from `~/.local/share/hyprwhspr/temp` to `~/.local/share/hyprchrp/temp`.

- **Parakeet models (`lib/src/parakeet_manager.py`)**
  - Update `models_dir` to `~/.local/share/hyprchrp/models/parakeet`.

- **Audio assets (`lib/src/audio_manager.py`)**
  - Switch `install_dir` default from `/usr/lib/hyprwhspr` to `/usr/lib/hyprchrp`.
  - Use env vars in priority order: `HYPRCHRP_ROOT` → `HYPRWHSPR_ROOT` → default path. This allows existing setups that export `HYPRWHSPR_ROOT` to keep working.

- **Misc Python modules**
  - Update docstrings and log messages in:
    - `config_manager.py`, `audio_utils.py`, `text_injector.py`, `parakeet_manager.py`, `audio_manager.py`, `logger.py`, `global_shortcuts.py`, `whisper_manager.py`, `audio_capture.py`, and `lib/src/__init__.py` to say “hyprchrp” instead of “hyprwhspr”.
  - No module/package renames are required (imports are all generic), so the structure under `lib/src/` stays the same.

### 4. Systemd service and integration
- **New canonical unit**
  - Create/rename service file to `config/systemd/hyprchrp.service` with:
    - `Description=hyprchrp Voice Dictation Service`.
    - `ExecStart=/usr/lib/hyprchrp/bin/hyprchrp`.
    - `Environment=HYPRCHRP_ROOT=/usr/lib/hyprchrp`.
  

- **Installer integration (`scripts/install-services.sh`)**
  - Update comments and `echo` messages.
  - Copy and enable `hyprchrp.service` instead of `hyprwhspr.service`.

- **Service test script (`scripts/test-services.sh`)**
  - Update all occurrences of `hyprwhspr` to `hyprchrp` (service description, `systemctl` commands, help text).

### 5. Hyprland tray script & Waybar
- **Tray script rename**
  - Rename `config/hyprland/hyprwhspr-tray.sh` → `hyprchrp-tray.sh`.
  - Inside the script:
    - Update comments and tooltips from `hyprwhspr` to `hyprchrp`.
    - Change `PACKAGE_ROOT` and `ICON_PATH` to `/usr/lib/hyprchrp` and `hyprchrp.png` (we can either rename the icon asset or point to an existing one—your call).
    - Update all `systemctl ... hyprwhspr.service`, `pgrep -f "hyprwhspr"`, and `~/.config/hyprwhspr/recording_status` references to the new names/paths.

- **Waybar module & CSS**
  - Rename files:
    - `config/waybar/hyprwhspr-module.jsonc` → `hyprchrp-module.jsonc`.
    - `config/waybar/hyprwhspr-style.css` → `hyprchrp-style.css`.
  - Update contents:
    - JSON: `"custom/hyprwhspr"` → `"custom/hyprchrp"`, paths to tray script and CSS under `/usr/lib/hyprchrp/...`.
    - CSS: `#custom-hyprwhspr` → `#custom-hyprchrp` in all selectors.

- **Installer Waybar integration (`scripts/install-omarchy.sh`)**
  - Change `PACKAGE_NAME`, `INSTALL_DIR`, `USER_BASE`, `STATE_DIR`, `SERVICE_NAME` to the new `hyprchrp` variants.
  - Update validation checks:
    - Required files now include `bin/hyprchrp`, `config/hyprland/hyprchrp-tray.sh`, `config/systemd/hyprchrp.service`, `config/waybar/hyprchrp-style.css`.
  - Update Waybar configuration logic:
    - Replace string checks for `"custom/hyprwhspr"` with `"custom/hyprchrp"`.
    - Update the default Waybar config snippet to include `"custom/hyprchrp"` in `modules-right` and `"/usr/lib/hyprchrp/config/waybar/hyprchrp-module.jsonc"` in `include`.
    - Generate the user module config file as `~/.config/waybar/hyprchrp-module.jsonc` pointing to the new tray script.
    - Adjust CSS import lines to `@import "/usr/lib/hyprchrp/config/waybar/hyprchrp-style.css";`.

- **Hyprland helper path**
  - Update the script references to `~/.config/hypr/scripts/hyprwhspr-tray.sh` → `hyprchrp-tray.sh` wherever they appear in `install-omarchy.sh`.

### 6. Other scripts
- **`scripts/install-omarchy.sh` (beyond Waybar/Systemd bits)**
  - Update all user-facing log messages from `hyprwhspr` to `hyprchrp`.
  - Change `HYPRWHSPR_CUDA_HOST` references:
    - Add support for `HYPRCHRP_CUDA_HOST` as the primary override, and fall back to `HYPRWHSPR_CUDA_HOST` for compatibility.
    - Update documentation log lines to mention the new env var name.
  - Adjust any path checks for `/usr/lib/hyprwhspr`, `~/.local/share/hyprwhspr`, `~/.config/hyprwhspr`, etc., to the new locations.

- **`scripts/fix-uinput-permissions.sh`**
  - Update script title and any references from `hyprwhspr` → `hyprchrp`.

- **`scripts/test-parakeet.py`**
  - Update the introductory docstring text to refer to `hyprchrp`.

### 7. Documentation updates
- **`README.md`**
  - Change project heading and textual references to `hyprchrp` / “HyprChrp”.
  - Update all paths and commands:
    - `/usr/lib/hyprwhspr` → `/usr/lib/hyprchrp`.
    - `~/.local/share/hyprwhspr/...` → `~/.local/share/hyprchrp/...`.
    - `~/.config/hyprwhspr/...` → `~/.config/hyprchrp/...`.
    - `hyprwhspr.service` → `hyprchrp.service`.
    - Tray script and Waybar examples to the new names.
  - Adjust the “Reset installation” section to delete the new directories instead of the old ones; 

- **`CLAUDE.md`**
  - Mirror the same naming/path changes as README (project overview, directory structure, config paths, systemd unit name, Waybar files, installation directory, troubleshooting paths).

- **Inline comments**
  - Where comments contain the old name in code/scripts (e.g., “hyprwhspr Systemd Services Installation Script”), update them to `hyprchrp`.

---
## Validation plan
Because there’s no formal test suite, we’ll rely on lightweight validation:

1. **Static checks**
   - Run `python3 -m compileall lib` to ensure all Python files (including the renamed imports and new paths) compile.
2. **Backend smoke test**
   - Run `python3 scripts/test-parakeet.py` to confirm that the Parakeet backend still loads models from the new path (or fallback path) correctly.
3. **Service scripts sanity**
   - Run `scripts/test-services.sh` after reinstalling services to ensure `hyprchrp.service` can start/stop and that Waybar/tray integration doesn’t error out.

If any of these fail after the rename, I’ll trace the offending paths/names and correct them before considering the rename complete.

---
## Questions for you
Before I implement this:
1. **Compatibility level:** Do you want a hard cut-over (no hyprwhspr wrappers/aliases), or should we keep a thin compatibility layer (old binary + old service name forwarding to the new ones)? this is a hard cut-over
2. **GitHub repo rename:** The GitHub repo will be renamed `Whamp/hyprchrp` 
3. **Icon/branding:** Should we also rename the PNG asset to `hyprchrp.png`, or just point the tray script at the existing icon file for now? rename the PNG asset

