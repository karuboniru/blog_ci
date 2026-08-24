#import "../../../../index.typ": template, tufted
// 原文件: source/_posts/build_your_own_ostree_system.md
// 原文时间: 2025-02-19 20:12:00
// tags: Fedora, rpm-ostree
#show: template.with(
  title: "Build your own fedora OSTree Remix",
  date: datetime(year: 2025, month: 2, day: 19),
  extra-info: "标签：Fedora · rpm-ostree",
  comments: true,
)

= Build your own fedora OSTree Remix

#quote(block: true)[
I am not responsible for bricked computers, system instabilities, dead cats, thermonuclear war or you getting fired because you lost important work.

Please make a backup of your device or of the data, and make a boot drive in case of necessity. Do some research if you have any concerns about steps documented in this guide.

YOU are choosing to make these modifications, and if you point the finger at me for messing up your device, I will laugh at you.
]

After a long break, I decided to continue with my blog (PhD life is tough).

== What Is This?
This guide shows you how to build your own Fedora OSTree Remix from scratch using `rpm-ostree compose`. I created it because I wanted my frequently used packages in the base image instead of relying on `toolbox`, which can be cumbersome to update alongside the full Fedora release. Also, by adding some important configuration to the base image would allow easier tracking of changes and updates.

== Writing your own rpm-ostree Tree configuration
The customization process starts with fedora's official `workstation-ostree-config` repo:

```bash
git clone https://pagure.io/workstation-ostree-config.git
cd workstation-ostree-config
git checkout f41 # or any fedora version
```

Assume you are a fan of `silverblue`, then you start with `cp silverblue.yaml myremix.yaml` and start editing `myremix.yaml` to your liking by adding something like (for example to add `fcitx5` and compilers):

```yaml
packages:
  - fcitx5
  - fcitx5-autostart
  - fcitx5-chinese-addons
  - fcitx5-configtool
  - fcitx5-gtk
  - cmake
  - gcc
  - gcc-c++
  - gcc-gfortran
  - llvm
```

More possible configuration can be found in the #link("https://coreos.github.io/rpm-ostree/treefile/")[official documentation].

== Building the OSTree with GitHub Actions
The action file that do the build looks like following, the `${{ vars.COMPOSEFILE }}` can be replaced with the file name you created in the previous step:

```yaml
name: Build Ostree Container Image
on:
  schedule:
    - cron: '00 0,8,16 * * *'
  push:
    branches: [ '*' ]


jobs:
  build:
    runs-on: ubuntu-latest
    container: 
      image: fedora:latest
      options: --privileged
    permissions:
      contents: read
      packages: write
      id-token: write

    steps:
      - name: Checkout repository
        uses: actions/checkout@v3
      
      - name: Build
        env:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}   
          image: ${{ github.repository }}
          tag: ${{ github.ref_name }}
          composefile: ${{ vars.COMPOSEFILE }} 
        run: |
          dnf -y --enablerepo=updates-testing install rpm-ostree skopeo selinux-policy-targeted
          skopeo login -u $username -p $password $registry
          mkdir -p repo cache
          ostree init --repo=repo --mode=archive
          rpm-ostree compose image --initialize-mode=if-not-exists \
            --format registry --layer-repo repo --cachedir=cache --copy-retry-times=4 \
            $composefile \
            $registry/$image:$tag
```

Commit all those changes, and publish everything to a GitHub repository. The action will run every 8 hours and build the image that looks like #link("https://github.com/karuboniru/karuboniru-workstation/pkgs/container/karuboniru-workstation/358447376?tag=f41")[this].

Given the image is built, and available through `ghcr.io/karuboniru/karuboniru-workstation:f41`. You can now pull the image and deploy it on your system:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/karuboniru/karuboniru-workstation:f41
reboot
```

and you are now using own Fedora OSTree Remix.

== Some useful customizations
=== howdy
The following file is `howdy.repo` that refers to the copr:

```ini
[howdy]
name=Copr repo for howdy-beta owned by principis
baseurl=https://download.copr.fedorainfracloud.org/results/principis/howdy-beta/fedora-41-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/principis/howdy-beta/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
```

and a `YAML` tree that handles the installation and SELinux policy:

```yaml
packages:
  - howdy 
  - howdy-gtk

