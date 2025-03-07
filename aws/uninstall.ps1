# Uninstall AWS CLI
Write-Output "Uninstalling AWS CLI..."
$awsCliPath = "$env:ProgramFiles\Amazon\AWSCLI"
if (Test-Path $awsCliPath) {
    Remove-Item -Recurse -Force $awsCliPath
    Write-Output "AWS CLI uninstalled successfully."
}
else {
    Write-Output "AWS CLI is not installed."
}

# Remove AWS CLI config files
Write-Output "Removing AWS CLI config files..."
$configPath = "$env:USERPROFILE\.aws"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "AWS CLI config files removed successfully."
}
else {
    Write-Output "No AWS CLI config files found."
}
