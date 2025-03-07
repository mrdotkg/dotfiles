# Install Azure CLI on Windows 11

# Define the URL for the latest Azure CLI release
$azureCliUrl = "https://aka.ms/installazurecliwindows"

# Define the installation path
$installPath = "$env:ProgramFiles\Microsoft SDKs\Azure\CLI2"

# Download the Azure CLI installer
$installerPath = "$env:TEMP\AzureCLI.msi"
Invoke-WebRequest -Uri $azureCliUrl -OutFile $installerPath

# Install Azure CLI
Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "Azure CLI installation completed successfully."
