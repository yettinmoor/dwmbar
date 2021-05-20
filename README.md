# dwmbar

A very minimal ~100 SLOC program to set dwm's statusbar through xsetroot. Modular design similar to [i3blocks](https://github.com/vivien/i3blocks) and [dwmblocks](https://github.com/torrinfail/dwmblocks). Run `dwmbar` to update all blocks and `dwmbar <cmd>` (e.g. `dwmbar time`) to update a single block. You can also run `dwmbar <cmd> "<param>"` to manually set a block's text. For example, when I'm updating my RSS feed, I simply set the RSS block to 🔁 temporarily, instead of having a laborious check in the command itself.

Customize by changing `src/config.zig` and recompiling, [suckless](https://suckless.org) style.

`dwmbar` stores state in `/tmp/dwmbar`. It does not run as a daemon, only when updating a block.
