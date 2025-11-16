#!/bin/bash
# hyprchrp Uninstallation Script
# Removes hyprchrp-specific files, services, and integrations installed by install-omarchy.sh

set -euo pipefail

# ----------------------- Colors & logging -----------------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ----------------------- Defaults -------------------------------
DRY_RUN=false
ASSUME_YES=false
PURGE_MODELS=false
PURGE_UINPUT=false

# ----------------------- Usage ---------------------------------
usage() {
  cat <<'EOF'
Usage: ./scripts/uninstall-hyprchrp.sh [options]

Options:
  -y, --yes             Assume "yes" to prompts (non-interactive)
  --dry-run             Show what would be removed without making changes
  --purge-models        Also remove pywhispercpp model files (shared data)
  --purge-uinput-rule   Remove the hyprchrp uinput udev rule if present
  -h, --help            Show this help message and exit
EOF
}

# ----------------------- Argument parsing ----------------------
while (($#)); do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    -y|--yes)
      ASSUME_YES=true
      ;;
    --purge-models)
      PURGE_MODELS=true
      ;;
    --purge-uinput-rule)
      PURGE_UINPUT=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

# ----------------------- Helpers --------------------------------
confirm() {
  local prompt="$1"
  if [ "$ASSUME_YES" = true ]; then
    return 0
  fi
  read -r -p "$prompt [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

run_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[dry-run] $*"
  else
    "$@"
  fi
}

