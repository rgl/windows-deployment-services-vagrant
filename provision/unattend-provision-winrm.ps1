Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Write-Host
    Write-Host 'Sleeping for 60m to give you time to look around the virtual machine before self-destruction...'
    Start-Sleep -Seconds (60*60)
    Exit 1
}

## for troubleshoot purposes, save this script output to a file.
#Start-Transcript C:\unattend-winrm.txt

## for troubleshoot purposes, save the current user details. this will be later displayed by provision.ps1.
#whoami /all >C:\unattend-whoami.txt

# move all (non-domain) network interfaces into the private profile to make winrm happy (it needs at
# least one private interface; for vagrant its enough to configure the first network interface).
# NB in windows server it would be enough to call winrm -force argument, but
#    in windows client 10, we must set the network interface profile.
Get-NetConnectionProfile `
    | Where-Object {$_.NetworkCategory -ne 'DomainAuthenticated'} `
    | Set-NetConnectionProfile -NetworkCategory Private

# configure WinRM.
Write-Output 'Configuring WinRM...'
winrm quickconfig -quiet
winrm set winrm/config/service '@{AllowUnencrypted="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
# make sure the WinRM service startup type is delayed-auto
# even when the default config is auto (e.g. Windows 2019
# changed that default).
# WARN do not be tempted to change the default WinRM service startup type from
#      delayed-auto to auto, as the later proved to be unreliable.
$result = sc.exe config WinRM start= delayed-auto
if ($result -ne '[SC] ChangeServiceConfig SUCCESS') {
    throw "sc.exe config failed with $result"
}

# dump the WinRM configuration.
Write-Output 'WinRM Configuration:'
winrm enumerate winrm/config/listener
winrm get winrm/config
winrm id

# disable UAC remote restrictions.
# see https://support.microsoft.com/en-us/help/951016/description-of-user-account-control-and-remote-restrictions-in-windows
# see https://docs.microsoft.com/en-us/windows/desktop/wmisdk/user-account-control-and-wmi#handling-remote-connections-under-uac
New-ItemProperty `
    -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' `
    -Name LocalAccountTokenFilterPolicy `
    -Value 1 `
    -Force `
    | Out-Null

# make sure winrm can be accessed from any network location.
New-NetFirewallRule `
    -DisplayName WINRM-HTTP-In-TCP-VAGRANT `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 5985 `
    | Out-Null
