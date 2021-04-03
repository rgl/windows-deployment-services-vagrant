function Add-WindowsImageVirtIoDeviceDrivers($imagePath, $imageIndex) {
    $mountPath = "c:\tmp\offline-windows-image\$(Split-Path -Leaf $imagePath)"
    mkdir -Force $mountPath | Out-Null
    $image = Get-WindowsImage -ImagePath $imagePath -Index $imageIndex
    $imageName = $image.ImageName
    Write-Output "Mounting #$imageIndex $imageName..."
    Mount-WindowsImage -ImagePath $imagePath -Index $imageIndex -Path $mountPath | Out-Null
    try {
        $image = Mount-DiskImage -PassThru 'c:\vagrant\tmp\virtio-win-0.1.190.iso'
        try {
            $volume = Get-Volume -DiskImage $image
            $driversRootPath = "$($volume.DriveLetter):"
            # NB we cannot use Import-WdsDriverPackage because it refuses to
            #    import unsigned drivers, even though they are signed with a
            #    certificate in the machine trusted publishers certificate
            #    store.
            # NB Signed virtio certificates seem to only be available to
            #    RedHat customers.
            #    See https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md#virtio-win-driver-signatures
            #    See https://github.com/virtio-win/virtio-win-guest-tools-installer/issues/11#issuecomment-696481340
            Get-ChildItem -Directory $driversRootPath | ForEach-Object {
                $driversPath = "$($_.FullName)\2k19\amd64"
                if (Test-Path $driversPath) {
                    Get-ChildItem "$driversPath\*.inf" | ForEach-Object {
                        Write-Output "Importing driver from $_..."
                        Add-WindowsDriver `
                            -ForceUnsigned `
                            -Path $mountPath `
                            -Driver $_ `
                            | Out-Null
                    }
                }
            }
            #Write-Output "Image 3rd party drivers:"
            #Get-WindowsDriver -Path $mountPath
        } finally {
            Dismount-DiskImage $image.ImagePath | Out-Null
        }
        Write-Output "Dismounting #$imageIndex $imageName..."
        Dismount-WindowsImage -Path $mountPath -Save | Out-Null
        Remove-Item $mountPath
    } catch {
        Dismount-WindowsImage -Path $mountPath -Discard | Out-Null
        throw
    }
}

function Get-WindowsImageIndex($imagePath, $name) {
    [xml]$xml = 7z x -so $imagePath '[1].xml' | Out-String
    $image = $xml.WIM.IMAGE | Where-Object {$_.NAME -eq $name} | Select-Object -First 1
    return [int]$image.INDEX
}

@(
    ,@{
        path = "windows-2019-17763.737.190906-2324.rs5_release_svc_refresh_SERVER_EVAL_x64FRE_en-us_1.iso"
        imageName = "Windows Server 2019 SERVERSTANDARD"
        imageBaseFileName = 'windows-server-2019-standard'
    }
) | ForEach-Object {
    $imagePath = "c:\vagrant\tmp\$($_.path)"
    $imageName = $_.imageName
    $imageBaseFileName = $_.imageBaseFileName
    $imageGroup = $_.imageName
    Write-Output "Importing $imagePath..."
    $image = Mount-DiskImage -PassThru $imagePath
    try {
        $volume = Get-Volume -DiskImage $image
        $sourceBootImagePath = "$($volume.DriveLetter):\sources\boot.wim"
        $sourceInstallImagePath = "$($volume.DriveLetter):\sources\install.wim"
        if (!(Get-WdsBootImage -ImageName $imageName)) {
            $bootImagePath = "C:\tmp\$imageBaseFileName-boot.wim"
            Copy-Item $sourceBootImagePath $bootImagePath
            Set-ItemProperty -Path $bootImagePath -Name IsReadOnly -Value $false
            Get-WindowsImage -ImagePath $bootImagePath | ForEach-Object {
                Add-WindowsImageVirtIoDeviceDrivers $bootImagePath $_.ImageIndex
            }
            Write-Output "Importing boot image $imageName from $bootImagePath..."
            Import-WdsBootImage `
                -Path $bootImagePath `
                -NewImageName $imageName `
                | Out-Null
            Remove-Item $bootImagePath
        }
        if (!(Get-WdsInstallImageGroup -ErrorAction SilentlyContinue -Name $imageGroup)) {
            New-WdsInstallImageGroup -Name $imageGroup | Out-Null
        }
        if (!(Get-WdsInstallImage -ErrorAction SilentlyContinue -ImageGroup $imageGroup -ImageName $imageName)) {
            $installImagePath = "C:\tmp\$imageBaseFileName-install.wim"
            Copy-Item $sourceInstallImagePath $installImagePath
            Set-ItemProperty -Path $installImagePath -Name IsReadOnly -Value $false
            # NB we cannot use Get-WindowsImage because its -Name is actually
            #    searching in the wim DISPLAYNAME property BUT
            #    Import-WdsInstallImage -ImageName uses the wim NAME property.
            #       <NAME>Windows Server 2019 SERVERSTANDARD</NAME>
            #       vs
            #       <DISPLAYNAME>Windows Server 2019 Standard Evaluation (Desktop Experience)</DISPLAYNAME>
            $imageIndex = Get-WindowsImageIndex -ImagePath $installImagePath -Name $imageName
            Add-WindowsImageVirtIoDeviceDrivers $installImagePath $imageIndex
            Write-Output "Importing install image #$imageIndex $imageName from $installImagePath..."
            Import-WdsInstallImage `
                -ImageGroup $imageGroup `
                -ImageName $imageName `
                -Path $installImagePath `
                | Out-Null
            Remove-Item $installImagePath
        }
    } finally {
        Dismount-DiskImage $image.ImagePath | Out-Null
    }
}
