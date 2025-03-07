# Install Docker on Windows 11

# Define the URL for the latest Docker Desktop release
$dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"

# Define the installation path
$installPath = "$env:ProgramFiles\Docker"

# Download the Docker installer
$installerPath = "$env:TEMP\DockerInstaller.exe"
Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath

# Install Docker
Start-Process -FilePath $installerPath -ArgumentList "/install /quiet" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "Docker installation completed successfully."
