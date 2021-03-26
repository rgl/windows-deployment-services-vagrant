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
