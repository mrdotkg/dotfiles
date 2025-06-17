# Windows OS Setup

## ISO

- Microwin ISO created by Chris Titus's WinUtil

## Apps

- AltSnap
- AOE4
- Autologon
- AquaSnap
- Discord
- Ditto
- Gigabytes Drivers and App Center Util
- Git
- GlazeWM
- Nvidia Graphics Driver
- Notepads
- Neovim
- Powershell 7
- Steam
- VSCode
- Whatsapp
- Wezterm

## Settings

### System

- Windows zoom 100%
- Windows theme dark
- Disable Cleartype, install mactype, configure it.
- Display 4k, HDR on, 120FPS
- Disable all startup apps
- Sign in with local account
- Enable OpenSSH server, Client and remote ssh into this pc from macOs from over local network
- Make powershell as default ssh shell.

### Taskbar

- Hide Search Menu in taskbar
- Disable Widgets, Weather

### Start Menu

- Remove apps from Start Menu
- Uninstall bloat apps

### Folder

- Default open Local Disc C

### MS Edge

- Setup Hotkey Super + E
- Addressbar search engine - Google

### Git

- Generate SSH key and configure on github
- Git username
- Git email

### Neovim

- Setup Hotkey
- Copy Config File

### Terminal

- Open Powershell 7 by default
- Setup Hotkey Super + X
- Copy Config file

### Wezterm

- Setup Hotkey
- Copy Config file

Commands Requiring Admin Privileges (Examples):
``` powershell
# User and Group Management:
Get-LocalUser, New-LocalUser, Remove-LocalUser, Rename-LocalUser (managing local user accounts) 
Get-LocalGroup, New-LocalGroup, Remove-LocalGroup, Add-LocalGroupMember, Get-LocalGroupMember (managing local groups and their members) 
Get-ADUser, New-ADUser, Remove-ADUser, Get-ADGroupMember (managing Active Directory users and groups - require domain administrator privileges) 
Get-ADGroup, New-ADGroup, Remove-ADGroup
Get-ADObject (when accessing objects with security descriptors) 
#System Configuration and Security:
Set-ExecutionPolicy (changing PowerShell execution policy) 
Get-Acl, Set-Acl (getting and setting access control lists for files and folders) 
Get-Process -FileVersionInfo (accessing file version information of processes – requires elevation for processes not owned by the current user) 
Enable-WindowsOptionalFeature, Disable-WindowsOptionalFeature (managing optional Windows features) 
Get-WindowsFeature (getting information about available and installed roles and features on server operating systems) 
New-ItemProperty, Remove-ItemProperty (modifying registry entries, which requires admin)
#Disk and File Management:
Format-Volume, Repair-Volume (formatting or repairing volumes)
New-Volume, Remove-Volume (creating or removing volumes)
Mount-DiskImage (mounting disk images)
Get-Disk, Set-Disk (managing disks)
Get-Partition, New-Partition (managing partitions)
Get-Volume, Set-Volume (managing volumes)
#Network Configuration:
Get-NetIPAddress, Set-NetIPAddress (managing IP addresses)
Get-NetAdapter, Set-NetAdapter (managing network adapters)
Get-NetRoute, Set-NetRoute (managing network routes)
New-NetFirewallRule, Set-NetFirewallRule (creating and modifying firewall rules)
#Software Installation and Management:
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i Setup.msi" (installing MSI packages) 
Get-WmiObject Win32_Product (getting installed products – can be slow and resource-intensive) 
Uninstall-Package (uninstalling packages using package managers like MSI or NuGet)
```