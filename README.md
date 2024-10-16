# RPLove

A loader for RexPaint images (`.xp` files).


# Usage

The `rplove.load` function will load and return a RexPaint image. You can then use or modify it however you want.

```lua
local rplove = require("rplove")

local img = rplove.load(filepath)

print(img.w, img.h, img.layers)

local cell = img:get_cell(1, 10, 10)
img:set_fg(1, 15, 15, my_color)

img:merge_layers()
```


