# Uninstall Kubernetes
Write-Output "Uninstalling Kubernetes..."
# ...existing code to uninstall Kubernetes...

# Remove Kubernetes config files
Write-Output "Removing Kubernetes config files..."
$configPath = "$env:USERPROFILE\.kube"
if (Test-Path $configPath) {
    Remove-Item -Recurse -Force $configPath
    Write-Output "Kubernetes config files removed successfully."
}
else {
    Write-Output "No Kubernetes config files found."
}
