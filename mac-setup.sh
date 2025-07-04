#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Detect CPU architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# Check if running as root
if [[ "$(id -u)" -eq 0 ]]; then
    echo "Please do NOT run this script as root. Run it as an admin user."
    exit 1
fi

# Prompt for sudo upfront
sudo -v

# Keep sudo alive while the script runs
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- System Security Configurations ---

echo "Configuring macOS security settings..."

# Enable FileVault (requires manual confirmation)
fdesetup status | grep -q "FileVault is On" || {
    echo "Enabling FileVault (you may be prompted)..."
    sudo fdesetup enable -user "$USER"
}

# Require password immediately after sleep or screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Disable remote login (SSH)
sudo systemsetup -setremotelogin off

# Create separate admin user
ADMIN_USER="adminops"
if ! id "$ADMIN_USER" &>/dev/null; then
    echo "Creating admin user '$ADMIN_USER'..."
    sudo sysadminctl -addUser "$ADMIN_USER" -fullName "Admin Ops" -password "changeme123" -admin
    echo "Admin user '$ADMIN_USER' created. Please change password later."
fi

# --- Install Command Line Tools ---

echo "Installing Xcode Command Line Tools (macOS Developer Tools)..."
xcode-select --install 2>/dev/null || echo "Xcode Command Line Tools already installed."

# --- Install Homebrew ---

if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Ensure brew is in PATH
if [[ "$ARCH" == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Update Homebrew
brew update

# --- Install Core Software ---

echo "Installing GUI applications via Homebrew..."

brew install --cask google-chrome zoom slack docker keepassxc visual-studio-code whatsapp

# --- Install Developer CLI Tools ---

echo "Installing CLI tools..."

brew install tfenv terraform kubectl helm awscli eksctl jq yq azure-cli google-cloud-sdk

# Configure tfenv to use latest version
LATEST_TF=$(tfenv list-remote | grep -E '^[0-9]+\.' | head -1)
tfenv install "$LATEST_TF"
tfenv use "$LATEST_TF"

# --- Final Configurations ---

echo "Applying system preferences..."

# Hide desktop icons (optional, security by obscurity)
# defaults write com.apple.finder CreateDesktop false && killall Finder

# Auto-lock screen after 5 minutes of inactivity
defaults -currentHost write com.apple.screensaver idleTime -int 300

# Enable automatic software updates
sudo softwareupdate --schedule on

# Enable full disk encryption check
fdesetup status

echo "✅ Setup completed successfully. Please verify FileVault, admin user, and installed apps."