repos:
  - howdy
  - fedora-41
  - fedora-41-updates

postprocess:
  - |
    #!/bin/bash
    set -xeuo pipefail
    cat <<EOF > /tmp/howdy.te 
    module howdy 1.0;

    require {
    type xdm_t;
    type local_login_t;
    type v4l_device_t;
    class chr_file { map write };
    }

    #============= xdm_t ==============
    allow xdm_t v4l_device_t:chr_file { write map };
    allow local_login_t v4l_device_t:chr_file { write map };
    EOF
    checkmodule -M -m -o /tmp/howdy.mod /tmp/howdy.te
    semodule_package -o /tmp/howdy.pp -m /tmp/howdy.mod
    semodule -i /tmp/howdy.pp
    rm /tmp/howdy.te /tmp/howdy.mod /tmp/howdy.pp
    # Enable howdy pam module for every case
    sed -i '1i auth        sufficient      pam_howdy.so' /etc/pam.d/{password-auth,system-auth}
    # workaround for canceling authentication in sudo/polkit
    # sed -i '1i auth sufficient pam_unix.so try_first_pass likeauth nullok' /etc/pam.d/system-auth
```

Finally add the `howdy.yaml` to the `myremix.yaml` file, under the `include` array:

```yaml
include:
  // ...
  - howdy.yaml
  // ...
```

=== IWD
```yaml
packages:
  - iwd

postprocess: 
  - |
    set -xeuo pipefail
    echo -e '[device]\nwifi.backend=iwd' > /usr/lib/NetworkManager/conf.d/23-wifi_backend.conf

exclude-packages:
  - wpa_supplicant
```

=== NVIDIA Drivers
Due to #link("https://github.com/coreos/rpm-ostree/issues/4983")[some reason], simply adding the related packages won't work during a compose, and everything related to `akmods` should be avoided here. For this reason, a "dummy" package is created to install the drivers packages without pulling in `akmods`:

```ini
# dummy.repo
[dummy]
name=Copr repo for Dummy package
baseurl=https://download.copr.fedorainfracloud.org/results/yanqiyu/Dummy/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/yanqiyu/Dummy/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1

# nvidia.repo
[nvidia]
name=RPM Fusion for Fedora $releasever - Nonfree - NVIDIA Driver
#baseurl=http://download1.rpmfusion.org/nonfree/fedora/nvidia-driver/$releasever/$basearch/
metalink=https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-nvidia-driver-$releasever&arch=$basearch
enabled=1
type=rpm-md
gpgcheck=0
repo_gpgcheck=0
skip_if_unavailable=True
```

And the `YAML` tree:

```yaml
repos:
  - fedora-41
  - fedora-41-updates
  - nvidia
  - dummy

packages:
  - nvidia-modprobe
  - xorg-x11-drv-nvidia-libs
  - nvidia-persistenced
  - xorg-x11-drv-nvidia
  - xorg-x11-drv-nvidia-cuda
  - xorg-x11-drv-nvidia-power
  - xorg-x11-drv-nvidia-kmodsrc
  - xorg-x11-drv-nvidia-cuda-libs
  - nvidia-settings
  - kernel-devel
  - dummy
exclude-packages:
  - akmods
  - akmod-nvidia

postprocess:
  - |
    set -xeuo pipefail
    kmodsrc=$(realpath /usr/share/nvidia-kmod-*/*.tar.xz)
    if [ -f $kmodsrc ]; then
      kmodule_path=$(realpath /lib/modules/*)
      kernel_uname=$(basename $kmodule_path)
      mkdir -p /tmp/kmod-build
      tar -xvf $kmodsrc -C /tmp/kmod-build
      cd /tmp/kmod-build/kernel-open
      make -O V=1 VERBOSE=1 CC='gcc -O2' LD=ld.bfd KERNEL_UNAME=${kernel_uname} modules -j$(nproc)
      make -O V=1 VERBOSE=1 CC='gcc -O2' LD=ld.bfd KERNEL_UNAME=${kernel_uname} modules_install
    fi
```

== When New Fedora Release
Just switch to new branches, and cherry-pick the changes from the previous branch, push the new branch and do another rebase.
