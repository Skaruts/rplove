# RPLove

A RexPaint image (`.xp`) loader for Lua/Love2d.


## Usage

The `rplove.load` function will load and return a RexPaint image. You can then use or modify it however you want.

```lua
local rplove = require("rplove")

local img = rplove.load("my_rex_image.xp")

print(img.w, img.h, img.layers)

local cell = img:get_cell(1, 10, 10)
img:set_fg(1, 15, 15, my_color)

img:merge_layers()
```

# API

- ### RPLove

| Function | Description |
|---|---|
| load(filepath) | Loads a RexPaint image file (.xp) from `filepath`. |
| use_custom_color(mt, func_new) | Replaces the default color metatable with `mt` defined by the user. `func_new` must take four floats (0-1) as parameters. **IMPORTANT**: must be called before using anything else in rplove. |
| new_image(w, h, layers) | Creates and returns a new RPImage, with `w` and `h` size, and `layers` amount of layers. |
| new_color(r, g, b, a) | Creates a new color with the given components. |

- ### RPImage

`RPImage` objects can be printed (`print(a)`) and compared (`a == b`).

All `RPImage` properties are read-only.

#### Properties



| Property | Description |
|---|---|
| w, h        | Image dimensions |
| layers      | Image layer count |
| transp_mode | Image transparency mode (`"Rexpaint"` or `"Custom"`) |
| version     | Image version |
| chars       | The image's array of glyphs |
| fgs         | The image's array of foreground colors |
| bgs         | The image's array of background colors |

#### Methods

| Method | Description |
|---|---|
| clear() | Clear all layers in the image. |
| clear_layer(index) | Clear layer at `index`. |
| get_cell(layer, x, y) | Gets an `RPCell` object for the cell at coordinates `x` and `y` and in layer 'layer'. |
| RPImage:get_cell_unpacked(layer, x, y) | Gets the unpacked cell components at coordinates `x` and `y` and in layer 'layer'. |
| get_char(layer, x, y) | Gets the `char` component of the cell at coordinates `x` and `y` and in layer `layer`. |
| get_fg(layer, x, y) | Gets the `fg` component of the cell at coordinates `x` and `y` and in layer `layer`. |
| get_bg(layer, x, y) | Gets the `bg` component of the cell at coordinates `x` and `y` and in layer `layer`. |
| set_cell(layer, x, y, char, fg, bg) | Sets the components of the cell at coordinates `x`, `y`, in layer `layer`. Unneeded components can be passed as `nil` |
| set_char(layer, x, y, char) | Sets the `char` component of the cell at coordinates `x`, `y`, in layer `layer`. |
| set_fg(layer, x, y, fg) | Sets the `fg` component of the cell at coordinates `x`, `y`, in layer `layer`. |
| set_bg(layer, x, y, bg) | Sets the `bg` component of the cell at coordinates `x`, `y`, in layer `layer`. |
| is_transparent(layer_or_cell, x, y) | Checks if a cell is transparent at the given coordinates and layer. An RPCell object can be passed in instead. |
| merge_layers(top, bottom) | Merges layers down from `top` to `bottom`. If called without arguments, it merges all layers. |
| insert_layer_at(index) | Inserts a new layer at index `index`. Does nothing if image has maximum layers. |
| remove_layer_at(index) | Removes layer at index 'index'. Does nothing if there's only one layer. |
| set_custom_transp(char, fg, bg) | Sets custom cell components to use for transparent cells. If a component is nil, the default one is used. NOTE: this is a heavy operation, as it converts all the transparent cells in the entire image. |
| reset_transp() | Resets the transparent cells back to REXPaint's default. NOTE: this is a heavy operation, as it converts all the transparent cells in the entire image. |


- ### RPCell

`RPCell` objects can be printed (`print(a)`) and compared (`a == b`).

#### Properties

###### Note: changing a RPCell's properties doesn't change the image. Use `RPImage.set_cell` for that.

| Property | Description |
|---|---|
| char : number | The cell's glyph ascii index. |
| fg : Color    | The cell's foreground color. |
| bg : Color    | The cell's background color. |
