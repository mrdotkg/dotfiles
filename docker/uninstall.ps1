# Uninstall Docker
Write-Output "Uninstalling Docker..."
$dockerPath = "$env:ProgramFiles\Docker"
if (Test-Path $dockerPath) {
    Remove-Item -Recurse -Force $dockerPath
    Write-Output "Docker uninstalled successfully."
}
else {
    Write-Output "Docker is not installed."
}

# Remove Docker config files
Write-Output "Removing Docker config files..."
$configPath = "$env:USERPROFILE\.docker"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Docker config files removed successfully."
}
else {
    Write-Output "No Docker config files found."
}
