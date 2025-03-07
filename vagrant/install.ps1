# Install and configure Vagrant on Windows 11

# Define the URL for the latest Vagrant release
$vagrantUrl = "https://releases.hashicorp.com/vagrant/latest/vagrant_latest_x86_64.msi"

# Download and install Vagrant
Write-Output "Installing Vagrant..."
$vagrantInstaller = "$env:TEMP\vagrant_latest_x86_64.msi"
Invoke-WebRequest -Uri $vagrantUrl -OutFile $vagrantInstaller
Start-Process msiexec.exe -ArgumentList "/i $vagrantInstaller /quiet" -Wait
Remove-Item -Path $vagrantInstaller -Force

# Configure Vagrant
Write-Output "Configuring Vagrant..."
$vagrantConfigPath = "$env:USERPROFILE\.vagrant.d"
if (-Not (Test-Path -Path $vagrantConfigPath)) {
    New-Item -ItemType Directory -Path $vagrantConfigPath
}

# Create a basic Vagrant configuration file
$configFile = "$vagrantConfigPath\Vagrantfile"
$configContent = @"
# Vagrant Configuration
Vagrant.configure("2") do |config|
  config.vm.box = "hashicorp/bionic64"
end
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Vagrant installation and configuration completed successfully."
