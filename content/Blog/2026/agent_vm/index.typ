#import "../../../../config.typ": template, tufted
#let post = (
  title: [MicroVM for Agents],
  tag: ("Linux", "MicroVM"),
  date: datetime(year: 2026, month: 9, day: 22),
  lang: "en",
  comments: true,
)
#show: template.with(..post)

#title()

We are always happy about letting AI agents take over our computer and do all kinds of shit for us. 
But just consider it from another point of view: this is essentially allowing a remote _entity_ to 
execute arbitrary commands on your system, which doesn't sound as peaceful as it seems.
For this reason, I have always been looking for any possible way to isolate the agent from my system. 
There are different solutions available on the market, varying from scripting with `bwrap` to various 
container- or disk-image-based solutions.

While I was looking for an existing microVM solution, I found that currently popular microVM solutions tend
to be either too isolated#footnote[
  This means that I can't re-use most of my host development environment; a re-installation is needed most of the time:
  - https://github.com/libkrun/krunvm
  - https://github.com/smol-machines/smolvm
] or under-isolated#footnote[
  This means that I have to use a complicated `bwrap` command to confine the VM:
  - https://github.com/AsahiLinux/muvm
], so they don't feel like a perfect match for me.

But let him who tied the bell on the tiger take it off: we can just make a wish to wonderful AIs, and the agents#footnote[
  ChatGPT 6 Astra, in Ultra mode, which is great. I just stated the design, and it finished all the code and tests. 
]
return us the _mostly_ perfect solution.

= `Agent-VM`
The result of vibe coding is #link("https://github.com/karuboniru/agent-vm/")[*Agent-VM*]. I tried to combine my 
ideas when constructing a bwrap sandbox and the previously mentioned microVM solutions, and the result is that 
this tool, built with `libkrun`, supports:
- Construct a sandbox `/` using the host `/usr` with a read-only bind mount;
- The minimal `/etc` is constructed on the fly;
- The current working directory is bind mounted to the sandbox;
- Allows various options to control the sandbox, like enabling/disabling network, passing certain host sockets 
  to the sandbox, etc.
  
== The configuration
The configuration should be quite self-explanatory. Here is a sample configuration file for the microVM:
#figure( caption: [
  Sample configuration file for the microVM, which should be put at `~/.config/agent-vm/config.toml`. One can have multiple different
  configuration files and specify the configuration file to use when starting the microVM using `--profile <profile_name>`. 
  `config.toml` is the default one being looked for when no `--profile` is specified.
],
[```toml
version = 1

[vm]
cpus = 2
memory_mib = 2048
# Per guest-native tmpfs capacity limit, including [[tmpfs]] below.
# Actual use consumes VM RAM; this is not an aggregate limit or reservation.
tmp_mib = 256

[filesystem]
cwd = "rw"
home = "ephemeral"
# Source masks apply at every shared alias. Missing paths beneath a shared
# directory are rejected, because creating placeholders would modify the host.
mask_sources = ["~/.ssh", "~/.gnupg"]
# mask_targets = ["/data/private"]

# Relative source paths are resolved against this file's directory.
# [[mounts]]
# source = "~/datasets"
# target = "/data"
# mode = "ro"

# Empty guest-native storage; writes disappear when the VM exits.
# CLI --tmpfs entries append to this list. Each uses vm.tmp_mib above.
# UID/GID default to the invoking user's numeric IDs; mode defaults to 0700.
# Explicit guest IDs do not change host ownership or the workload identity.
# Root ownership with mode 0700 denies access to a non-root workload.
[[tmpfs]]
target = "/cache"
# uid = 1000
# gid = 1000
# mode = 0o750

# Optional temporary GnuPG home with an existing public keyring exposed read-only.
# Enable both entries together; do not also mask this source or guest subtree.
# UID/GID default to the invoking user's IDs; the explicit values are optional.
# [[tmpfs]]
# target = "~/.gnupg"
# uid = 1000
# gid = 1000
#
# [[mounts]]
# source = "~/.gnupg/pubring.kbx"
# target = "~/.gnupg/pubring.kbx"
# mode = "ro"

# Forward an existing filesystem Unix stream socket. Relative sources use this
# file's directory; ~ expands to the invoking user's home, as for mounts.
# CLI --socket entries append to these. Targets must be absolute and writable.
# Missing parent directories are created as guest root, then assigned to the
# guest user before the relay drops privileges and creates a mode-0600 socket.
# Existing parent ownership is unchanged; existing destinations are rejected.
# [[sockets]]
# source = "~/service.sock"
# target = "/run/service/client.sock"

[environment]
# TERM, LANG and LC_ALL are inherited by default when present.
# Add only variables that the workload needs. Missing explicit names are errors.
inherit = []

[environment.set]
EDITOR = "vi"

[network]
mode = "none" # or "passt" to enable host network passthrough
# Publishing requires mode = "passt". Default bind address is loopback.
publish = []
# publish = ["127.0.0.1:8080:8080/tcp"]

[ssh_agent]
# Alias: host SSH_AUTH_SOCK -> /run/user/<uid>/ssh-agent.socket, with guest env.
# --no-ssh-agent disables this alias only, not explicit [[sockets]] entries.
# When disabled, environment.set may specify SSH_AUTH_SOCK for a custom forward.
enabled = false

# Optional filtered D-Bus forwarding; each bus is independently disabled by default.
# Arguments are literal xdg-dbus-proxy per-bus options; --filter is always added.
# No shell expansion. Empty args exposes only the proxy's baseline bus operations.
[dbus.user]
enabled = false
args = ["--talk=org.freedesktop.Notifications"]
# address = "unix:path=/run/user/1000/bus"
# Otherwise uses host DBUS_SESSION_BUS_ADDRESS, then $XDG_RUNTIME_DIR/bus.

[dbus.system]
enabled = false
args = ["--talk=org.freedesktop.UPower"]
# address = "unix:path=/run/dbus/system_bus_socket"
# Otherwise uses host DBUS_SYSTEM_BUS_ADDRESS, then the standard system socket.
```
]
)

And extra configuration can be applied via cmdline like `agent-vm --mask .git -- some_coding_agent` to hide the `.git` directory from being uploaded by accident. 

== Installation
Currently packaging is only available for Fedora #link("https://copr.fedorainfracloud.org/coprs/yanqiyu/agent-vm/")[on Copr], but it should be easy to build from source on other distributions. The build process is quite simple. Just run:
#figure(
  caption: [
    Simple guide for general installation
  ],[
    ```bash
    git clone https://github.com/karuboniru/agent-vm.git
    cd agent-vm
    cmake -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo 
    cmake --install build --prefix ~/.local
    ```
  ]
)
