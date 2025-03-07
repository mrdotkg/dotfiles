# Uninstall VSCode
Write-Output "Uninstalling VSCode..."
Start-Process -FilePath "C:\Program Files\Microsoft VS Code\unins000.exe" -ArgumentList "/silent" -Wait

# Remove VSCode config files
Write-Output "Removing VSCode config files..."
$configPath = "$env:APPDATA\Code"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "VSCode config files removed successfully."
}
else {
    Write-Output "No VSCode config files found."
}
