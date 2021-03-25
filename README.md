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

Launch the `client` environment:

```bash
bash create_empty_box.sh
vagrant up --provider=libvirt client # or --provider=hyperv
# You should open the VM console to see it network booting.
```

**NB** Vagrant will fail to connect to the VM; the idea is just to see it PXE boot.

## Notes

* If you launch the `wds` environment multiple times, you must manually remove
  these objects from the Active Directory:
  * `CN=DhcpRoot,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com`
  * `CN=wds.example.com,CN=NetServices,CN=Services,CN=Configuration,DC=example,DC=com`
* Slow DNS/NetBIOS responses will break WDS (e.g. it will be slow to start,
  or even never starts) and PXE boot (e.g. fail to find a boot image).
* In Windows PE you can press the `SHIFT+F10` key combination to open a
  Command Prompt window.
* You can target a specific device (e.g. MAC address) by prestaging it.
  * You can prestage a device through the Active Directory Prestaged
    devices node on the WDS Manager or with `wdsutil /Set-Device`.
  * This would also allow you to use a different unattended file and
    boot image.
  * **NB** All credentials flow through the network in cleartext.
* You can open `.wim` files with 7-Zip.
* You can use the [Microsoft Deployment Toolkit (MDT)](https://en.wikipedia.org/wiki/Microsoft_Deployment_Toolkit)
  to create custom Windows images that you can deploy from the WDS server.
* Some configuration steps are awkwardly run as the `vagrant` domain
  account (instead of the local `vagrant` account). If you known a better
  way, please let us know!
