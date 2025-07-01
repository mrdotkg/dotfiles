# Steam
winget install Valve.Steam -e --accept-source-agreements --accept-package-agreements

# PowerShell
winget install Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements

# Neovim
winget install Neovim.Neovim -e --accept-source-agreements --accept-package-agreements

# Disable Activity History
Get-ActivityHistory | Remove-Item

# Disable Cortana
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -Value 0

# Setup OpenSSH And Allow through Firewall
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
New-NetFirewallRule -Name 'OpenSSH Server (sshd)' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22

# Powershell 7
Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value 'C:\Program Files\PowerShell\7\pwsh.exe'

# Allow Remote Desktop
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0;
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'