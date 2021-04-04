param(
    $domain = 'example.com',
    $domainControllerIp = '192.168.56.2'
)

$ErrorActionPreference = 'Stop'


$domainAdminstratorUsername = "vagrant@$domain"
$domainAdminstratorPassword = 'vagrant'
$domainAdminstratorCredential = New-Object `
    System.Management.Automation.PSCredential(
        $domainAdminstratorUsername,
        (ConvertTo-SecureString $domainAdminstratorPassword -AsPlainText -Force))


$systemVendor = (Get-WmiObject Win32_ComputerSystemProduct Vendor).Vendor


$vagrantManagementAdapter = Get-NetAdapter -Name vagrant
$domainControllerAdapter = Get-NetAdapter -Name domain


# do not dynamically register the vagrant management interface address in the domain dns server.
$vagrantManagementAdapter | Set-DNSClient -RegisterThisConnectionsAddress $false


# make sure the dns requests on this interface fail fast.
# NB we need to do this because there is no way to remove the DNS server from
#    a DHCP interface.
# NB this will basically force dns requests to fail with icmp destination port
#    unreachable (instead of timing out and delaying everything), which in turn
#    will force windows to query other dns servers (our domain dns server that
#    is set on the domain adapter).
# NB we cannot set this to the domain controller dns server because windows will
#    always use this interface to connect the dns server, but since its only
#    reachable through the domain adapter, the dns responses will never arrive
#    and dns client will eventually timeout and give up, and that breaks WDS
#    because dns takes too long to reply.
$vagrantManagementAdapter | Set-DnsClientServerAddress -ServerAddresses 127.127.127.127

# use the DNS server from the Domain Controller machine.
# this way we can correctly resolve DNS entries that are only defined on the Domain Controller.
$domainControllerAdapter | Set-DnsClientServerAddress -ServerAddresses $domainControllerIp


# trust the DC CA certificate.
# NB this is only needed to be able to start the next PSSession before joining
#    the machine to the domain.
Import-Certificate `
    -FilePath c:/vagrant/tmp/ExampleEnterpriseRootCA.der `
    -CertStoreLocation Cert:\LocalMachine\Root `
    | Out-Null

# remove previous Active Directory objects. e.g.:
#   CN=DhcpRoot,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com
#   CN=wds.example.com,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com
#   CN=WDS,CN=Computers,DC=example,DC=com
#   CN=client,CN=Computers,DC=example,DC=com
# NB we must use -SkipRevocationCheck because the DC certificate has a CRL
#    Distribution Point URL of ldap: that does not seem to work. maybe we
#    should configure the DC CA to include an http: URL too? feel free to
#    contribute it :-)
#    NB without this, it errors with:
#           The SSL certificate could not be checked for revocation
$session = New-PSSession `
    -UseSSL `
    -SessionOption (New-PSSessionOption -SkipRevocationCheck) `
    -ComputerName "dc.$domain" `
    -Credential $domainAdminstratorCredential
Invoke-Command -Session $session -ScriptBlock {
    $domain = Get-ADDomain
    $domainDnsRoot = $domain.DNSRoot
    $domainDn = $domain.DistinguishedName
    @(
        'CN=DhcpRoot,CN=NetServices,CN=Services,CN=Configuration'
        "CN=wds.$domainDnsRoot,CN=NetServices,CN=Services,CN=Configuration"
        'CN=WDS,CN=Computers'
        'CN=client,CN=Computers'
    ) | ForEach-Object {
        $id = "$_,$domainDn"
        # NB Get-ADObject does not honour -ErrorAction. 
        try {
            $o = Get-ADObject -Identity $id
            Write-Output "Removing the $id AD object..."
            $o | Remove-ADObject -Recursive -Confirm:$false
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # ignore.
        }
    }
}
Remove-PSSession $session


# add the machine to the domain.
# NB if you get the following error message, its because you MUST first run sysprep.
#       Add-Computer : Computer 'test-node-one' failed to join domain 'example.com' from its current workgroup 'WORKGROUP'
#       with following error message: The domain join cannot be completed because the SID of the domain you attempted to join
#       was identical to the SID of this machine. This is a symptom of an improperly cloned operating system install.  You
#       should run sysprep on this machine in order to generate a new machine SID. Please see
#       http://go.microsoft.com/fwlink/?LinkId=168895 for more information.
Write-Output "Adding this machine to the $domain domain..."
Add-Computer `
    -DomainName $domain `
    -Credential $domainAdminstratorCredential
