#import "../../../index.typ": template, tufted
// 原文件: source/_posts/hands-on-coreos.md
// 原文时间: 2021-05-06 23:32:57
#show: template.with(
  title: "上手 Fedora CoreOS，以搭建代理为例",
  date: datetime(year: 2021, month: 5, day: 6),
  comments: true,
)

= 上手 Fedora CoreOS，以搭建代理为例

前几天，Vultr 的洛杉矶机房维护，我的主力代理自然就断掉了，于是临时启动了一个机器用来救急。虽然有一个脚本用来处理配置代理需要的步骤，但是因为脚本忘了写防火墙规则导致我迷惑了足足有半分钟（然后想起来我上次用这个脚本的时候也是手动 ssh 上去添加防火墙规则的）。

退一步越想越气，于是突然想到妮可艹提到过 #link("https://getfedora.org/en/coreos?stream=stable")[Fedora CoreOS] 很适合这类工作，顺便我正好学习下这东西怎么用。

== 在 Vultr 上通过 CoreOS 部署 V2ray
说干就干，先看看#link("https://docs.fedoraproject.org/en-US/fedora-coreos/")[文档]，琢磨琢磨，然后糊一个 Fedora CoreOS Config 文件。

```yaml
variant: fcos
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBFlngteAj8k7Fv0Ht6dFtQvA+Svxn/qnTuDfUzEvaU33QEyN9jDaJyMdct4elU9ec9aQheskwv5ULSvv7lzgs4ZhgtgGNRfH0mC8cI49DGdSxucaAuPiHmKNTfQa88iZxg== CARD AUTH pubkey pkcs11:id=%04;object=CARD%20AUTH%20pubkey;token=Karuboniru;manufacturer=piv_II?module-path=/usr/lib64/pkcs11/opensc-pkcs11.so"
      groups: [ sudo, wheel ]
storage:
  files:
    - path: /var/lib/v2ray/config.json
      overwrite: true
      contents: 
        inline: |
          {
            "inbounds": [
              {
                "port": <YOUR-PORT-HERE>,
                "protocol": "vmess",
                "settings": {
                  "clients": [
                    {
                      "id": "<YOUR-UUID-HERE>",
                      "alterId": 64
                    }   
                  ]
                }
              }
            ],
            "outbounds": [
              {
                "protocol": "freedom",
                "settings": {}
              }
            ]
          }
      mode: 0644
systemd:
  units:
    - name: v2ray.service
      enabled: true
      contents: |
        [Unit]
        Description=Run v2ray
        After=network-online.target
        Wants=network-online.target

        [Service]
        ExecStartPre=-/bin/podman kill v2ray
        ExecStartPre=-/bin/podman rm v2ray
        ExecStartPre=-/bin/podman pull docker.io/v2fly/v2fly-core:latest
        ExecStart=/bin/podman run --name v2ray --volume /var/lib/v2ray:/etc/v2ray:z --net=host docker.io/v2fly/v2fly-core:latest
        ExecStop=/bin/podman stop v2ray

        [Install]
        WantedBy=multi-user.target
```

我们来拆开看看这个文件

```yaml
variant: fcos
version: 1.0.0
```

上面意思是我要构建一个 `fcos` 系统，并且配置文件格式是 `1.0.0`。

`"ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBFlngteAj8k7Fv0Ht6dFtQvA+Svxn/qnTuDfUzEvaU33QEyN9jDaJyMdct4elU9ec9aQheskwv5ULSvv7lzgs4ZhgtgGNRfH0mC8cI49DGdSxucaAuPiHmKNTfQa88iZxg== CARD AUTH pubkey pkcs11:id=%04;object=CARD%20AUTH%20pubkey;token=Karuboniru;manufacturer=piv_II?module-path=/usr/lib64/pkcs11/opensc-pkcs11.so"` 是我的 ssh 公钥，之后需要维护可能用到。

```yaml
storage:
  files:
    - path: /var/lib/v2ray/config.json
      overwrite: true
      contents: 
        inline: |
          {
            "inbounds": [
              {
                "port": <YOUR-PORT-HERE>,
                "protocol": "vmess",
                "settings": {
                  "clients": [
                    {
                      "id": "<YOUR-UUID-HERE>",
                      "alterId": 64
                    }   
                  ]
                }
              }
            ],
            "outbounds": [
              {
                "protocol": "freedom",
                "settings": {}
              }
            ]
          }
      mode: 0644
```

这是放一个配置文件到 `/var/lib/v2ray/config.json`，至于 `/etc` 尽可能留给包管理。

最后是添加一个自动启动的 systemd unit

