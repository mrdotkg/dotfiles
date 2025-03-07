# Install fonts on Windows 11

# Define the fonts directory
$fontsDir = "$PSScriptRoot"

# Get all font files in the directory
$fontFiles = Get-ChildItem -Path $fontsDir -Filter *.ttf

# Install each font
foreach ($fontFile in $fontFiles) {
    $fontDest = "$env:SystemRoot\Fonts\$($fontFile.Name)"
    Copy-Item -Path $fontFile.FullName -Destination $fontDest -Force
    $fontRegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fontName = $fontFile.BaseName
    Set-ItemProperty -Path $fontRegKey -Name $fontName -Value $fontFile.Name
}

Write-Output "Fonts installation completed successfully."
