@powershell -NoProfile -ExecutionPolicy Unrestricted "cd %~dp0;$s=[scriptblock]::create((gc %~f0|?{$_.readcount -gt 1})-join\"`n\");&$s" %*&goto:eof

# Check Administrators
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole("Administrators")) {
    Write-Host "Please run as administrator."
    pause
    exit
}

$current_dir = $(Get-Location).Path
$scripts = Join-Path $current_dir scripts

New-Item $scripts -ItemType Directory
Set-Location $scripts

# Disable Windows Update
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name WindowsUpdate
New-Item HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate -Name AU
New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU -Name NoAutoUpdate -Value 1

# Remove Bloadwares
Invoke-WebRequest "https://raw.githubusercontent.com/Sycnex/Windows10Debloater/master/Windows10SysPrepDebloater.ps1" -OutFile .\Windows10SysPrepDebloater.ps1
Unblock-File .\Windows10SysPrepDebloater.ps1
.\Windows10SysPrepDebloater.ps1 -Sysprep -Debloat -Privacy

# Disable UAC
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "ConsentPromptBehaviorAdmin" -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "PromptOnSecureDesktop" -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "EnableLUA" -Value 0

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -DisableScriptScanning $true -ExclusionPath $scripts
Invoke-WebRequest "https://raw.githubusercontent.com/jeremybeaume/tools/master/disable-defender.ps1" -OutFile .\disable-defender.ps1
$(Get-Content .\disable-defender.ps1) -replace "Read-Host","# Read-Host" | Out-File $scripts\disable-defender.ps1
Unblock-File $scripts\disable-defender.ps1
.\disable-defender.ps1

# Make FLARE VM Installer
Invoke-WebRequest "https://raw.githubusercontent.com/mandiant/flare-vm/main/install.ps1" -OutFile .\install.ps1
Unblock-File .\install.ps1

$link = "$current_dir\flarevm-installer.lnk"
$powershell_path = '"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"'
$cmdargs = "-ExecutionPolicy Unrestricted .\install.ps1"
    
$res = New-Item $(Split-Path -Path $link -Parent) -ItemType Directory -Force
$WshShell = New-Object -comObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($link)
$shortcut.TargetPath = $powershell_path
$shortcut.Arguments = $cmdargs
$shortcut.WorkingDirectory = $scripts
$shortcut.Save()

Restart-Computer -Confirm