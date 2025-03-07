# Uninstall Go
Write-Output "Uninstalling Go..."
# ...existing code to uninstall Go...

# Remove Go config files
Write-Output "Removing Go config files..."
$configPath = "$env:USERPROFILE\go"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Go config files removed successfully."
}
else {
    Write-Output "No Go config files found."
}
