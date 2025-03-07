# Uninstall Fish Shell
Write-Output "Uninstalling Fish Shell..."
$fishPath = "$env:ProgramFiles\Fish"
if (Test-Path $fishPath) {
    Remove-Item -Recurse -Force $fishPath
    Write-Output "Fish Shell uninstalled successfully."
}
else {
    Write-Output "Fish Shell is not installed."
}

# Remove Fish Shell config files
Write-Output "Removing Fish Shell config files..."
$configPath = "$env:USERPROFILE\.config\fish"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Fish Shell config files removed successfully."
}
else {
    Write-Output "No Fish Shell config files found."
}
