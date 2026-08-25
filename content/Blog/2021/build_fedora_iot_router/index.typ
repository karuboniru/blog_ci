#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/build_fedora_iot_router.md
// 原文时间: 2021-12-01 11:53:53
#let post = (
  title: [Building a router based on Fedora IoT],
  date: datetime(year: 2021, month: 12, day: 1),
  comments: true,
)
#show: template.with(..post)

#title()

I had enough of my old WiFi router that hangs randomly, and hijacks my traffic when it thinks the network is down (diagnostics page). So I decided to build one router on myself. Compared to #link("https://fedoramagazine.org/use-fedora-server-create-router-gateway/")[Fedora Magazine article], I decided to do something new: use #link("https://getfedora.org/en/iot/")[Fedora IoT] instead of Fedora Server.

This guide is based on latest fedora iot edition and my setup is a multi ethernet small computer. Installing Fedora IoT is nothing special than a normal Fedora installation. So I will not explain the installation process here. I will only explain the router configuration.

= Why Fedora IoT?
As described in #link("https://getfedora.org/en/iot/")[this page], Fedora IoT is a new edition of Fedora based on OsTree and designed to work in IoT devices, providing an immutable operating system with atomic updates. And the shipped image is tested as a whole. It should be safe to do regular updates, following upstream and getting various security fixes quickly.

= Setup lan bridge and assgin Firewall-zone
In my device I have `enp1s0` as wan port and `enp[2-4]s0` as lan ports. Those lan ports should be bridged to `br0` bridge.

```
nmcli connection modify enp1s0 connection.zone external
nmcli connection add ifname br0 type bridge con-name br0 bridge.stp no ipv4.addresses 192.168.100.1/24 ipv4.method manual ipv6.addresses fdcc::1/64 ipv6.method manual connection.zone internal ipv4.may-fail no ipv6.may-fail no
nmcli connection add type bridge-slave ifname enp2s0 master br0
nmcli connection add type bridge-slave ifname enp3s0 master br0
... (and for all other lan ports)
```

Theoretically, If your ISP provides ipv6-PD, you can just set `ipv6.method` to `shared` and remove the `ipv6.addresses` part, NetworkManager will do prefix delegation on lan network. If you are also setting `ipv4.method shared`, you can even ignore the step setting up dhcp and route advertisement, NetworkManager will do it for you in this case.

= Setup firewall
== Enable masquerading on wan
```
firewall-cmd --zone=external --add-masquerade --permanent
firewall-cmd --zone=external --add-rich-rule='rule family="ipv6" masquerade' --permanent
```

This allows masquerading for both ipv4 and ipv6.

== Allow some services on lan
```
firewall-cmd --zone=internal --add-service=dhcp --permanent
firewall-cmd --zone=internal --add-service=dns --permanent
```

If you need more service just list them here.

== Allow traffic to be forwarded from lan to wan
```
firewall-cmd --new-policy=router --permanent
firewall-cmd --policy=router --add-ingress-zone internal --permanent
firewall-cmd --policy=router --add-egress-zone external --permanent
firewall-cmd --policy=router --set-target ACCEPT --permanent
firewall-cmd --policy=router --add-rich-rule='rule tcp-mss-clamp value=pmtu' --permanent
```

== Disable SSH from wan (optional)
```
firewall-cmd --zone=external --remove-service=ssh --permanent
```

Finally `firewall-cmd --reload` to apply the changes.

= Setup dnsmasq
Edit `/etc/dnsmasq.d/router.conf` and add the following lines:

```
port=0
bogus-priv
no-resolv
local=/niconi.org/
interface=br0
expand-hosts
domain=niconi.org
dhcp-range=192.168.233.5,192.168.233.254,24h
dhcp-option=option:router,192.168.100.1
dhcp-authoritative
dhcp-leasefile=/var/lib/dnsmasq/dnsmasq.leases
dhcp-option=option:dns-server,192.168.100.1
dhcp-option=option6:dns-server,[fccd::1]
enable-ra
dhcp-range=fccd::, ra-stateless
```

I disabled the dns server on lan ports since I will be using AdGuard Home instead. If you want to enable, just remove `port=0` and add `server ...` pointing to upstream dns server to the file. Also, you can specify `dns-dhcp-option=option:dns-server, ...` to your upstream servers.

Then edit `/etc/systemd/system/dnsmasq.service.d/override.conf` and add the following lines:

```
[Unit]
After=network-online.target
```

