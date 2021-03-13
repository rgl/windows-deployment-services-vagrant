param(
    $vmId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host "ERROR: $_"
    Write-Host (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Host (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

$vm = Get-VM -Id $vmId

# reconfigure the vagrant management interface for network booting.
Get-VMNetworkAdapter -VM $vm | Sort-Object MacAddress | Select-Object -First 1 | ForEach-Object {
    $_ | Set-VMNetworkAdapter `
        -DhcpGuard On `
        -RouterGuard On `
        -MacAddressSpoofing Off
    $_ | Set-VMNetworkAdapterVlan -Untagged
    $vm | Set-VMFirmware -BootOrder $_
}
