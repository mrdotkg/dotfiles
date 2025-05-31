# New Windows OS Setup Automation Script
Set-Variable -Name AppList -Value @(
    "AltSnap.AltSnap",
    "Valve.Steam",
    "Microsoft.PowerShell",
    "Neovim.Neovim",
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "WezTerm.WezTerm",
    "Notepads.NotepadsApp",
    "Discord.Discord",
    "Ditto.Ditto",
    "Nvidia.GeForceExperience",
    "AquaSnap.AquaSnap",
    # "Whatsapp.Whatsapp",
    "GlazeWM.GlazeWM"
)
function Install-Apps {
    param(
        [string[]]$Apps
    )
    foreach ($app in $Apps) {
        winget install --id $app -e --accept-source-agreements --accept-package-agreements
    }
}