to avoid early starting of dnsmasq, which may cause failure due to br0 is not ready.

Then, just run `systemctl daemon-reload` and `systemctl enable --now dnsmasq` to apply the changes and start dnsmasq.

= AdGuard Home
AdGuard Home is a free and open source DNS filtering software. It is designed to block ads, malware, and other unwanted content. It is available via docker hub, we could use podman to run it. Create file `/etc/systemd/system/container-adguardhome.service` and add the following lines:

```
[Unit]
Description=Podman container-adguardhome.service
Documentation=man:podman-generate-systemd(1)
Wants=network-online.target
After=network-online.target
RequiresMountsFor=%t/containers

[Service]
Environment=PODMAN_SYSTEMD_UNIT=%n
Restart=on-failure
TimeoutStopSec=70
ExecStartPre=/bin/rm -f %t/%n.ctr-id
ExecStart=/usr/bin/podman run --cidfile=%t/%n.ctr-id --cgroups=no-conmon --rm --sdnotify=conmon -d --replace --name adguardhome -v /var/lib/adg/work:/opt/adguardhome/work:z -v /var/lib/adg/confdir:/opt/adguardhome/conf:z -p 192.168.100.1:53:53/tcp -p 192.168.100.1:53:53/udp -p [fccd::1]:53:53/tcp -p [fccd::1]:53:53/udp -p 192.168.100.1:3000:3000/tcp -p [fccd::1]:3000:3000/tcp --label io.containers.autoupdate=registry docker.io/adguard/adguardhome:latest
ExecStop=/usr/bin/podman stop --ignore --cidfile=%t/%n.ctr-id
ExecStopPost=/usr/bin/podman rm -f --ignore --cidfile=%t/%n.ctr-id
Type=notify
NotifyAccess=all

[Install]
WantedBy=multi-user.target 
```

And do `mkdir -p /var/lib/adg/confdir /var/lib/adg/work` `systemctl daemon-reload` and `systemctl enable --now container-adguardhome.service` to enable and start AdGuard Home. And you should go to `http://192.168.100.1:3000` to configure your AdGuard Home.

#html.hr()

At this point, you can find devices connected to lan ports can access network now, the router is mostly done, but we can do more bonus work to enable auto updating.

= Auto-updating system image
`rpm-ostree` don't ship with a automatic update service that reboots for you, we can make a service on our own:

```
# /etc/systemd/system/os-update.service
[Unit]
Description=rpm-ostree Automatic Update with reboot
Documentation=man:rpm-ostree(1) man:rpm-ostreed.conf(5)
ConditionPathExists=/run/ostree-booted

[Service]
Type=simple
ExecStart=/usr/bin/rpm-ostree upgrade --reboot
StandardOutput=null

# /etc/systemd/system/os-update.timer
[Unit]
Description=rpm-ostree Automatic Update Trigger with reboot
ConditionPathExists=/run/ostree-booted

[Timer]
OnCalendar=*-*-* 04:00:00

[Install]
WantedBy=timers.target
```

And then, we can enable and start the service: `systemctl daemon-reload && systemctl enable --now os-update.timer` This will check updates on `4:00` local time daily and reboot if there is any updates.

= Auto update containers
Execute `systemctl enable --now podman-auto-update.timer` to tell podman to check update for AdGuard Home periodically and apply updates automatically.

#html.hr()

= Allow podman containers to access ipv6 via nat
If you want to set ipv6 dns in AdGuard Home as upstream, it can fail since podman don't provide ipv6 for container by default, but you can enable by changing `/etc/cni/net.d/87-podman.conflist` to

```
{
  "cniVersion": "0.4.0",
  "name": "podman",
  "plugins": [
    {
      "type": "bridge",
      "bridge": "cni-podman0",
      "isGateway": true,
      "ipMasq": true,
      "hairpinMode": true,
      "ipam": {
        "type": "host-local",
        "routes": [{ "dst": "0.0.0.0/0", "gw": "10.88.0.1" }, { "dst": "::/0", "gw": "fdc2::1" } ],
        "ranges": [
          [
            {
              "subnet": "10.88.0.0/16",
              "gateway": "10.88.0.1"
            }
          ],
          [
            {
              "subnet": "fdc2::/64",
              "gateway": "fdc2::1"
            }
          ]  
        ]
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    },
    {
      "type": "firewall"
    },
    {
      "type": "tuning"
    }
  ]
}
```

And restart container, ipv6 will be available then.
