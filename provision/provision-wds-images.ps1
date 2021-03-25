@(
    ,@{
        path = "windows-2019-17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
        imageName = "Windows Server 2019 SERVERSTANDARD"
    }
) | ForEach-Object {
    $imagePath = "c:\vagrant\tmp\$($_.path)"
    $imageName = $_.imageName
    $imageGroup = $_.imageName
    Write-Output "Importing $imagePath..."
    $image = Mount-DiskImage -PassThru $imagePath
    try {
        $volume = Get-Volume -DiskImage $image
        $bootImagePath = "$($volume.DriveLetter):\sources\boot.wim"
        $installImagePath = "$($volume.DriveLetter):\sources\install.wim"
        if (!(Get-WdsBootImage -ImageName $imageName)) {
            Write-Output "Importing boot image $imageName from $bootImagePath..."
            Import-WdsBootImage `
                -Path $bootImagePath `
                -NewImageName $imageName `
                | Out-Null
        }
        if (!(Get-WdsInstallImageGroup -ErrorAction SilentlyContinue -Name $imageGroup)) {
            New-WdsInstallImageGroup -Name $imageGroup | Out-Null
        }
        if (!(Get-WdsInstallImage -ErrorAction SilentlyContinue -ImageGroup $imageGroup -ImageName $imageName)) {
            Write-Output "Importing install image from $installImagePath..."
            Import-WdsInstallImage `
                -ImageGroup $imageGroup `
                -ImageName $imageName `
                -Path $installImagePath `
                | Out-Null
        }
    } finally {
        Dismount-DiskImage $image.ImagePath | Out-Null
    }
}

# configure the wds server to use an unattend file to automatically install
# windows.
# NB to further automate the installation see the autounattended files at
#    https://github.com/rgl/windows-vagrant, e.g.
#    https://github.com/rgl/windows-vagrant/blob/master/windows-2019-uefi/autounattend.xml
#    the major difference between those and the WDS unattended is the use of
#    the WindowsDeploymentServices element instead of ImageInstall element.
# NB the credentials flow in the clear over the network.
# NB this configures all machines/devices to use the same unattend file. to
#    target a specific device (e.g. by MAC address) you must prestage the
#    device.
#    NB you can prestage a device through the Active Directory Prestaged
#       devices node on the WDS Manager or with wdsutil /Set-Device.
#    NB this would also allow you to use a different unattended file and
#       boot image.
Write-Output "Configuring WDS to automatically install Windows..."
Copy-Item unattend-windows-2019-uefi.xml C:\RemoteInstall\WdsClientUnattend
wdsutil `
    /Set-Server `
    /WdsUnattend `
    /Policy:Enabled `
    /Architecture:x64uefi `
    /File:WdsClientUnattend\unattend-windows-2019-uefi.xml `
    | Out-String -Stream
