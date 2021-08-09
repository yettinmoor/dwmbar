# dwmbar

A very minimal, ~200 SLOC program to set dwm's statusbar through xsetroot. Modular design similar to [i3blocks](https://github.com/vivien/i3blocks) and [dwmblocks](https://github.com/torrinfail/dwmblocks). Run `dwmbar` to update all blocks and `dwmbar <cmd>` (e.g. `dwmbar time`) to update a single block. You can also run `dwmbar <cmd> "<param>"` to manually set a block's text. For example, when I'm updating my RSS feed, I simply set the RSS block to 🔁 temporarily, instead of having a laborious check in the command itself.

Customize by changing `$XDG_CONFIG_HOME/dwmbar.cfg`. An example config:

```cfg
[!global]
delim = " | "

[mpc]
cmd = "mpc current -f '%artist% - %title%'"
prefix = "♫"

[updates]
cmd = "pacman -Qu | wc -l | grep -v '^0'"
prefix = ""

[time]
cmd = "date +%R"
```

`cmd` and `prefix` are valid keys.

`dwmbar` stores state in `/tmp/dwmbar`. It does not run as a daemon, only when updating a block.
