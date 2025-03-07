# Uninstall Azure CLI
Write-Output "Uninstalling Azure CLI..."
$azureCliPath = "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2"
if (Test-Path $azureCliPath) {
    Remove-Item -Recurse -Force $azureCliPath
    Write-Output "Azure CLI uninstalled successfully."
}
else {
    Write-Output "Azure CLI is not installed."
}

# Remove Azure CLI config files
Write-Output "Removing Azure CLI config files..."
$configPath = "$env:USERPROFILE\.azure"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Azure CLI config files removed successfully."
}
else {
    Write-Output "No Azure CLI config files found."
}
