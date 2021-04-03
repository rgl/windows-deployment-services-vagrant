# copy unattend files.
Copy-Item unattend-* C:\RemoteInstall\WdsClientUnattend

$firmwareType = (Get-ComputerInfo -Property BiosFirmwareType).BiosFirmwareType.ToString().ToLowerInvariant()

# configure the wds server to use an unattend file to automatically boot
# new devices into the wds server.
# NB to further automate the installation see the autounattended files at
#    https://github.com/rgl/windows-vagrant, e.g.
#    https://github.com/rgl/windows-vagrant/blob/master/windows-2019-uefi/autounattend.xml
#    the major difference between those and the WDS unattended are:
#    * the use of the WindowsDeploymentServices element instead of
#      the ImageInstall element.
#    * the need for the Microsoft-Windows-International-Core component
#      in the oobeSystem configuration pass.
# NB the credentials flow in the clear over the network.
# NB this configures all machines/devices to use the same unattend file. to
#    target a specific device (e.g. by MAC address) you must prestage the
#    device.
#    NB you can prestage a device through the Active Directory Prestaged
#       devices node on the WDS Manager or with wdsutil /Set-Device.
#    NB this would also allow you to use a different unattended file and
#       boot image.
# see https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-set-server
Write-Output "Configuring WDS to automatically boot new devices..."
wdsutil `
    /Set-Server `
    /NewMachineDomainJoin:No `
    /WdsUnattend `
    /Policy:Enabled `
    /Architecture:x64 `
    /File:WdsClientUnattend\unattend-windows-2019-amd64-bios-new-device.xml `
    | Out-String -Stream
wdsutil `
    /Set-Server `
    /NewMachineDomainJoin:No `
    /WdsUnattend `
    /Policy:Enabled `
    /Architecture:x64uefi `
    /File:WdsClientUnattend\unattend-windows-2019-amd64-uefi-new-device.xml `
    | Out-String -Stream

# configure the wds server to use an unattend file to automatically install
# windows into a known device.
# NB this will create a Computer object in the AD at, e.g., CN=client,CN=Computers,DC=example,DC=com.
# TODO why /JoinDomain:Yes prevents unattend OOBE/Autologon/FirstLogonCommands from working?
# see https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-set-device
Write-Output "Configuring WDS to automatically boot the known client device..."
wdsutil `
    /Add-Device `
    /Device:client `
    /ID:080027000001 `
    /JoinDomain:No `
    /WdsClientUnattend:WdsClientUnattend\unattend-windows-2019-amd64-$firmwareType-known-device.xml `
    | Out-String -Stream
