# Uninstall Bash
Write-Output "Uninstalling Bash..."
# ...existing code to uninstall Bash...

# Remove Bash config files
Write-Output "Removing Bash config files..."
$configPath = "$env:USERPROFILE\.bashrc"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Bash config files removed successfully."
}
else {
    Write-Output "No Bash config files found."
}
