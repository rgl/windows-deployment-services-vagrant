Write-Output 'Installing the Routing feature...'
Install-WindowsFeature Routing -IncludeManagementTools

# enable LAN routing.
Install-RemoteAccess -VpnType RoutingOnly

# enable full NAT from the domain interface through the vagrant interface.
Write-Output 'Configuring NAT...'
netsh routing ip nat install
netsh routing ip nat add interface vagrant mode=full
netsh routing ip nat add interface domain
netsh routing ip nat show interface