```yaml
systemd:
  units:
    - name: v2ray.service
      enabled: true
      contents: |
        [Unit]
        Description=Run v2ray
        After=network-online.target
        Wants=network-online.target

        [Service]
        ExecStartPre=-/bin/podman kill v2ray
        ExecStartPre=-/bin/podman rm v2ray
        ExecStartPre=-/bin/podman pull docker.io/v2fly/v2fly-core:latest
        ExecStart=/bin/podman run --name v2ray --volume /var/lib/v2ray:/etc/v2ray:z --net=host docker.io/v2fly/v2fly-core:latest
        ExecStop=/bin/podman stop v2ray

        [Install]
        WantedBy=multi-user.target
```

这个 unit 会通过 #link("https://podman.io/")[Podman] 拉取 #link("https://hub.docker.com/r/v2fly/v2fly-core")[V2ray 的 Docker 镜像] 并创建一个容器，将 `/var/lib/v2ray` 挂载到容器内的 `/etc/v2ray`，并指定 `net=host`，也就是容器不隔离网络。

FCC 文件是一个易读的 Yaml 文件，之后要用 #link("https://github.com/coreos/butane")[Butane] 工具进行转换。

首先要安装 Butane

```bash
sudo dnf install butane
```

然后用你的 fcc 文件喂给它…假定它的名字是 `fcos.fcc`

```bash
butane fcos.fcc
```

于是会输出一段混沌的 json 到终端，这就是 ign 文件，复制这段输出。转到 #link("https://www.vultr.com/?ref=8404229-6G")[Vultr (With Referral)]，创建服务器，选择区域并在 `Server Type` 处选择 CoreOS： #html.img(src: "https://cdn.yanqiyu.info/20210506233322.png") 把上面的 `butane fcos.fcc` 的输出粘贴到框框里面。然后按需修改配置，选择 `Deploy Now` 就完成了部署。记下 ip 配置好客户端就能用了。

#html.hr()

OK，接下来就是肮脏的 workarounds 了

== Vultr 的 Fedora CoreOS 太老了
我虽然在工单系统反馈了这个问题，但是估计一时半会不会有修复，你可能需要手动上去 `rpm-ostree update` 更新一下------因为 CoreOS 自带的 `zincati` 在那个版本上面是默认禁用自动更新的。

你也可以加上

```yaml
  links:
    - path: /etc/zincati/config.d/95-disable-on-dev.toml
      overwrite: true
      target: /dev/null
      hard: false
```

到 `storage` 部分，这会启用自动更新，理论上它会允许系统随后自动更新到最新版本的 CoreOS。

== 开 BBR
这个简单，在 `files` 下面加上

```yaml
    - path: /etc/modules-load.d/80-bbr.conf
      contents:
        inline: |
          tcp_bbr
    - path: /etc/sysctl.d/80-bbr.conf
      contents:
        inline: |
          net.ipv4.tcp_congestion_control = bbr  
```

就有了 BBR。

== 用 `sshd.socket` 而不是 `sshd.service`
可能能省点内存，因为 ssh 用的并不是很频繁。但是可能因为 Vultr 的 CoreOS 版本太老的原因，在 `systemd` 段加上：

```yaml
    - name: sshd.socket
      enabled: true
    - name: sshd.service
      enabled: false
```

不好使，需要做的是在 `systemd` 段加上

```yaml
    - name: sshd.socket
      enabled: true
```

并在 `links` 里面加上

```yaml
    - path: /etc/systemd/system/sshd.service
      overwrite: true
      target: /dev/null
      hard: false
```

来 mask 掉 `sshd.service`。

== 切换到 CGroup V2
只是个人喜好罢了…在 `systemd` 段下面加

```yaml
    - name: cgroups-v2-karg.service
      enabled: true
      contents: |
        [Unit]
        Description=Switch To cgroups v2
        # We run after `systemd-machine-id-commit.service` to ensure that
        # `ConditionFirstBoot=true` services won't rerun on the next boot.
        After=systemd-machine-id-commit.service
        ConditionKernelCommandLine=systemd.unified_cgroup_hierarchy
        ConditionPathExists=!/var/lib/cgroups-v2-karg.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/bin/rpm-ostree kargs --delete=systemd.unified_cgroup_hierarchy
        ExecStart=/bin/touch /var/lib/cgroups-v2-karg.stamp
        ExecStart=/bin/systemctl --no-block reboot

        [Install]
        WantedBy=multi-user.target
```

== 更改 ign 文件重新部署
令人震惊的是，Vultr 不提供这个功能，他们的技术支持建议是 reserve 现在的 ip，应用到新部署的机器上…听着就很傻。于是只能曲线救国：

