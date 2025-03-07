# Install AWS CLI on Windows 11

# Define the URL for the latest AWS CLI release
$awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"

# Define the installation path
$installPath = "$env:ProgramFiles\Amazon\AWSCLI"

# Download the AWS CLI installer
$installerPath = "$env:TEMP\AWSCLIV2.msi"
Invoke-WebRequest -Uri $awsCliUrl -OutFile $installerPath

# Install AWS CLI
Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "AWS CLI installation completed successfully."
