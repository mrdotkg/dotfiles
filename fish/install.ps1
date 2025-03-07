# Install Fish Shell on Windows 11

# Define the URL for the latest Fish Shell release
$fishUrl = "https://github.com/fish-shell/fish-shell/releases/latest/download/fish-3.3.1.msi"

# Define the installation path
$installPath = "$env:ProgramFiles\Fish"

# Download the Fish Shell installer
$installerPath = "$env:TEMP\fish.msi"
Invoke-WebRequest -Uri $fishUrl -OutFile $installerPath

# Install Fish Shell
Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "Fish Shell installation completed successfully."
