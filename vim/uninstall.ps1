# Uninstall Vim
Write-Output "Uninstalling Vim..."
$vimPath = "$env:LOCALAPPDATA\Vim"
if (Test-Path $vimPath) {
    Remove-Item -Recurse -Force $vimPath
    Write-Output "Vim uninstalled successfully."
}
else {
    Write-Output "Vim is not installed."
}

# Remove Vim config files
Write-Output "Removing Vim config files..."
$configPath = "$env:USERPROFILE\vimfiles"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Vim config files removed successfully."
}
else {
    Write-Output "No Vim config files found."
}
