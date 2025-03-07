# Uninstall Alacritty
Write-Output "Uninstalling Alacritty..."
$alacrittyPath = "C:\Program Files\Alacritty"
if (Test-Path $alacrittyPath) {
    Remove-Item -Recurse -Force $alacrittyPath
    Write-Output "Alacritty uninstalled successfully."
}
else {
    Write-Output "Alacritty is not installed."
}

# Remove Alacritty config files
Write-Output "Removing Alacritty config files..."
$configPath = "$env:USERPROFILE\.config\alacritty"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Alacritty config files removed successfully."
}
else {
    Write-Output "No Alacritty config files found."
}