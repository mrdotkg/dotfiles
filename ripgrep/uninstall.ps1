# Uninstall ripgrep

Write-Output "Uninstalling ripgrep..."
choco uninstall ripgrep -y || { Write-Output "Failed to uninstall ripgrep"; exit 1 }

# Remove ripgrep config files
Write-Output "Removing ripgrep config files..."
$configPath = "$env:USERPROFILE\.config\ripgrep"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "ripgrep config files removed successfully."
}
else {
    Write-Output "No ripgrep config files found."
}
