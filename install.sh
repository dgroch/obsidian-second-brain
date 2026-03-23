#!/usr/bin/env bash
#
# install.sh - Set up your Second Brain
#
# This script will:
#   1. Create your vault directory with the PARA folder structure
#   2. Initialize Git and connect to your remote
#   3. Copy starter templates
#   4. Generate a .gitignore for the vault
#   5. Optionally set up a cron job for auto-sync
#   6. Optionally set up a systemd timer (Linux) or launchd agent (macOS)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BOLD}${BLUE}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${BLUE}║     Second Brain Framework Setup     ║${NC}"
    echo -e "${BOLD}${BLUE}╚══════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

prompt_value() {
    local prompt="$1"
    local default="$2"
    local result

    if [[ -n "$default" ]]; then
        read -rp "$(echo -e "${BOLD}$prompt${NC} [$default]: ")" result
        echo "${result:-$default}"
    else
        read -rp "$(echo -e "${BOLD}$prompt${NC}: ")" result
        echo "$result"
    fi
}

prompt_yn() {
    local prompt="$1"
    local default="${2:-y}"
    local result
    read -rp "$(echo -e "${BOLD}$prompt${NC} [${default}]: ")" result
    result="${result:-$default}"
    [[ "$result" =~ ^[Yy] ]]
}

# --- Check prerequisites ---

check_prerequisites() {
    echo -e "${BOLD}Checking prerequisites...${NC}"
    local missing=0

    if command -v git &>/dev/null; then
        print_step "Git $(git --version | cut -d' ' -f3)"
    else
        print_error "Git is not installed"
        missing=1
    fi

    if command -v bash &>/dev/null; then
        print_step "Bash ${BASH_VERSION}"
    else
        print_error "Bash is required"
        missing=1
    fi

    if command -v obsidian-cli &>/dev/null; then
        print_step "obsidian-cli $(obsidian-cli --version 2>/dev/null || echo 'installed')"
    else
        print_warn "obsidian-cli not found (optional, install: brew install yakitrak/yakitrak/obsidian-cli)"
    fi

    if command -v openclaw &>/dev/null; then
        print_step "OpenClaw detected"
        OPENCLAW_AVAILABLE=true
    else
        OPENCLAW_AVAILABLE=false
    fi

    if [[ $missing -eq 1 ]]; then
        echo ""
        print_error "Please install missing prerequisites and try again."
        exit 1
    fi
    echo ""
}

# --- Gather configuration ---

gather_config() {
    echo -e "${BOLD}Configuration${NC}"
    echo "─────────────────────────────────────"

    # Try to auto-detect vault path via obsidian-cli
    local default_vault="$HOME/SecondBrain"
    if command -v obsidian-cli &>/dev/null; then
        local detected
        detected="$(obsidian-cli print-default --path-only 2>/dev/null || true)"
        if [[ -n "$detected" && -d "$detected" ]]; then
            default_vault="$detected"
            print_step "Detected existing vault: $detected"
        fi
    fi

    VAULT_PATH=$(prompt_value "Vault path" "$default_vault")
    GIT_REMOTE=$(prompt_value "Git remote URL (HTTPS or SSH)" "")
    GIT_BRANCH=$(prompt_value "Git branch" "main")
    SYNC_INTERVAL=$(prompt_value "Auto-sync interval (minutes, 0 to disable)" "10")
    COMMIT_PREFIX=$(prompt_value "Commit message prefix" "vault")

    echo ""
}

# --- Create vault structure ---

create_vault() {
    echo -e "${BOLD}Creating vault...${NC}"

    mkdir -p "$VAULT_PATH"

    # Create PARA folders
    local folders=("0-Inbox" "1-Projects" "2-Areas" "3-Resources" "4-Archive" "Templates")
    for folder in "${folders[@]}"; do
        mkdir -p "$VAULT_PATH/$folder"
        print_step "Created $folder/"
    done

    # Copy templates
    if [[ -d "$SCRIPT_DIR/vault-template" ]]; then
        cp -rn "$SCRIPT_DIR/vault-template/"* "$VAULT_PATH/" 2>/dev/null || true
        print_step "Copied starter templates"
    fi

    # Create vault .gitignore
    cat > "$VAULT_PATH/.gitignore" << 'GITIGNORE'
# Obsidian workspace (device-specific, causes conflicts)
.obsidian/workspace.json
.obsidian/workspace-mobile.json

# Obsidian cache
.obsidian/cache

# OS files
.DS_Store
Thumbs.db

# Trash
.trash/

# Temporary files
*.tmp
*.swp
*~
GITIGNORE
    print_step "Created .gitignore"

    echo ""
}

