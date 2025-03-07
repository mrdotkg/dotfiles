# Install Python on Windows 11

# Define the URL for the latest Python release
$pythonUrl = "https://www.python.org/ftp/python/3.9.7/python-3.9.7-amd64.exe"

# Define the installation path
$installPath = "C:\Python39"

# Download the Python installer
$installerPath = "$env:TEMP\python-3.9.7-amd64.exe"
Invoke-WebRequest -Uri $pythonUrl -OutFile $installerPath

# Install Python
Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 TargetDir=$installPath" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "Python installation completed successfully."
