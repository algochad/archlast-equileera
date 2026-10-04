# Bushy Leaves `bushy_leaves`

![Screenshot](screenshot.png)

Makes leaves render bushy instead of boxy. Now with better performance and Plantlife support.

Tested with:

* [Minetest Game](https://content.luanti.org/packages/Minetest/minetest_game/)
* [VoxeLibre](https://content.luanti.org/packages/Wuzzy/mineclone2/)
* [Repixture](https://content.luanti.org/packages/Wuzzy/repixture/)
* [NodeCore](https://content.luanti.org/packages/Warr1024/nodecore/)
* [Mineclonia](https://content.luanti.org/packages/ryvnf/mineclonia/)


## `full` vs `cheap`

It can be hard to choose what mesh type you want for bushy leaves. By default
it is `full`, but you can configure bushy leaves to render with the `cheap`
mesh instead.

`full` mesh is (almost) identical to the the nodebox that was used in the
original mod.

![Screenshot: bushy leaves with `full` mesh type](screenshot_full.png)

`cheap` mesh has been simplified to get better performance. But it wasn't a
lossless optimization; you can see the differences from the `full` mesh here.

![Screenshot: bushy leaves with `cheap` mesh type](screenshot_cheap.png)

The choice is completely up to you. But if you're a server owner and want to
use this mod on your server (god forbid), at the very least do all your players
with lower end devices a favor and go with `cheap`.

Both meshes were created by singularis-mzf, see [`models/license.txt`](models/license.txt).
