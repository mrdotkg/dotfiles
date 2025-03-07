# Uninstall WezTerm
Write-Output "Uninstalling WezTerm..."
$weztermPath = "$env:LOCALAPPDATA\WezTerm"
if (Test-Path $weztermPath) {
    Remove-Item -Recurse -Force $weztermPath
    Write-Output "WezTerm uninstalled successfully."
}
else {
    Write-Output "WezTerm is not installed."
}

# Remove WezTerm config files
Write-Output "Removing WezTerm config files..."
$configPath = "$env:USERPROFILE\.wezterm"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "WezTerm config files removed successfully."
}
else {
    Write-Output "No WezTerm config files found."
}