run_priv_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[dry-run] (sudo) $*"
    return 0
  fi
  if [ "$EUID" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

run_user_cmd() {
  if [ "$DRY_RUN" = true ]; then
    log_info "[dry-run] (user:$ACTUAL_USER) $*"
    return 0
  fi

  if [ "$EUID" -eq 0 ] && [ "$ACTUAL_USER" != "root" ]; then
    local user_uid
    user_uid=$(id -u "$ACTUAL_USER")
    sudo -H -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$user_uid" "$@"
  else
    "$@"
  fi
}

remove_path() {
  local target="$1" description="$2"
  if [ -e "$target" ]; then
    log_info "Removing $description: $target"
    run_cmd rm -rf "$target"
  else
    log_info "No $description found at $target (skipping)"
  fi
}

remove_priv_path() {
  local target="$1" description="$2"
  if [ -e "$target" ]; then
    log_info "Removing $description: $target"
    run_priv_cmd rm -rf "$target"
  else
    log_info "No $description found at $target (skipping)"
  fi
}

# ----------------------- User detection -------------------------
detect_actual_user() {
  if [ "$EUID" -eq 0 ]; then
    if [ -n "${SUDO_USER:-}" ]; then
      ACTUAL_USER="$SUDO_USER"
    else
      ACTUAL_USER=""
      while IFS=: read -r username _ _ _ _ home _; do
        if [ "$username" = "root" ]; then
          continue
        fi
        if [ -d "$home" ] && [ "$home" != "/" ]; then
          ACTUAL_USER="$username"
          break
        fi
      done < <(getent passwd)

      if [ -z "$ACTUAL_USER" ]; then
        log_warning "No non-root user found; defaulting to root"
        ACTUAL_USER="root"
      fi
    fi
  else
    ACTUAL_USER="$USER"
  fi

  USER_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
  if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    log_error "Could not determine home directory for user: $ACTUAL_USER"
    exit 1
  fi
}

detect_actual_user

CONFIG_DIR="$USER_HOME/.config/hyprchrp"
DATA_DIR="${XDG_DATA_HOME:-$USER_HOME/.local/share}/hyprchrp"
STATE_DIR="${XDG_STATE_HOME:-$USER_HOME/.local/state}/hyprchrp"
USER_SYSTEMD_DIR="$USER_HOME/.config/systemd/user"
WAYBAR_CONFIG="$USER_HOME/.config/waybar/config.jsonc"
WAYBAR_MODULE="$USER_HOME/.config/waybar/hyprchrp-module.jsonc"
WAYBAR_STYLE="$USER_HOME/.config/waybar/style.css"
MODELS_DIR="${XDG_DATA_HOME:-$USER_HOME/.local/share}/pywhispercpp/models"
INSTALL_DIR="/usr/lib/hyprchrp"
SYSTEM_UINPUT_RULE="/etc/udev/rules.d/99-uinput.rules"

log_info "Detected user: $ACTUAL_USER"
log_info "Operating in $( [ "$DRY_RUN" = true ] && echo 'dry-run' || echo 'live' ) mode"

# ----------------------- Systemd cleanup ------------------------
stop_and_disable_service() {
  if ! command -v systemctl >/dev/null 2>&1; then
    log_warning "systemctl not available; skipping user service stop"
    return
  fi

  if ! run_user_cmd systemctl --user stop hyprchrp.service >/dev/null 2>&1; then
    log_info "hyprchrp.service not running or unavailable (skip stop)"
  else
    log_success "Stopped hyprchrp.service"
  fi

  if ! run_user_cmd systemctl --user disable hyprchrp.service >/dev/null 2>&1; then
    log_info "hyprchrp.service not enabled (skip disable)"
  else
    log_success "Disabled hyprchrp.service"
  fi
}

remove_user_systemd_unit() {
  local unit_path="$USER_SYSTEMD_DIR/hyprchrp.service"
  if [ -f "$unit_path" ]; then
    log_info "Removing user systemd unit: $unit_path"
    run_cmd rm -f "$unit_path"
    run_user_cmd systemctl --user daemon-reload || log_warning "Failed to reload user systemd daemon"
  else
    log_info "No user systemd unit found at $unit_path"
  fi
}

# ----------------------- Waybar cleanup ------------------------
cleanup_waybar_module() {
  if [ -f "$WAYBAR_MODULE" ]; then
    log_info "Removing Waybar module file: $WAYBAR_MODULE"
    run_cmd rm -f "$WAYBAR_MODULE"
  else
    log_info "No Waybar module file found at $WAYBAR_MODULE"
  fi
}

cleanup_waybar_config() {
  if [ ! -f "$WAYBAR_CONFIG" ]; then
    log_info "Waybar config not found at $WAYBAR_CONFIG"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    log_info "[dry-run] Would clean Waybar config $WAYBAR_CONFIG"
    return
  fi

  local backup
  backup="$WAYBAR_CONFIG.backup-hyprchrp-uninstall-$(date +%Y%m%d-%H%M%S)"
  cp "$WAYBAR_CONFIG" "$backup"
  log_info "Backup created: $backup"

  if ! WAYBAR_CONFIG="$WAYBAR_CONFIG" WAYBAR_MODULE="$WAYBAR_MODULE" \
    python3 <<'PY'; then
import json, os, sys

config_path = os.environ['WAYBAR_CONFIG']
module_path = os.environ['WAYBAR_MODULE']
system_module_path = '/usr/lib/hyprchrp/config/waybar/hyprchrp-module.jsonc'

try:
    with open(config_path, 'r', encoding='utf-8') as f:
        config = json.load(f)
except json.JSONDecodeError as exc:
    print(f"ERROR: Invalid JSON in {config_path}: {exc}", file=sys.stderr)
    sys.exit(1)

modified = False

if isinstance(config.get('include'), list):
    new_include = [item for item in config['include'] if item not in (module_path, system_module_path)]
    if new_include != config['include']:
        config['include'] = new_include
        modified = True

module_keys = [
    'modules-right',
    'modules-left',
    'modules-center',
    'modules-top',
    'modules-bottom'
]

for key in module_keys:
    if isinstance(config.get(key), list):
        new_modules = [item for item in config[key] if item != 'custom/hyprchrp']
        if new_modules != config[key]:
            config[key] = new_modules
            modified = True

if modified:
    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2, separators=(',', ': '))
    print(f"Cleaned Waybar config: {config_path}")
else:
    print("Waybar config already clean")
PY
    log_error "Failed to update $WAYBAR_CONFIG"
  fi
}

