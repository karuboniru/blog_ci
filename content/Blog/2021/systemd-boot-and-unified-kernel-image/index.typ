#import "../../../../config.typ": template, tufted
#import "@preview/theorion:0.6.0": *
// 原文件: source/_posts/systemd-boot-and-unified-kernel-image.md
// 原文时间: 2021-04-30 11:32:57
#let post = (
  title: [Switch to systemd-boot and Unified Kernel Image on Fedora],
  date: datetime(year: 2021, month: 4, day: 30),
  lang: "en",
  tag: ("Linux",),
  comments: true,
)
#show: template.with(..post)

#title()

#caution-block[
I am not responsible for bricked computers, system instabilities, dead cats, thermonuclear war or you getting fired because you lost important work.

Please make a backup of your device or of the data, and make a boot drive in case of necessity. Do some research if you have any concerns about steps documented in this guide.

YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.
]

= Why are you doing this kind of wried thing?
Ok… Since I want to sign secure boot on my own, without breaking Fedora's current multi-kernel behavior. Luckily that #link("https://www.freedesktop.org/software/systemd/man/kernel-install.html")[kernel-install.d] provides enough power to customize kernel install process.

= Switch to Systemd-Boot (from Grub+Shim)
#caution-block[
ENSURE YOU ARE ON UEFI BEFORE DOING THIS.
]

It is basically same as #link("https://kowalski7cc.xyz/blog/systemd-boot-fedora-32")[kowalski7cc's article] with minor modifications to make it work with Unified Kernel Image

== Move efi mount point
You may want to check if modifications to `/etc/fstab` is sanity.

#figure(
  caption: [Create and mount the EFI System Partition at `/efi`],
  [
```bash
sudo mkdir /efi
sudo sed -i "s|/boot/efi|/efi|g" /etc/fstab
```
  ],
)

Now remount efi:

#figure(
  caption: [Remount the EFI System Partition at `/efi`],
  [
```bash
sudo umount /boot/efi
sudo mount /efi
```
  ],
)

== Install systemd-boot
You may want to backup files at `/boot/efi` and `/boot` before this.

#figure(
  caption: [Prepare `/efi` and remove GRUB-related protected-package rules],
  [
```bash
sudo mkdir /efi/$(cat /etc/machine-id)
sudo rm /etc/dnf/protected.d/grub* /etc/dnf/protected.d/shim*   # needed in some cases, if next command won't run.
# in case following command fails, delete /etc/dnf/protected.d/grub* and /etc/dnf/protected.d/shim*
sudo dnf remove grubby grub2\* shim\* memtest86\ && sudo rm -rf /boot/grub2 && sudo rm -rf /boot/loader
cat /proc/cmdline | cut -d ' ' -f 2- | sudo tee /etc/kernel/cmdline
sudo bootctl install
```
  ],
)

And you may umount `/boot` and remove its fstab entry now since it will no longer be used.

#caution-block[
DO NOT REBOOT UNTIL I TOLD YOU THAT YOU CAN.
]

= Change kernel-install scripts to enable Unified Kernel Image
== Disable old initrd generation
Do following:

#figure(
  caption: [Disable the default Dracut kernel-install plugin],
  [
```bash
sudo ln -s /dev/null /etc/kernel/install.d/50-dracut.install
```
  ],
)

to disable default initrd generation and installation, we are going to move this work in other scripts.

