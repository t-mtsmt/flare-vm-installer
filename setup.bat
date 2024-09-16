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

# Disable UAC
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "ConsentPromptBehaviorAdmin" -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "PromptOnSecureDesktop" -Value 0
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name "EnableLUA" -Value 0

# Make FLARE VM Installer
Invoke-WebRequest "https://raw.githubusercontent.com/mandiant/flare-vm/main/install.ps1" -OutFile .\install.ps1
Unblock-File .\install.ps1

$link = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp\flarevm-installer.lnk"
$powershell_path = '"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"'
$cmdargs = "-Command `"& {Start powershell -ArgumentList '-ExecutionPolicy Unrestricted \`"$workdir\install.ps1\`"' -Verb RunAs; Remove-Item  -Force `'$link`' -ErrorAction 'ignore'}`""

$res = New-Item $(Split-Path -Path $link -Parent) -ItemType Directory -Force
$WshShell = New-Object -comObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($link)
$shortcut.TargetPath = $powershell_path
$shortcut.Arguments = $cmdargs
$shortcut.WorkingDirectory = $workdir
$shortcut.Save()

# Disable Windows Defender
Set-MpPreference -DisableRealtimeMonitoring $true -DisableScriptScanning $true -ExclusionPath $scripts
Start-Sleep -Seconds 3.0
Invoke-WebRequest "https://github.com/ionuttbara/windows-defender-remover/archive/refs/tags/release_def_12_8.zip" -OutFile .\windows-defender-remover.zip
Expand-Archive -Path .\windows-defender-remover.zip
$windows_defender_remover_path = $(Resolve-Path .\windows-defender-remover\*)
$content = $(Get-Content $windows_defender_remover_path\Script_Run.bat) -replace "choice /C:yas /N","goto removedef"
Out-File -Encoding utf8 -InputObject $content $windows_defender_remover_path\Script_Run.bat
&"$windows_defender_remover_path\Script_Run.bat"
