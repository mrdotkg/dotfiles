# Uninstall Neovim
Write-Output "Uninstalling Neovim..."
$neovimPath = "$env:LOCALAPPDATA\Neovim"
if (Test-Path $neovimPath) {
    Remove-Item -Recurse -Force $neovimPath
    Write-Output "Neovim uninstalled successfully."
}
else {
    Write-Output "Neovim is not installed."
}

# Remove Neovim config files
Write-Output "Removing Neovim config files..."
$configPath = "$env:LOCALAPPDATA\nvim"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Neovim config files removed successfully."
}
else {
    Write-Output "No Neovim config files found."
}
