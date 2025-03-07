# Uninstall Tmux
Write-Output "Uninstalling Tmux..."
$tmuxPath = "$env:LOCALAPPDATA\Tmux"
if (Test-Path $tmuxPath) {
    Remove-Item -Recurse -Force $tmuxPath
    Write-Output "Tmux uninstalled successfully."
}
else {
    Write-Output "Tmux is not installed."
}

# Remove Tmux config files
Write-Output "Removing Tmux config files..."
$configPath = "$env:USERPROFILE\.tmux"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Tmux config files removed successfully."
}
else {
    Write-Output "No Tmux config files found."
}
