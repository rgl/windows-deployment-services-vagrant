# to be able to configure hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'
# to make sure the nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

$domain                  = "example.com"
$domain_ip_address       = "192.168.56.2"
$wds_ip_address          = "192.168.56.5"
$dhcp_server_start_range = "192.168.56.10"
$dhcp_server_end_range   = "192.168.56.20"

Vagrant.configure("2") do |config|
  config.vm.define "wds" do |config|
    config.vm.box = "windows-2019-amd64"
    config.vm.hostname = "wds"

    config.vm.provider :libvirt do |lv, config|
      lv.memory = 2*1024
      lv.cpus = 2
      lv.cpu_mode = 'host-passthrough'
      lv.keymap = 'pt'
      # replace the default synced_folder with something that works in the base box.
      # NB for some reason, this does not work when placed in the base box Vagrantfile.
      config.vm.synced_folder '.', '/vagrant', type: 'smb', smb_username: ENV['USER'], smb_password: ENV['VAGRANT_SMB_PASSWORD']
    end

    config.vm.provider :hyperv do |hv, config|
      hv.linked_clone = true
      hv.enable_virtualization_extensions = false # nested virtualization.
      hv.cpus = 2
      hv.memory = 2*1024
      hv.vlan_id = ENV['HYPERV_VLAN_ID']
      # set the management network adapter.
      # see https://github.com/hashicorp/vagrant/issues/7915
      # see https://github.com/hashicorp/vagrant/blob/10faa599e7c10541f8b7acf2f8a23727d4d44b6e/plugins/providers/hyperv/action/configure.rb#L21-L35
      config.vm.network :private_network,
        bridge: ENV['HYPERV_SWITCH_NAME'] if ENV['HYPERV_SWITCH_NAME']
      config.vm.synced_folder '.', '/vagrant',
        type: 'smb',
        smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
        smb_password: ENV['VAGRANT_SMB_PASSWORD']
      # further configure the VM (e.g. manage the network adapters).
      config.trigger.before :'VagrantPlugins::HyperV::Action::StartInstance', type: :action do |trigger|
        trigger.ruby do |env, machine|
          # see https://github.com/hashicorp/vagrant/blob/v2.2.10/lib/vagrant/machine.rb#L13
          # see https://github.com/hashicorp/vagrant/blob/v2.2.10/plugins/kernel_v2/config/vm.rb#L716
          bridges = machine.config.vm.networks.select{|type, options| type == :private_network && options.key?(:hyperv__bridge)}.map do |type, options|
            mac_address_spoofing = false
            mac_address_spoofing = options[:hyperv__mac_address_spoofing] if options.key?(:hyperv__mac_address_spoofing)
            [options[:hyperv__bridge], mac_address_spoofing]
          end
          system(
            'PowerShell',
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            'provision/configure-hyperv-host.ps1',
            machine.id,
            bridges.to_json
          )
        end
      end
    end

    config.vm.network "private_network",
      ip: $wds_ip_address,
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false,
      hyperv__bridge: "windows-domain-controller"

    config.vm.provision "shell", path: "provision/ps.ps1", args: ["configure-hyperv-guest.ps1", $wds_ip_address]
    config.vm.provision "windows-sysprep"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-network-interface-names.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "locale.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["add-to-domain.ps1", $domain, $domain_ip_address]
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", inline: "$env:chocolateyVersion='0.10.15'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-base.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-router.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["provision-dhcp-server.ps1", $domain, $domain_ip_address, $wds_ip_address, $dhcp_server_start_range, $dhcp_server_end_range]
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["provision-wds.ps1", $domain]
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-wds-images.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-wds-unattend.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-firewall.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "summary.ps1"

    config.trigger.before :up do |trigger|
      trigger.run = {
        inline: '''bash -euc \'
certs=(
  ../windows-domain-controller-vagrant/tmp/ExampleEnterpriseRootCA.der
)
for cert_path in "${certs[@]}"; do
  if [ -f $cert_path ]; then
    mkdir -p tmp
    cp $cert_path tmp
  fi
done
\'
'''
      }
    end
  end

  define_client(config, 'client', '080027000001')
  define_client(config, 'newclient', nil)
end

def define_client(config, name, mac_address)
  config.vm.define name do |config|
    config.vm.box = "wds-empty-windows"
    config.vm.boot_timeout = 30*60 # seconds.
    config.winrm.username = 'Administrator'
    config.winrm.password = 'HeyH0Password'

    config.vm.provider :libvirt do |lv, config|
      config.vm.box = nil
      lv.memory = 2*1024
      lv.cpus = 2
      lv.cpu_mode = 'host-passthrough'
      lv.keymap = 'pt'
      lv.input :type => 'tablet', :bus => 'usb'
      lv.graphics_type = 'spice'
      lv.video_type = 'qxl'
      lv.channel :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
      lv.channel :type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio'
      lv.storage :file, :size => '60G', :type => 'qcow2'
      # NB currently its not possible to connect to the libvirt VMs because
      #    there is no way for libvirt-vagrant to obtain the VM IP address (it
      #    does not use a dnsmasq provided IP address; instead, the IP is
      #    assigned by the DHCP server in the WDS VM).
      lv.mgmt_attach = false
      lv.boot 'hd' # NB since this is using a BIOS firmware, the OS cannot change the boot order.
      lv.boot 'network'
      config.vm.network :private_network, mac: mac_address, libvirt__network_name: 'windows-domain-controller-vagrant0'
    end

    config.vm.provider :hyperv do |hv, config|
      hv.linked_clone = true
      hv.enable_virtualization_extensions = false # nested virtualization.
      hv.cpus = 2
      hv.memory = 2*1024
      config.vm.network :private_network, bridge: "windows-domain-controller"
      config.vm.synced_folder '.', '/vagrant',
        type: 'smb',
        smb_username: ENV['VAGRANT_SMB_USERNAME'] || ENV['USER'],
        smb_password: ENV['VAGRANT_SMB_PASSWORD']
      # further configure the VM (e.g. manage the network adapters).
      config.trigger.before :'VagrantPlugins::HyperV::Action::StartInstance', type: :action do |trigger|
        trigger.ruby do |env, machine|
          system(
            'PowerShell',
            '-NoLogo',
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            'provision/configure-hyperv-host-client.ps1',
            machine.id,
            mac_address
          )
        end
      end
    end

    config.vm.provision "shell", inline: 'Write-Output "Hello World from $env:COMPUTERNAME!"'
  end
end
