# see https://docs.microsoft.com/en-us/windows-server/networking/technologies/dhcp/dhcp-deploy-wps

param(
    $domain = 'example.com',
    $domainIpAddress = '192.168.56.2',
    $wdsIpAddress = '192.168.56.5',
    $startRange = '192.168.56.10',
    $endRange = '192.168.56.20'
)

Write-Output 'Installing the DHCP service and administration tools...'
Install-WindowsFeature DHCP -IncludeManagementTools

Write-Output 'Creating the DHCP Administrators and DHCP Users local security groups...'
Add-DhcpServerSecurityGroup
Restart-Service DHCPServer

Write-Output 'Configuring the Domain Network DHCP scope...'
$scope = Add-DhcpServerv4Scope `
    -Name 'Domain Network' `
    -StartRange $startRange `
    -EndRange $endRange `
    -SubnetMask 255.255.255.0 `
    -LeaseDuration '00:30:00' `
    -State Active `
    -PassThru
$scope = Get-DhcpServerv4Scope | Where-Object {$_.Name -eq 'Domain Network'}
Set-DhcpServerv4OptionValue `
    -ScopeId $scope.ScopeId `
    -Router $wdsIpAddress `
    -DnsServer $domainIpAddress `
    -DnsDomain $domain

Write-Output 'Authorizing the DHCP server in Active Directory...'
# NB Add-DhcpServerInDC must to be run as a domain administrator account.
# NB this will create an object in the AD at, e.g.:
#       CN=wds.example.com,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com
Start-PowerShellScriptAs "vagrant@$domain" vagrant Add-DhcpServerInDC

Write-Output 'Authorizing the DHCP server in the Active Directory DNS...'
# TODO can this use a non domain administrator account?
Set-DhcpServerDnsCredential -Credential (New-Object `
    System.Management.Automation.PSCredential(
        "vagrant@$domain",
        (ConvertTo-SecureString "vagrant" -AsPlainText -Force)))

# Notify Server Manager that post-install DHCP configuration is complete.
Set-ItemProperty `
    -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 `
    -Name ConfigurationState `
    -Value 2