cleanup_waybar_style() {
  if [ ! -f "$WAYBAR_STYLE" ]; then
    log_info "Waybar style.css not found at $WAYBAR_STYLE"
    return
  fi

  if [ "$DRY_RUN" = true ]; then
    log_info "[dry-run] Would remove hyprchrp CSS import from $WAYBAR_STYLE"
    return
  fi

  if ! WAYBAR_STYLE="$WAYBAR_STYLE" python3 <<'PY'; then
import os

style_path = os.environ['WAYBAR_STYLE']
import_line = '@import "/usr/lib/hyprchrp/config/waybar/hyprchrp-style.css";'

if not os.path.isfile(style_path):
    raise SystemExit(0)

with open(style_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = [line for line in lines if line.strip() != import_line]

if new_lines != lines:
    temp_path = style_path + '.tmp'
    with open(temp_path, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    os.replace(temp_path, style_path)
    print(f"Removed hyprchrp CSS import from {style_path}")
PY
    log_error "Failed to clean $WAYBAR_STYLE"
  fi
}

# ----------------------- Directory cleanup ---------------------
remove_user_artifacts() {
  remove_path "$CONFIG_DIR" "user config"
  remove_path "$DATA_DIR" "user runtime data"
  remove_path "$STATE_DIR" "user state"
}

# ----------------------- Install dir cleanup -------------------
remove_install_dir() {
  if [ ! -d "$INSTALL_DIR" ]; then
    log_info "No system install dir at $INSTALL_DIR"
    return
  fi

  local representative="$INSTALL_DIR/lib/main.py"
  if [ -f "$representative" ] && pacman -Qo "$representative" >/dev/null 2>&1; then
    local owner
    owner=$(pacman -Qo "$representative" 2>/dev/null | awk '{print $5}')
    log_warning "$INSTALL_DIR is managed by package: $owner"
    log_warning "Use 'sudo pacman -Rns $owner' to remove the packaged install"
    return
  fi

  remove_priv_path "$INSTALL_DIR" "system install"
}

# ----------------------- Optional purges -----------------------
purge_models_if_requested() {
  if [ "$PURGE_MODELS" = false ]; then
    return
  fi

  if [ ! -d "$MODELS_DIR" ]; then
    log_info "No pywhispercpp models directory at $MODELS_DIR"
    return
  fi

  if confirm "Remove pywhispercpp models at $MODELS_DIR? They may be used by other apps."; then
    remove_path "$MODELS_DIR" "pywhispercpp models"
  else
    log_info "Skipping pywhispercpp models removal"
  fi
}

purge_uinput_rule_if_requested() {
  if [ "$PURGE_UINPUT" = false ]; then
    return
  fi

  if [ ! -f "$SYSTEM_UINPUT_RULE" ]; then
    log_info "No uinput rule at $SYSTEM_UINPUT_RULE"
    return
  fi

  local expected_rule='# Allow members of the input group to access uinput device
KERNEL=="uinput", GROUP="input", MODE="0660"'
  local current_rule
  current_rule=$(<"$SYSTEM_UINPUT_RULE")

  if [ "$current_rule" != "$expected_rule" ]; then
    log_warning "$SYSTEM_UINPUT_RULE does not match hyprchrp rule; not removing"
    return
  fi

  if confirm "Remove hyprchrp uinput rule at $SYSTEM_UINPUT_RULE?"; then
    remove_priv_path "$SYSTEM_UINPUT_RULE" "uinput udev rule"
    run_priv_cmd udevadm control --reload-rules || log_warning "Failed to reload udev rules"
    run_priv_cmd udevadm trigger --name-match=uinput || log_warning "Failed to trigger uinput rule"
    log_info "To remove input/tty group memberships (if added for hyprchrp):"
    log_info "  sudo gpasswd -d $ACTUAL_USER input"
    log_info "  sudo gpasswd -d $ACTUAL_USER tty"
  else
    log_info "Skipping uinput rule removal"
  fi
}

# ----------------------- Main ---------------------------------
main() {
  log_info "Starting hyprchrp uninstall"

  stop_and_disable_service
  remove_user_systemd_unit

  cleanup_waybar_module
  cleanup_waybar_config
  cleanup_waybar_style

  remove_user_artifacts
  remove_install_dir

  purge_models_if_requested
  purge_uinput_rule_if_requested

  log_success "hyprchrp uninstall completed"
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode: no changes were made"
  fi
  log_info "Consider disabling ydotool.service manually if you only used it for hyprchrp"
}

main "$@"
