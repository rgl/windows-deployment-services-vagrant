# the network interfaces do not have stable order, so we cannot sort them.
# instead we choose the first DHCP interface to be the vagrant interface, and
# the other interface is the router one.
# NB we might have gotten around this by sorting with the result of
#    Get-NetAdapterHardwareInfo, maybe, using the pci slot number, but that is
#    also, cumbersome. ultimately, the best compromise, that would be somewhat
#    straitforward to troubleshoot, would be to somehow use the MAC address,
#    and do this from vagrant itself.
#    see https://github.com/hashicorp/vagrant/issues/12271
# NB vagrant configures the interfaces by the mac address, but this information
#    is not readly available from our provision script.
# see https://github.com/hashicorp/vagrant/blob/v2.2.15/plugins/guests/windows/cap/configure_networks.rb#L11-L48
# see https://github.com/hashicorp/vagrant/blob/v2.2.15/plugins/guests/windows/guest_network.rb#L36-L46
# see https://github.com/hashicorp/vagrant/blob/v2.2.15/plugins/guests/windows/guest_network.rb#L48-L59

$adapters = Get-NetAdapter -Physical
$vagrantAdapter = $adapters | Where-Object {($_ | Get-NetIPInterface).Dhcp -eq 'Enabled'}
$domainAdapter = $adapters | Where-Object {$_ -ne $vagrantAdapter}
$vagrantAdapter | Rename-NetAdapter -NewName vagrant
$domainAdapter | Rename-NetAdapter -NewName domain
