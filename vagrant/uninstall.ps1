# Uninstall Vagrant
Write-Output "Uninstalling Vagrant..."
Start-Process msiexec.exe -ArgumentList "/x {Vagrant Product Code} /quiet" -Wait

# Remove Vagrant config files
Write-Output "Removing Vagrant config files..."
$configPath = "$env:USERPROFILE\.vagrant.d"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Vagrant config files removed successfully."
}
else {
    Write-Output "No Vagrant config files found."
}
