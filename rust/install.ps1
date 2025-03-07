# Install Rust on Windows 11

# Download and install Rust using rustup
Invoke-WebRequest -Uri "https://sh.rustup.rs" -OutFile "$env:TEMP\rustup-init.exe"
Start-Process -FilePath "$env:TEMP\rustup-init.exe" -ArgumentList "-y" -Wait

# Remove the installer after installation
Remove-Item -Path "$env:TEMP\rustup-init.exe"

Write-Output "Rust installation completed successfully."
