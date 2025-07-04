#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

if [[ "$(id -u)" -eq 0 ]]; then
    echo "Do not run this script as root. Please run as an admin user."
    exit 1
fi

sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# --- System Security Configurations ---

echo "Configuring macOS security settings..."

# Enable FileVault (requires user confirmation)
fdesetup status | grep -q "FileVault is On" || {
    echo "Enabling FileVault (user confirmation required)..."
    sudo fdesetup enable -user "$USER"
}

# Require password immediately after screen saver
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Enable firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Disable remote login (SSH)
sudo systemsetup -setremotelogin off

# Create separate admin user with generated password
ADMIN_USER="adminops"
if ! id "$ADMIN_USER" &>/dev/null; then
    echo "Creating admin user '$ADMIN_USER' with a strong random password..."
    ADMIN_PASS=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' </dev/urandom | head -c 20)
    echo "Generated password for $ADMIN_USER: $ADMIN_PASS"
    sudo sysadminctl -addUser "$ADMIN_USER" -fullName "Admin Ops" -password "$ADMIN_PASS" -admin
    echo "Admin user '$ADMIN_USER' created. Please save the password securely."
fi

# --- Developer Tools ---

echo "Installing Xcode Command Line Tools..."
xcode-select --install 2>/dev/null || echo "Xcode CLT already installed."

# --- Homebrew Installation ---

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

brew update

# --- GUI Applications ---

echo "Installing GUI applications..."
brew install --cask \
    google-chrome \
    zoom \
    slack \
    docker \
    keepassxc \
    visual-studio-code \
    whatsapp \
    google-drive \
    dropbox \
    adobe-acrobat-reader \
    microsoft-teams

# --- CLI Tools ---

echo "Installing CLI tools..."
brew install \
    tfenv \
    terraform \
    kubectl \
    helm \
    awscli \
    eksctl \
    jq \
    yq \
    azure-cli \
    google-cloud-sdk

# Configure tfenv with latest version
LATEST_TF=$(tfenv list-remote | grep -E '^[0-9]+\.' | head -1)
tfenv install "$LATEST_TF"
tfenv use "$LATEST_TF"

# --- Final Security and System Settings ---

echo "Applying final system preferences..."

# Auto-lock after 5 min
defaults -currentHost write com.apple.screensaver idleTime -int 300

# Enable automatic software updates
sudo softwareupdate --schedule on

# Show FileVault status
fdesetup status

echo "✅ Setup completed successfully."
