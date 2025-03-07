# Uninstall Google Cloud SDK
Write-Output "Uninstalling Google Cloud SDK..."
# ...existing code to uninstall Google Cloud SDK...

# Remove Google Cloud SDK config files
Write-Output "Removing Google Cloud SDK config files..."
$configPath = "$env:USERPROFILE\.config\gcloud"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Google Cloud SDK config files removed successfully."
}
else {
    Write-Output "No Google Cloud SDK config files found."
}
