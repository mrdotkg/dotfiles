# Uninstall Windows Terminal
Write-Output "Uninstalling Windows Terminal..."
$packageFullName = (Get-AppxPackage -Name "Microsoft.WindowsTerminal" | Select-Object -ExpandProperty PackageFullName)
if ($packageFullName) {
    Remove-AppxPackage -Package $packageFullName
    Write-Output "Windows Terminal uninstalled successfully."
}
else {
    Write-Output "Windows Terminal is not installed."
}

# Remove Windows Terminal config files
Write-Output "Removing Windows Terminal config files..."
$configPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Windows Terminal config files removed successfully."
}
else {
    Write-Output "No Windows Terminal config files found."
}
