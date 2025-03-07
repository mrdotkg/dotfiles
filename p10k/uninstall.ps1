# Uninstall Powerlevel10k from WSL

Write-Output "Uninstalling Powerlevel10k..."
wsl -- bash -c "rm -rf ~/powerlevel10k"
wsl -- bash -c "sed -i '/powerlevel10k/d' ~/.zshrc"

Write-Output "Powerlevel10k uninstalled successfully."
