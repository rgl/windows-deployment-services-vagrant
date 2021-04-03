# About

This is an example [Windows Deployment Services (WDS)](https://en.wikipedia.org/wiki/Windows_Deployment_Services) vagrant environment.

## Usage

Install and start the [Windows Domain Controller environment](https://github.com/rgl/windows-domain-controller-vagrant) in `../windows-domain-controller-vagrant`.

Copy the Windows 2019 ISO to the `tmp` directory (the exact ISO flename is
defined in [provision/provision-wds-images.ps1](provision/provision-wds-images.ps1)).

Launch the `wds` environment:

```bash
vagrant up --provider=libvirt wds # or --provider=hyperv
```

Launch the known `client` environment and watch it automatically install
windows:

```bash
bash create_empty_box.sh
vagrant up --provider=libvirt client # or --provider=hyperv
# Open the VM console to see it network booting and install windows.
```

Launch the new/unknown `newclient` environment and watch it show a wds client
prompt asking the user to choose an image to install:

```bash
vagrant up --provider=libvirt newclient # or --provider=hyperv
# Open the VM console to see it network booting.
```

**NB** Vagrant will fail to connect to the VM; the idea is just to see it PXE boot.

## Open Questions

Can you help with any of the following problems?

* Why `/JoinDomain:Yes` prevents unattend OOBE/Autologon/FirstLogonCommands
  from working?

## Notes

* When you launch the `wds` environment multiple times, these Active Directory
  objects are [automatically removed](provision/add-to-domain.ps1)
  to make sure WDS starts with the default configuration:
  * `CN=DhcpRoot,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com`
  * `CN=wds.example.com,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com`
  * `CN=WDS,CN=Computers,DC=example,DC=com`
  * `CN=client,CN=Computers,DC=example,DC=com`
* Slow DNS/NetBIOS responses will break WDS (e.g. it will be slow to start,
  or even never starts) and PXE boot (e.g. fail to find a boot image).
* You can target a specific device (e.g. MAC address) by prestaging it.
  * You can prestage a device through the Active Directory Prestaged
    devices node on the WDS Manager or with `wdsutil /Set-Device`.
  * This would also allow you to use a different unattended file and
    boot image.
  * See [provision/provision-wds-unattend.ps1](provision/provision-wds-unattend.ps1).
* All credentials flow through the network in cleartext and are saved at
  `C:\Windows\Panther\unattend.xml` with read permissions for every user.
* You can open `.wim` files with 7-Zip.
* You can use the [Microsoft Deployment Toolkit (MDT)](https://en.wikipedia.org/wiki/Microsoft_Deployment_Toolkit)
  to create custom Windows images that you can deploy from the WDS server.
* Some configuration steps are awkwardly run as the `vagrant` domain
  account (instead of the local `vagrant` account). If you known a better
  way, please let us know!

## Troublehsoot

* Press the `SHIFT+F10` key combination to open a Command Prompt window.
  * This works in WinPE and when booting Windows (e.g. while executing the
    `specialize` configuration pass).
* The unattend file is saved at `C:\Windows\Panther\unattend.xml`.
* The logs are saved at `C:\Windows\Panther`.

## References

* [Windows Deployment Services (WDS)](https://docs.microsoft.com/en-us/windows/deployment/windows-deployment-scenarios-and-tools#windows-deployment-services).
  * [wdsutil /Set-Server](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-set-server).
  * [wdsutil /Set-Device](https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/wdsutil-set-device).
* [Windows Setup Technical Reference](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-technical-reference).
* [Windows Setup Configuration Passes](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-setup-configuration-passes).
* [Microsoft Deployment Toolkit (MDT)](https://docs.microsoft.com/en-us/windows/deployment/windows-deployment-scenarios-and-tools#microsoft-deployment-toolkit).
