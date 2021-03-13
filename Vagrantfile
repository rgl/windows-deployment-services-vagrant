# to be able to configure hyper-v vm.
ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

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
      libvirt__forward_mode: "route",
      libvirt__dhcp_enabled: false,
      hyperv__bridge: "windows-domain-controller"

    config.vm.provision "shell", path: "provision/ps.ps1", args: ["configure-hyperv-guest.ps1", $wds_ip_address]
    config.vm.provision "windows-sysprep"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "locale.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["add-to-domain.ps1", $domain, $domain_ip_address]
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", inline: "$env:chocolateyVersion='0.10.15'; iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex", name: "Install Chocolatey"
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["provision-dhcp-server.ps1", $domain, $domain_ip_address, $wds_ip_address, $dhcp_server_start_range, $dhcp_server_end_range]
    config.vm.provision "shell", path: "provision/ps.ps1", args: ["provision-wds.ps1", $domain]
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-wds-images.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-base.ps1"
    config.vm.provision "shell", reboot: true
    config.vm.provision "shell", path: "provision/ps.ps1", args: "provision-firewall.ps1"
    config.vm.provision "shell", path: "provision/ps.ps1", args: "summary.ps1"
  end

  config.vm.define "client" do |config|
    config.vm.box = "wds-empty-windows"
    config.vm.synced_folder '.', '/vagrant', disabled: true

    config.vm.provider :libvirt do |lv, config|
      config.vm.box = nil
      lv.memory = 2*1024
      lv.cpus = 2
      lv.cpu_mode = 'host-passthrough'
      lv.keymap = 'pt'
      lv.storage :file, :size => '60G', :type => 'qcow2'
      lv.mgmt_attach = false
      lv.boot 'network'
      config.vm.network :private_network, libvirt__network_name: 'windows-domain-controller-vagrant0'
    end

    config.vm.provider :hyperv do |hv, config|
      hv.linked_clone = true
      hv.enable_virtualization_extensions = false # nested virtualization.
      hv.cpus = 2
      hv.memory = 2*1024
      config.vm.network :private_network, bridge: "windows-domain-controller"
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
            machine.id
          )
        end
      end
    end
  end
end
