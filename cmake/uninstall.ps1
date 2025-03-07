# Uninstall CMake
Write-Output "Uninstalling CMake..."
$cmakePath = "$env:ProgramFiles\CMake"
if (Test-Path $cmakePath) {
    Remove-Item -Recurse -Force $cmakePath
    Write-Output "CMake uninstalled successfully."
}
else {
    Write-Output "CMake is not installed."
}

# Remove CMake config files
Write-Output "Removing CMake config files..."
$configPath = "$env:USERPROFILE\.cmake"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "CMake config files removed successfully."
}
else {
    Write-Output "No CMake config files found."
}
