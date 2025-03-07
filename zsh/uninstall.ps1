# Uninstall Zsh
Write-Output "Uninstalling Zsh..."
$zshPath = "$env:LOCALAPPDATA\Zsh"
if (Test-Path $zshPath) {
    Remove-Item -Recurse -Force $zshPath
    Write-Output "Zsh uninstalled successfully."
}
else {
    Write-Output "Zsh is not installed."
}

# Remove Zsh config files
Write-Output "Removing Zsh config files..."
$configPath = "$env:USERPROFILE\.zsh"
if (Test-Path $configPath)) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Zsh config files removed successfully."
}
else {
    Write-Output "No Zsh config files found."
}