== Change installation of kernel image
#figure(
  caption: [`/etc/kernel/install.d/90-loaderentry.install` for unified kernel images (#link("https://gist.github.com/karuboniru/d47b0a70f53614d90d30946745c33ab9")[source]); set the file's `+x` permission],
  [
```bash
#!/usr/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
# SPDX-License-Identifier: LGPL-2.1-or-later
#
# This file is part of systemd.
#
# systemd is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# systemd is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with systemd; If not, see <http://www.gnu.org/licenses/>.

COMMAND="$1"
KERNEL_VERSION="$2"
ENTRY_DIR_ABS="$3"
KERNEL_IMAGE="$4"
INITRD_OPTIONS_START="5"

MACHINE_ID=$KERNEL_INSTALL_MACHINE_ID

BOOT_ROOT=${ENTRY_DIR_ABS%/$MACHINE_ID/$KERNEL_VERSION}
BOOT_MNT=$(stat -c %m $BOOT_ROOT)
ENTRY_DIR=${ENTRY_DIR_ABS#$BOOT_MNT}

if [[ $COMMAND == remove ]]; then
    rm -f "$BOOT_ROOT/loader/entries/$MACHINE_ID-$KERNEL_VERSION.conf"
    rm -f "$BOOT_ROOT/loader/entries/$MACHINE_ID-$KERNEL_VERSION+"*".conf"
    rm -f "$BOOT_ROOT/EFI/Linux/$KERNEL_VERSION-$MACHINE_ID.efi"
    rm -f "$BOOT_ROOT/EFI/Linux/$KERNEL_VERSION-$MACHINE_ID+"*".efi"
    exit 0
fi

if ! [[ $COMMAND == add ]]; then
    exit 1
fi

if ! [[ $KERNEL_IMAGE ]]; then
    exit 1
fi

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
elif [[ -f /usr/lib/os-release ]]; then
    . /usr/lib/os-release
fi

if ! [[ $PRETTY_NAME ]]; then
    PRETTY_NAME="Linux $KERNEL_VERSION"
fi

if [[ -f /etc/kernel/cmdline ]]; then
    read -r -d '' -a BOOT_OPTIONS < /etc/kernel/cmdline
elif [[ -f /usr/lib/kernel/cmdline ]]; then
    read -r -d '' -a BOOT_OPTIONS < /usr/lib/kernel/cmdline
else
    declare -a BOOT_OPTIONS

    read -r -d '' -a line < /proc/cmdline
    for i in "${line[@]}"; do
        [[ "${i#initrd=*}" != "$i" ]] && continue
        [[ "${i#BOOT_IMAGE=*}" != "$i" ]] && continue
        BOOT_OPTIONS+=("$i")
    done
fi

if [[ -f /etc/kernel/tries ]]; then
    read -r TRIES </etc/kernel/tries
    if ! [[ "$TRIES" =~ ^[0-9]+$ ]] ; then
        echo "/etc/kernel/tries does not contain an integer." >&2
        exit 1
    fi
    LOADER_ENTRY="$BOOT_ROOT/EFI/Linux/$KERNEL_VERSION-$MACHINE_ID+$TRIES.efi"
else
    LOADER_ENTRY="$BOOT_ROOT/EFI/Linux/$KERNEL_VERSION-$MACHINE_ID.efi"
fi

mkdir -p "${LOADER_ENTRY%/*}" || {
    echo "Could not create loader entry directory '${LOADER_ENTRY%/*}'." >&2
    exit 1
}

[ "$KERNEL_INSTALL_VERBOSE" -gt 0 ] && \
    echo "Creating $LOADER_ENTRY"
{
unset noimageifnotneeded
for ((i=0; i < "${#BOOT_OPTIONS[@]}"; i++)); do
# shellcheck disable=SC1001
if [[ ${BOOT_OPTIONS[$i]} == root\=PARTUUID\=* ]]; then
noimageifnotneeded="yes"
break
fi
done
dracut --kernel-cmdline "${BOOT_OPTIONS[*]}" -f ${noimageifnotneeded:+--noimageifnotneeded} --uefi "$LOADER_ENTRY" "$KERNEL_VERSION"
}
exit 0
```
  ],
)

The `dracut --kernel-cmdline "${BOOT_OPTIONS[*]}" -f ${noimageifnotneeded:+--noimageifnotneeded} --uefi "$LOADER_ENTRY" "$KERNEL_VERSION"` does the magic to enable Unified Kernel Image.

== Change generation of rescue image
#figure(
  caption: [`/etc/kernel/install.d/51-dracut-rescue.install` for unified rescue images (#link("https://gist.github.com/karuboniru/2e6fb6dc48094a7bbd9671da42a83960")[source]); set the file's `+x` permission],
  [
```bash
#!/usr/bin/bash

export LANG=C

COMMAND="$1"
KERNEL_VERSION="$2"
ENTRY_DIR_ABS="$3"
KERNEL_IMAGE="$4"


dropindirs_sort()
{
    suffix=$1; shift
    args=("$@")
    files=$(
        while (( $# > 0 )); do
            for i in "${1}"/*"${suffix}"; do
                [[ -f $i ]] && echo "${i##*/}"
            done
            shift
        done | sort -Vu
    )

    for f in $files; do
        for d in "${args[@]}"; do
            if [[ -f "$d/$f" ]]; then
                echo "$d/$f"
                continue 2
            fi
        done
    done
}

[[ -f /etc/os-release ]] && . /etc/os-release

if [[ ${KERNEL_INSTALL_MACHINE_ID+x} ]]; then
    MACHINE_ID=$KERNEL_INSTALL_MACHINE_ID
elif [[ -f /etc/machine-id ]] ; then
    read -r MACHINE_ID < /etc/machine-id
fi

if ! [[ $MACHINE_ID ]]; then
    exit 0
fi

if [[ -f /etc/kernel/cmdline ]]; then
    read -r -d '' -a BOOT_OPTIONS < /etc/kernel/cmdline
elif [[ -f /usr/lib/kernel/cmdline ]]; then
    read -r -d '' -a BOOT_OPTIONS < /usr/lib/kernel/cmdline
else
    declare -a BOOT_OPTIONS

    read -r -d '' -a line < /proc/cmdline
    for i in "${line[@]}"; do
        [[ "${i#initrd=*}" != "$i" ]] && continue
        BOOT_OPTIONS+=("$i")
    done
fi
BOOT_ROOT=${ENTRY_DIR_ABS%/$MACHINE_ID/$KERNEL_VERSION}
LOADER_ENTRY="$BOOT_ROOT/EFI/Linux/0-rescue-$MACHINE_ID.efi"
BOOT_DIR_ABS="$BOOT_ROOT/EFI/Linux"
ret=0

case "$COMMAND" in
    add)
        [[ -f "$LOADER_ENTRY" ]] && exit 0

        # source our config dir
        for f in $(dropindirs_sort ".conf" "/etc/dracut.conf.d" "/usr/lib/dracut/dracut.conf.d"); do
            if [[ -e $f ]]; then
                # shellcheck disable=SC1090
                . "$f"
            fi
        done

        # shellcheck disable=SC2154
        [[ $dracut_rescue_image != "yes" ]] && exit 0

        [[ -d "$BOOT_DIR_ABS" ]] || mkdir -p "$BOOT_DIR_ABS"

        dracut --kernel-cmdline "${BOOT_OPTIONS[*]}" -f --no-hostonly -a "rescue" --uefi "$LOADER_ENTRY" "$KERNEL_VERSION"

        ((ret+=$?))
        ;;

    remove)
        exit 0
        ;;

    *)
        usage
        ret=1;;
esac

exit $ret
```
  ],
)

= Reinstall kernel-core
Reinstall your kernel image to make changes apply:

#figure(
  caption: [Reinstall the kernel to generate unified images],
  [
```bash
sudo dnf install binutils # needed by dracut to build kernel image
sudo dnf reinstall $(rpm -qa|grep kernel-core)
```
  ],
)

You should be able to see several `.efi` kernel image at `/efi/EFI/Linux`, if it's not there, rollback with your backup. Now you can reboot to see if everything works.

= Update systemd-boot on demand
Install plugins to run scripts for dnf:

#figure(
  caption: [Install the DNF post-transaction-actions plugin],
  [
```bash
python3-dnf-plugin-post-transaction-actions
```
  ],
)

#figure(
  caption: [`/etc/dnf/plugins/post-transaction-actions.d/systemd-udev.action`],
  [
```
systemd-udev:in:bootctl update
```
  ],
)

This will enable systemd-boot in efi to update along with systemd package.
