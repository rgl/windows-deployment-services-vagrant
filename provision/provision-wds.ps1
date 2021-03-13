param(
    $domain = 'example.com'
)

# disable WINS NetBIOS on all the network interfaces.
# NB this is required to make sure the proxyDHCP ACK responses are not delayed;
#    a delay causes the PXE client to timeout and fail.
Write-Output 'Disabling WINS NetBIOS...'
Get-CimInstance Win32_NetworkAdapterConfiguration `
    | Where-Object -Property TcpipNetbiosOptions -ne $null `
    | Invoke-CimMethod -MethodName SetTcpipNetbios -Arguments @{TcpipNetbiosOptions=[UInt32]2} `
    | Out-Null

Write-Output 'Installing the Windows Deployment Services (WDS)...'
Install-WindowsFeature WDS-Deployment -IncludeManagementTools

# install the tftp client.
# e.g. tftp -i wds.example.com get boot\x64\wdsmgfw.efi
Install-WindowsFeature TFTP-Client

# configure wds.
Start-PowerShellScriptAs "vagrant@$domain" vagrant @'
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Output 'Initializing WDS...'
# see https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-initialize-server
# NB this will create an object in the AD at, e.g.:
#       CN=wds.example.com,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com
wdsutil /Verbose /Progress /Initialize-Server /RemInst:C:\RemoteInstall | Out-String -Stream
# NB you can ignore the following /Initialize-Server error:
#       An error occurred while trying to execute the command.
#       Error Code: 0x41D
#       Error Description: The service did not respond to the start or control request in a timely fashion.
# NB restarting the service will make it work.
Restart-Service WDSServer

Write-Output 'Configuring WDS...'
# see https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-set-server
wdsutil /Set-Server /UseDhcpPorts:No /DhcpOption60:Yes | Out-String -Stream # because DHCP and WDS are running in the same machine.
wdsutil /Set-Server /AutoAddPolicy /Policy:Disabled /AnswerClients:All | Out-String -Stream

# Copy C:\RemoteInstall\boot\x64\wdsmgfw.efi to C:\RemoteInstall\boot\x64 because
# for some odd reason its not there... but its needed for PXE booting a client.
# NB When using the UI to import a boot.wim file, the C:\RemoteInstall\boot\x64 is
#    correctly populated and the following files are all the same:
#       C:\Windows\System32\RemInst\boot\x64\wdsmgfw.efi
#       C:\RemoteInstall\boot\x64\wdsmgfw.efi
#    NB all the common boot files come from a boot.wim (e.g. 1\Windows\Boot\PXE\wdsmgfw.efi).
$remoteInstallPath = 'C:\RemoteInstall\boot\x64\wdsmgfw.efi'
if (!(Test-Path $remoteInstallPath)) {
    $systemRemoteInstallPath = 'C:\Windows\System32\RemInst\boot\x64\wdsmgfw.efi'
    Write-Output "Copying missing wdsmgfw.efi file from $systemRemoteInstallPath to $remoteInstallPath..."
    Copy-Item $systemRemoteInstallPath $remoteInstallPath
}

Write-Output 'WDS Status:'
# see https://docs.microsoft.com/en-US/troubleshoot/windows-server/deployment/enable-logging-windows-deployment-service
# NB You can enable all the wds logs with:
#   Get-WinEvent -ListLog 'Microsoft-Windows-Deployment-Services-Diagnostics/*' | ForEach-Object {$_.IsEnabled = $true; $_.SaveChanges()}
# NB The Microsoft-Windows-Deployment-Services-Diagnostics/Metdata contains the PXE transactions.
wdsutil /Get-Server /Show:All /Detailed | Out-String -Stream

# Show the x64 boot loader settings.
Write-Output 'Default x64 boot loader settings:'
bcdedit /store C:\RemoteInstall\Boot\x64\default.bcd /enum all
'@
