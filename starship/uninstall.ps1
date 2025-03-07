# Uninstall Starship
Write-Output "Uninstalling Starship..."
Remove-Item -Path "$env:USERPROFILE\.cargo\bin\starship.exe" -Force

# Remove Starship config files
Write-Output "Removing Starship config files..."
$configPath = "$env:USERPROFILE\.config\starship"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Starship config files removed successfully."
}
else {
    Write-Output "No Starship config files found."
}
