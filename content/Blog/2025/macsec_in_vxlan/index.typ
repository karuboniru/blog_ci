#import "../../../../config.typ": template, tufted
// 原文件: source/_posts/macsec_in_vxlan.md
// 原文时间: 2025-04-20 15:53:57
// tags: 瞎折腾
#let post = (
  title: [一种很怪的隧道 (MACsec in VXLAN)],
  date: datetime(year: 2025, month: 4, day: 20),
  tag: ("瞎折腾", "Linux"),
  comments: true,
)
#show: template.with(..post)

#title()

= 出发点
其实一开始是想玩 IEKv2 + IPsec 的，但刚开始配置就被复杂度劝退了。于是就开始研究现有的隧道方案，看到#link("https://alecthw.github.io/p/fuck-gfw-vxlan/")[这篇文章]，才知道数据中心里常用的 VXLAN 隧道其实也能跑在公网上，而且还能翻墙。

不过那篇文章提到一个问题：VXLAN 本身没有加密，墙还是能检查隧道里的内容。然后我就想到，既然是二层连接，不如加个 #link("https://man7.org/linux/man-pages/man8/ip-macsec.8.html")[MACsec]，既能加密又能认证？这种比较小众的协议，说不定就是“灯下黑”，能混过去。

= 配隧道
先在两端配置 VXLAN 隧道：

```bash
firewall-cmd --permanent --add-port=8472/udp # 放行 vxlan 的端口
nmcli connection add type vxlan \
  con-name vxlan ifname vxlan \ # interface 的名字，可以随便取名
  id 0 remote $endpoint_ip \ vlan id 随便给一个就行，但是两端必须一样，endpoint_ip是对端的公网ip
  ipv4.method disable ipv6.method disable \ # vxlan上要跑的是二层协议，所以不需要ipv4/ipv6
  802-3-ethernet.mtu 1430 # 1430是为了留出 vxlan 的开销，下层链接是 ipv6 于是减去了 70 的 mtu
```

两端机器都需要运行这个配置，确保 endpoint\_ip 指向对端的公网地址。这样 VXLAN 隧道就通了，不过这个链路没有加密和认证，直接跑业务还是不太安全。所以我们再加上一层 MACsec。

= 配 macsec
先在任意一端生成 16 字节的 CAK 和 32 字节的 CKN：

```bash
# 生成 16 字节 CAK（用于加密）
dd if=/dev/urandom count=16 bs=1 2> /dev/null | hexdump -e '1/2 "%04x"'

# 生成 32 字节 CKN（用于身份标识）
dd if=/dev/urandom count=32 bs=1 2> /dev/null | hexdump -e '1/2 "%04x"'
```

然后配置 macsec 隧道，在服务器端：

```bash
nmcli connection add type macsec con-name macsec0 ifname macsec0 \
  connection.autoconnect yes macsec.parent vxlan \
  macsec.mode psk macsec.mka-cak $CAK macsec.mka-ckn $CKN \
  ipv4.method shared ipv6.method shared \
  connection.zone trusted \
  ipv4.address 10.12.0.1/16 ipv6.address fcc1::1/64 
```

在客户端：

```bash
nmcli connection add type macsec con-name macsec0 ifname macsec0 \
  connection.autoconnect yes macsec.parent vxlan \
  macsec.mode psk macsec.mka-cak $CAK macsec.mka-ckn $CKN \
  ipv4.method auto ipv6.method auto 
```

过几秒钟，客户端应该就能自动从服务端获取 IPv4/IPv6 地址了。逻辑上，这就像你在两台机器之间拉了一根网线。要让客户端能上网，还需要配置 NAT 和防火墙规则，这部分就不展开说了，和配置软路由差不多。

= 保活
MACsec 是点对点的，一端断开后，另一端的 NetworkManager 会默认禁用接口，导致重连时需要手动 up。可以通过下面的方式避免这件事：

新建配置文件：

```
# /etc/NetworkManager/conf.d/alwayson.conf
[main]
ignore-carrier=macsec0
```

这样就能告诉 NetworkManager：别动我这个接口！

= 结尾
这个方案确实有不少限制。一方面双方都得有公网 IP（IPv6 也可以），另一方面它是点对点的，不像传统 VPN 那样灵活。不过好处也很明显：全内核支持，性能极好，配置比 IPsec 简单好几个量级。

而且由于是二层连接，客户端这边可以直接把 MACsec 接口桥接到一个网桥上，让其他设备或虚拟机也能接入这个加密网络，玩法还是挺多的。