=== 把真正的 ign 文件放到 GitHub Gist
在 #link("https://gist.github.com/")[Gist] 放下前面 butane 输出的 ign 文件（最好是 Secret Gist）。然后导出它的 raw 链接，一般格式是：`https://gist.githubusercontent.com/<username>/<id>/raw/<commit>/<name>.ign`，对应的写一个 fcc 文件，内容是

```yaml
variant: fcos
version: 1.0.0
ignition:
  config:
    replace:
      source: https://gist.githubusercontent.com/<username>/<id>/raw/<name>.ign
```

里面链接要去掉 `<commit>` 这一级，保证始终拉取最新版本。要是有更好的存放 ign 文件的地方欢迎指出。

于是用这个 fcc 文件，配合 butane 输出 ign 文件部署。之后想要更改 ign 重新部署就更改对应 Gist，然后再 Vultr 面板选择 Reinstall 即可。

== 我的 FirewallD 呢
答案是 FirewallD 没了，整个 CoreOS 就没 Python，自然就没了 FirewallD。虽然可以靠 `/etc/sysconfig/nftables.conf` + `nftables.service` 解决问题，但是考虑到 CoreOS 上本来就没运行需要拦住的服务，于是没有防火墙就没有吧XD。

#html.hr()

== 最后 FCC 文件长啥样
```yaml
variant: fcos
version: 1.0.0
passwd:
  users:
    - name: core
      ssh_authorized_keys:
        - "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBFlngteAj8k7Fv0Ht6dFtQvA+Svxn/qnTuDfUzEvaU33QEyN9jDaJyMdct4elU9ec9aQheskwv5ULSvv7lzgs4ZhgtgGNRfH0mC8cI49DGdSxucaAuPiHmKNTfQa88iZxg== CARD AUTH pubkey pkcs11:id=%04;object=CARD%20AUTH%20pubkey;token=Karuboniru;manufacturer=piv_II?module-path=/usr/lib64/pkcs11/opensc-pkcs11.so"
      groups: [ sudo, wheel ]
storage:
  files:
    - path: /var/lib/v2ray/config.json
      overwrite: true
      contents: 
        inline: |
          {
            "inbounds": [
              {
                "port": <YOUR-PORT-HERE>,
                "protocol": "vmess",
                "settings": {
                  "clients": [
                    {
                      "id": "<YOUR-UUID-HERE>",
                      "alterId": 64
                    }   
                  ]
                }
              }
            ],
            "outbounds": [
              {
                "protocol": "freedom",
                "settings": {}
              }
            ]
          }
      mode: 0644
    - path: /etc/modules-load.d/80-bbr.conf
      contents:
        inline: |
          tcp_bbr
    - path: /etc/sysctl.d/80-bbr.conf
      contents:
        inline: |
          net.ipv4.tcp_congestion_control = bbr  
  links:
    - path: /etc/zincati/config.d/95-disable-on-dev.toml
      overwrite: true
      target: /dev/null
      hard: false
    - path: /etc/systemd/system/sshd.service
      overwrite: true
      target: /dev/null
      hard: false
systemd:
  units:
    - name: v2ray.service
      enabled: true
      contents: |
        [Unit]
        Description=Run v2ray
        After=network-online.target
        Wants=network-online.target

        [Service]
        ExecStartPre=-/bin/podman kill v2ray
        ExecStartPre=-/bin/podman rm v2ray
        ExecStartPre=-/bin/podman pull docker.io/v2fly/v2fly-core:latest
        ExecStart=/bin/podman run --name v2ray --volume /var/lib/v2ray:/etc/v2ray:z --net=host docker.io/v2fly/v2fly-core:latest
        ExecStop=/bin/podman stop v2ray

        [Install]
        WantedBy=multi-user.target
    - name: cgroups-v2-karg.service
      enabled: true
      contents: |
        [Unit]
        Description=Switch To cgroups v2
        # We run after `systemd-machine-id-commit.service` to ensure that
        # `ConditionFirstBoot=true` services won't rerun on the next boot.
        After=systemd-machine-id-commit.service
        ConditionKernelCommandLine=systemd.unified_cgroup_hierarchy
        ConditionPathExists=!/var/lib/cgroups-v2-karg.stamp

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        ExecStart=/bin/rpm-ostree kargs --delete=systemd.unified_cgroup_hierarchy
        ExecStart=/bin/touch /var/lib/cgroups-v2-karg.stamp
        ExecStart=/bin/systemctl --no-block reboot

        [Install]
        WantedBy=multi-user.target
    - name: sshd.socket
      enabled: true
```
