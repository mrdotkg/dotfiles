# Uninstall Node.js
Write-Output "Uninstalling Node.js..."
# ...existing code to uninstall Node.js...

# Remove Node.js config files
Write-Output "Removing Node.js config files..."
$configPath = "$env:USERPROFILE\.npmrc"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Node.js config files removed successfully."
}
else {
    Write-Output "No Node.js config files found."
}
