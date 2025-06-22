# Steam - Installed with winget package manager, Steam is a digital distribution platform for video games;
winget install Valve.Steam -e --accept-source-agreements --accept-package-agreements

# PowerShell Task automation framework and scripting language designed for system administrators, offering powerful command-line capabilities;
winget install Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements

# Neovim Highly extensible text editor and an improvement over the original Vim editor.;
winget install Neovim.Neovim -e --accept-source-agreements --accept-package-agreements

# Disable Activity History Erases recent docs, clipboard, and run history.;
Get-ActivityHistory | Remove-Item

# Disable Cortana Disables Cortana, the virtual assistant in Windows.;
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0

# Setup OpenSSH And Allow through Firewall Sets up OpenSSH Server and Client and allows through Windows Firewall.;
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0;
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0;
Set-Service -Name sshd -StartupType 'Automatic';
Start-Service sshd;
New-NetFirewallRule -Name 'OpenSSH Server (sshd)' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22

# Powershell 7 as Default SSH Sets Powershell 7 as the default shell for SSH.;
Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value 'C:\Program Files\PowerShell\7\pwsh.exe'

# Allow Remote Desktop Enables Remote Desktop connections to the machine.;
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0;
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'