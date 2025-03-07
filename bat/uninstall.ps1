# Uninstall bat

Write-Output "Uninstalling bat..."
choco uninstall bat -y || { Write-Output "Failed to uninstall bat"; exit 1 }

# Remove bat config files
Write-Output "Removing bat config files..."
$configPath = "$env:USERPROFILE\.config\bat"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "bat config files removed successfully."
}
else {
    Write-Output "No bat config files found."
}