# --- Initialize Git ---

init_git() {
    echo -e "${BOLD}Setting up Git...${NC}"
    cd "$VAULT_PATH"

    if [[ ! -d ".git" ]]; then
        git init -b "$GIT_BRANCH"
        print_step "Initialized git repository"
    else
        print_warn "Git already initialized"
    fi

    if [[ -n "$GIT_REMOTE" ]]; then
        if git remote get-url origin &>/dev/null; then
            git remote set-url origin "$GIT_REMOTE"
            print_step "Updated remote origin"
        else
            git remote add origin "$GIT_REMOTE"
            print_step "Added remote origin: $GIT_REMOTE"
        fi

        # Try initial pull if remote has content
        if git ls-remote origin &>/dev/null 2>&1; then
            if git ls-remote --heads origin "$GIT_BRANCH" | grep -q "$GIT_BRANCH"; then
                print_warn "Remote branch exists. Pulling existing content..."
                git fetch origin "$GIT_BRANCH"
                git reset --mixed "origin/$GIT_BRANCH" 2>/dev/null || true
            fi
        fi
    fi

    # Initial commit if needed
    git add -A
    if ! git diff --cached --quiet 2>/dev/null; then
        git commit -m "Initial second brain setup"
        print_step "Created initial commit"
    fi

    if [[ -n "$GIT_REMOTE" ]]; then
        if git push -u origin "$GIT_BRANCH" 2>/dev/null; then
            print_step "Pushed to remote"
        else
            print_warn "Could not push (you may need to set up authentication first)"
        fi
    fi

    echo ""
}

# --- Save configuration ---

save_config() {
    echo -e "${BOLD}Saving configuration...${NC}"

    # Save .env to framework directory
    cat > "$SCRIPT_DIR/.env" << ENV
# Second Brain Configuration (generated by install.sh)
VAULT_PATH="$VAULT_PATH"
GIT_REMOTE="$GIT_REMOTE"
GIT_BRANCH="$GIT_BRANCH"
SYNC_INTERVAL=$SYNC_INTERVAL
COMMIT_PREFIX="$COMMIT_PREFIX"
AUTO_RESOLVE_CONFLICTS=true
LOG_FILE="$HOME/.secondbrain/sync.log"
LOG_MAX_SIZE=10
NOTIFICATIONS=true
ENV

    # Also save to ~/.secondbrain for global access
    mkdir -p "$HOME/.secondbrain"
    cp "$SCRIPT_DIR/.env" "$HOME/.secondbrain/.env"

    print_step "Configuration saved to .env"
    print_step "Configuration saved to ~/.secondbrain/.env"
    echo ""
}

# --- Set up auto-sync ---

setup_cron() {
    if [[ "$SYNC_INTERVAL" -eq 0 ]]; then
        print_warn "Auto-sync disabled (interval = 0)"
        return
    fi

    echo -e "${BOLD}Setting up auto-sync...${NC}"

    local sync_script="$SCRIPT_DIR/scripts/sync.sh"
    chmod +x "$sync_script"
    chmod +x "$SCRIPT_DIR/scripts/backup.sh"
    chmod +x "$SCRIPT_DIR/scripts/status.sh"

    local method=""
    echo "Choose auto-sync method:"
    echo "  1) Cron job (recommended, works everywhere)"
    echo "  2) Systemd timer (Linux only, survives reboots better)"
    echo "  3) launchd agent (macOS only, survives reboots)"
    echo "  4) Skip (run sync manually or use --daemon mode)"
    read -rp "$(echo -e "${BOLD}Select [1]:${NC} ")" method
    method="${method:-1}"

    case "$method" in
        1) setup_cron_job "$sync_script" ;;
        2) setup_systemd "$sync_script" ;;
        3) setup_launchd "$sync_script" ;;
        4) print_warn "Skipped auto-sync setup. Run manually: $sync_script" ;;
    esac
    echo ""
}

