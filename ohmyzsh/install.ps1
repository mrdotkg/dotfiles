# Install Oh My Zsh on Windows 11 using WSL

# Check if WSL is installed
if (-Not (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq "Enabled") {
    Write-Output "WSL is not installed. Please install WSL first."
    exit
}

# Install Oh My Zsh
wsl -- bash -c "sh -c '$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)'"

Write-Output "Oh My Zsh installation completed successfully."
