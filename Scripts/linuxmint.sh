#!/bin/bash

# 🔐 SSH Key Generation: Create ed25519 cryptographic keys for secure authentication GitHub
ssh-keygen -t ed25519 -C "grv.rkg@gmail.com"
# 🔧 SSH Agent: Start SSH agent service for key management authentication daemon
eval "$(ssh-agent -s)"
# 🔑 Key Loading: Add private key to SSH agent for automatic authentication
ssh-add ~/.ssh/id_ed25519
# 📋 Clipboard Copy: Copy public key to clipboard for GitHub repository access
cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
# 🌐 Browser Launch: Open GitHub SSH key settings page for key registration
xdg-open "https://github.com/settings/ssh/new"