# Install CMake on Windows 11

# Define the URL for the latest CMake release
$cmakeUrl = "https://github.com/Kitware/CMake/releases/latest/download/cmake-3.21.3-windows-x86_64.msi"

# Define the installation path
$installPath = "$env:ProgramFiles\CMake"

# Download the CMake installer
$installerPath = "$env:TEMP\cmake.msi"
Invoke-WebRequest -Uri $cmakeUrl -OutFile $installerPath

# Install CMake
Start-Process msiexec.exe -ArgumentList "/i $installerPath /quiet" -Wait

# Remove the installer after installation
Remove-Item -Path $installerPath

Write-Output "CMake installation completed successfully."
