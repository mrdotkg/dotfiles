# Uninstall SSH
Write-Output "Uninstalling OpenSSH Client..."
Remove-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Remove SSH config files
Write-Output "Removing SSH config files..."
$configPath = "$env:USERPROFILE\.ssh"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "SSH config files removed successfully."
}
else {
    Write-Output "No SSH config files found."
}
