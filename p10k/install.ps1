# Install Powerlevel10k on Windows 11 using WSL

# Check if WSL is installed
if (-Not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled") {
    Write-Output "WSL is not installed. Please install WSL first."
    exit
}

# Install Powerlevel10k
wsl -- bash -c "git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k"
wsl -- bash -c "echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc"

Write-Output "Powerlevel10k installation completed successfully."