setup_cron_job() {
    local sync_script="$1"
    local cron_entry="*/$SYNC_INTERVAL * * * * $sync_script >> $HOME/.secondbrain/sync.log 2>&1"

    # Remove existing secondbrain cron entries
    (crontab -l 2>/dev/null | grep -v "secondbrain\|sync.sh") | crontab - 2>/dev/null || true

    # Add new entry
    (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
    print_step "Cron job added: every $SYNC_INTERVAL minutes"
}

setup_systemd() {
    local sync_script="$1"
    local service_dir="$HOME/.config/systemd/user"
    mkdir -p "$service_dir"

    cat > "$service_dir/secondbrain-sync.service" << SERVICE
[Unit]
Description=Second Brain Git Sync

[Service]
Type=oneshot
ExecStart=$sync_script
SERVICE

    cat > "$service_dir/secondbrain-sync.timer" << TIMER
[Unit]
Description=Second Brain sync timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=${SYNC_INTERVAL}min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

    systemctl --user daemon-reload
    systemctl --user enable --now secondbrain-sync.timer
    print_step "Systemd timer enabled: every $SYNC_INTERVAL minutes"
}

setup_launchd() {
    local sync_script="$1"
    local plist_path="$HOME/Library/LaunchAgents/com.secondbrain.sync.plist"
    local interval_seconds=$((SYNC_INTERVAL * 60))

    cat > "$plist_path" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.secondbrain.sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>$sync_script</string>
    </array>
    <key>StartInterval</key>
    <integer>$interval_seconds</integer>
    <key>StandardOutPath</key>
    <string>$HOME/.secondbrain/sync.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.secondbrain/sync.log</string>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
PLIST

    launchctl load "$plist_path" 2>/dev/null || true
    print_step "launchd agent installed: every $SYNC_INTERVAL minutes"
}

# --- Print summary ---

print_summary() {
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║     Setup Complete!                  ║${NC}"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════╝${NC}"
    echo ""
    echo "  Vault:       $VAULT_PATH"
    echo "  Remote:      ${GIT_REMOTE:-none}"
    echo "  Branch:      $GIT_BRANCH"
    echo "  Auto-sync:   every ${SYNC_INTERVAL}m"
    echo ""
    echo -e "${BOLD}Quick start:${NC}"
    echo "  1. Open Obsidian and select '$VAULT_PATH' as your vault"
    echo "  2. Start writing notes in 0-Inbox/"
    echo "  3. Your notes auto-sync every ${SYNC_INTERVAL} minutes"
    echo ""
    echo -e "${BOLD}Useful commands:${NC}"
    echo "  $SCRIPT_DIR/scripts/sync.sh          # Sync now"
    echo "  $SCRIPT_DIR/scripts/sync.sh --daemon  # Run continuous sync"
    echo "  $SCRIPT_DIR/scripts/backup.sh         # Create backup"
    echo "  $SCRIPT_DIR/scripts/status.sh         # View status"
    echo ""

    if [[ "$OPENCLAW_AVAILABLE" == "true" ]]; then
        echo -e "${BOLD}OpenClaw:${NC}"
        echo "  This project includes an OpenClaw skill (SKILL.md)."
        echo "  OpenClaw can manage your vault, run syncs, and organize notes."
        echo "  The skill activates when you ask about your second brain."
        echo ""
    else
        echo -e "${BOLD}OpenClaw (optional):${NC}"
        echo "  Install OpenClaw for AI-assisted vault management:"
        echo "    npm install -g openclaw@latest"
        echo "  Then use this project directory as a workspace skill."
        echo ""
    fi
}

# --- Main ---

main() {
    print_header
    check_prerequisites
    gather_config
    create_vault
    init_git
    save_config
    setup_cron
    print_summary
}

main "$@"
