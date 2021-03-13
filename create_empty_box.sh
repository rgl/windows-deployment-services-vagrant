#!/bin/bash
set -euxo pipefail

VAGRANT_HOME="${VAGRANT_HOME:-$HOME/.vagrant.d}"

rm -rf tmp-wds-empty-windows
mkdir -p tmp-wds-empty-windows
pushd tmp-wds-empty-windows

# create and add an wds-empty-windows box to the hyperv provider.
TEMPLATE_BOX="$VAGRANT_HOME/boxes/windows-2019-amd64/0/hyperv"
if [ ! -d "$VAGRANT_HOME/boxes/wds-empty-windows/0/hyperv" ] && [ -d "$TEMPLATE_BOX" ]; then
rm -rf ./*
cp "$TEMPLATE_BOX/Vagrantfile" .
cp "$TEMPLATE_BOX/metadata.json" .
cp -r "$TEMPLATE_BOX/Virtual Machines" .
mkdir 'Virtual Hard Disks'
TEMPLATE_BOX="$TEMPLATE_BOX" PowerShell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command '
Get-ChildItem "$env:TEMPLATE_BOX/Virtual Hard Disks/*.vhdx" | ForEach-Object {
    New-VHD -Dynamic -SizeBytes 60GB -Path "$PWD/Virtual Hard Disks/$($_.Name)" | Out-Null
}
'
tar cvzf wds-empty-windows.box ./*
vagrant box add --force wds-empty-windows wds-empty-windows.box
fi

popd
rm -rf tmp-wds-empty-windows
