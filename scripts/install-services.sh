#!/bin/bash
# hyprchrp Systemd Services Installation Script

set -e

echo "🚀 Installing hyprchrp systemd services..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_DIR/config/systemd"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

# Ensure user systemd directory exists
mkdir -p "$USER_SYSTEMD_DIR"

# Copy service files
echo "📋 Copying service files..."
cp "$CONFIG_DIR/hyprchrp.service" "$USER_SYSTEMD_DIR/"

# Reload systemd configuration
echo "🔄 Reloading systemd configuration..."
systemctl --user daemon-reload

# Enable services
echo "✅ Enabling services..."
systemctl --user enable hyprchrp.service
systemctl --user enable ydotool.service

echo "🎉 Services installed and enabled!"
echo ""
echo "To start the services now, run:"
echo "  systemctl --user start hyprchrp"
echo "  systemctl --user start ydotool"
echo ""
echo "To check status:"
echo "  systemctl --user status hyprchrp"
echo "  systemctl --user status ydotool"
echo ""
echo "Services will now start automatically on login."
