# Uninstall fzf

Write-Output "Uninstalling fzf..."
choco uninstall fzf -y || { Write-Output "Failed to uninstall fzf"; exit 1 }

# Remove fzf config files
Write-Output "Removing fzf config files..."
$configPath = "$env:USERPROFILE\.fzf"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "fzf config files removed successfully."
}
else {
    Write-Output "No fzf config files found."
}
