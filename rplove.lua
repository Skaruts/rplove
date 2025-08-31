--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
-- MIT License
--
-- Copyright (c) 2019 Skaruts
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
--[[

		RPLove - A REXPaint image importer for lua/love2d (WIP)


	Quick Reference:

		Usage:
			local rplove = require("rplove")
			local img = rplove.load(filepath)
			img.set_fg(1, 5, 5, rplove.new_color(1, 0.5, 0, 1))

		Optionally use:
			rplove.use_custom_color(MyColor, MyColor.new)  -- must be called before loading images
			rplove.new_image(w, h, layers)  -- Not very useful yet (no way to save)

		Images
			Images can be compared (a == b) and printed ( print(my_image) )

			Properties: (all fields are read-only)
				w, h            - image dimensions
				layers          - image layer count
				transp_mode     - image transparency mode ("Rexpaint" or "Custom")
				version         - image version
				chars           - the image's array of glyphs
				fgs             - the image's array of foreground colors
				bgs             - the image's array of background colors

			Methods:
				RPImage.clear()
				RPImage.clear_layer(index)

				RPImage.get_cell(layer, x, y)
				RPImage.get_cell_unpacked(layer, x, y)
				RPImage.get_char(layer, x, y)
				RPImage.get_fg(layer, x, y)
				RPImage.get_bg(layer, x, y)

				RPImage.set_cell(layer, x, y, char, fg, bg)
				RPImage.set_char(layer, x, y, char)
				RPImage.set_fg(layer, x, y, fg)
				RPImage.set_bg(layer, x, y, bg)

				RPImage:is_transparent(layer_or_cell, x, y)

				RPImage.merge_layers(top, bottom)

				RPImage.insert_layer_at(index)
				RPImage.remove_layer_at(index)
				RPImage.set_custom_transp(char, fg, bg)
				RPImage.reset_transp()


		Cells:
			Cells can be compared (a == b) and printed ( print(my_cell) )

			Properties:
				char    - glyph value
				fg      - foreground color
				bg      - background color


		Colors:
			Colors can be compared (a == b) and printed ( print(my_color) )

			Properties:
				r, g, b, a    - color components



	TODO:
		- check if love is fused and mounted before reading from files save images
		- rplove.save(filepath)
		- check arg types
]]
--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
local remove       = table.remove
local insert       = table.insert
local unpack       = unpack
local byte         = string.byte
local fmt          = string.format
local max          = math.max
local min          = math.min
local setmetatable = setmetatable
local rawequal     = rawequal
local rawset       = rawset
local type         = type
local assert       = assert



-- helpers
local function errorf(level, msg, ...)
	error(fmt(msg, ...), level+1)
end

-- a global 'NO_TYPE_CHECKING' flag can be set to true, to disable type checking
local checktype
if NO_TYPE_CHECKING then
	checktype = function(arg) return arg end
else
	checktype = function(arg, pos, req_type, level)
		local tp = type(arg)
		if tp == req_type then return end
		if tp == "table" and arg.__type and arg.__type == req_type then return end
		errorf(level+1, "bad argument #%d to '%s': %s expected, got %s", pos, debug.getinfo(level).name, req_type, type(arg))
	end
end



--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--

-- 		Quick and dirty file handling helper

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
local function File(filepath, format)
	local t = {
		_cursor = 1,
		content = nil,
		size = 0,
	}
	-- __tostring = function(self)   return fmt("File(\n%s\n)", self.content)   end,
	function t:load(filepath)
		self._cursor = 1
		if not love.filesystem.getInfo(filepath) then errorf(3, "(File.load) couldn'self load file at '%s'", filepath) end
		self.content, self.size = love.filesystem.read(filepath)
		self.content = love.data.decompress("string", 'gzip', self.content)
	end
	function t:move(num_bytes)
		-- move the position in the file by 'num_bytes' (negative moves backward)
		self._cursor = self._cursor + num_bytes
	end
	function t:get_bytes(ammount)
		local bytes = byte(self.content, self._cursor, self._cursor+ammount-1)
		self:move(ammount)
		return bytes
	end
	function t:get_8() return self:get_bytes(1) end -- returns the next byte
	function t:get_32() return self:get_bytes(4) end  -- returns the next 4 bytes

	-- load the file
	t:load(filepath, format)
	return t
end



--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--

--        Quick Color class
--
--    Can be replaced by another color class, using
--       rplove.use_custom_color(MyColor, MyColor.new)

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
-- this allows you to access 'color.r', etc, while keeping the color as a simple array
local _lookup_idxs = {r=1, g=2, b=3, a=4}

local _COLOR_TYPE = "RPColor"
local COL_MT = { __type = _COLOR_TYPE }

function COL_MT.__index(t, k)
	-- TODO: shouldn't this do rawget(t, k) as well, at some point?)
	return _lookup_idxs[k] and t[_lookup_idxs[k]] or COL_MT[k]
end

function COL_MT.__newindex(t, k, v)
    if not _lookup_idxs[k] then errorf(2, "invalid field or method '%s'", k) end
    t[_lookup_idxs[k]] = v
end

function COL_MT.__tostring(t)
	return fmt("(%s,%s,%s,%s)", t[1], t[2], t[3], t[4])
end

function COL_MT.__eq(a, b)
	return rawequal(a, b) or a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

local function _new_color(r, g, b, a)
	if not g then
		r, g, b, a = r.r, r.g, r.b, r.a
	end
	return setmetatable(g and {r,g,b,a or 1} or {r[1], r[2], r[3], r[4] or 1}, COL_MT)
end



--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--

--        RPCell
--
--    Not used internally. Cells objects are only created when a user calls
--		RPImage.new_cell
--		RPImage.get_cell

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
local _cell_fields = {
	char = function(self) return self[1] end,
	fg   = function(self) return self[2] end,
	bg   = function(self) return self[3] end,
}

local RPCell = {
	__type = "RPCell",
	__tostring = function(self)
		return fmt("RPCell(%s, %s, %s)", self.char, self.fg, self.bg)
	end,
	__eq = function(self, other)
		return self[1] == other[1] and self[2] == other[2] and self[3] == other[3]
	end,
}

RPCell.__index = function(self, k)
	return _cell_fields[k] and _cell_fields[k](self)
		or RPCell[k]
end



--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--

-- 		RPImage

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
local _ERR_BOUNDS = "index out of bounds: %d, %d, %d (layer, x, y)"
local __VERSION = 0

local _PINK   = _new_color(1, 0, 1, 1)
local _TRANSP = _new_color(0, 0, 0, 0)
local _BLACK  = _new_color(0, 0, 0, 1)

local _REX_EMPTY_CELL = {32, _BLACK, _PINK}
local _CUSTOM_EMPTY_CELL = {0, _TRANSP, _TRANSP}

local _REX_TRANSP_MODE = "Rexpaint"
local _CUSTOM_TRANSP_MODE = "Custom"

local _read_only = {
	w=true,
	h=true,
	layers=true,
	version=true,
	transp_mode=true,
	chars=true,
	fgs=true,
	bgs=true,
}

local _fields = {
	w            = function(self) return self._w end,
	h            = function(self) return self._h end,
	layers       = function(self) return self._layers end,
	transp_mode  = function(self) return self._transp_mode end,
	version      = function(self) return self._version end,
	chars        = function(self) return self._chars end,
	fgs          = function(self) return self._fgs end,
	bgs          = function(self) return self._bgs end,
}

local RPImage = { __type = "RPImage" }

RPImage.__index = function(self, k)
	return _fields[k] and _fields[k](self) or RPImage[k]
end

RPImage.__newindex = function(self, k, v)
	if _read_only[k] then errorf(2, "field '%s' is read only", k) end
	rawset(self, k, v) -- TODO: check if this is correct
end

function RPImage.__tostring(self)
	return fmt("RPImage(%s x %s x %s)", self._w, self._h, self._layers)
end

function RPImage.__eq(self, other)
	if self._w ~= other._w or self._h ~= other._h
	or self._layers ~= other._layers
	-- or self._transp_mode ~= other._transp_mode
	then return false end

	for l=1, self._layers do
		local tchars, tfgs, tbgs = self._chars[l], self._fgs[l], self._bgs[l]
		local ochars, ofgs, obgs = other._chars[l], other._fgs[l], other._bgs[l]
		for i=0, self._w*self._h-1 do
			if tchars[i] ~= ochars[i]
			or tfgs[i]   ~= ofgs[i]
			or tbgs[i]   ~= obgs[i]
			then
				return false
			end
		end
	end
	return true
end


local function _init_layer(self)
	local char, fg, bg = self._empty_cell[1], self._empty_cell[2], self._empty_cell[3]
	local lc, lf, lb = {}, {}, {}
	for i=0, self._w*self._h-1 do
		lc[i], lf[i], lb[i] = char, fg, bg
	end
	return lc, lf, lb
end

local function _init_cells(self)
	self._chars, self._fgs, self._bgs = {}, {}, {}
	for l=1, self._layers do
		self._chars[l], self._fgs[l], self._bgs[l] = _init_layer(self)
	end
end

local function _new_image(w, h, layers, version)
	local t = setmetatable( {
		_version      = version or __VERSION,
		_w            = w or 80,
		_h            = h or 50,
		_layers       = layers or 1,
		_chars        = true, -- booleans just to reserve read only fields
		_fgs          = true,
		_bgs          = true,
		_transp_mode = _REX_TRANSP_MODE,
		_empty_cell   = _REX_EMPTY_CELL,
	}, RPImage )

	_init_cells(t)
	return t
end

--fill layer at 'idx' with empty cells
function RPImage:clear_layer(idx)
	if idx < 1 or idx > self._layers then return end
	local lc, lf, lb = self._chars[idx], self._fgs[idx], self._bgs[idx]
	local char, fg, bg = unpack(self._empty_cell)
	for i=0, self._w*self._h-1 do
		lc[i] = char
		lf[i] = fg
		lb[i] = bg
	end
end

-- clear all layers
function RPImage:clear()
	for l=1, self._layers do
		self:clear_layer(l)
	end
end

local function _validate_position(self, l, x, y)
	return l > 0 and l <= self._layers
	   and x >= 0 and x < self._w
	   and y >= 0 and y < self._h
end

-- create a new 'RPCell' object
function RPImage:new_cell(char, fg, bg)
	local ec = self.transp_mode == _REX_TRANSP_MODE
		and _REX_EMPTY_CELL
		 or self._empty_cell

	return setmetatable( { char or ec[1], fg or ec[2], bg or ec[3] }, RPCell )
end


-- Get an `RPCell` object for the cell at coordinates `x` and `y` and in layer 'layer'.
function RPImage:get_cell(layer, x, y)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then errorf(2, _ERR_BOUNDS, layer, x, y) end
	local i = x+y*self._w
	return self:new_cell(self._chars[layer][i], self._fgs[layer][i], self._bgs[layer][i])
end

-- Get the unpacked cell components at coordinates `x` and `y` and in layer 'layer'.
function RPImage:get_cell_unpacked(layer, x, y)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then errorf(2, _ERR_BOUNDS, layer, x, y) end
	local i = x+y*self._w
	return self._chars[layer][i], self._fgs[layer][i], self._bgs[layer][i]
end

-- Get the `char` component of the cell at coordinates `x` and `y` and in layer `layer`.
function RPImage:get_char(layer, x, y)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then errorf(2, _ERR_BOUNDS, layer, x, y) end
	return self._chars[layer][x+y*self._w]
end

-- Get the `fg` component of the cell at coordinates `x` and `y` and in layer `layer`.
function RPImage:get_fg(layer, x, y)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)

	if not _validate_position(self, layer, x, y) then errorf(2, _ERR_BOUNDS, layer, x, y) end
	return self._fgs[layer][x+y*self._w]
end

-- Get the `bg` component of the cell at coordinates `x` and `y` and in layer `layer`.
function RPImage:get_bg(layer, x, y)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)

	if not _validate_position(self, layer, x, y) then errorf(2, _ERR_BOUNDS, layer, x, y) end
	return self._bgs[layer][x+y*self._w]
end

-- Set the components of the cell at coordinates `x`, `y`, in layer `layer`.
-- (unneeded components can be passed as nil)
-- param 'char' : number | RPCell | table as {char, fg, bg}
-- param 'fg'   : _COLOR_TYPE
-- param 'bg'   : _COLOR_TYPE
function RPImage:set_cell(layer, x, y, char, fg, bg)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)

	if not _validate_position(self, layer, x, y) then return end
	local idx = x+y*self._w

	if type(char) == "table" then
		char, fg, bg = char[1], char[2], char[3]
	end

	if char then
		checktype(char, 4, "number", 2)
		self._chars[layer][idx] = char
	end
	if fg then
		checktype(fg, 5, _COLOR_TYPE, 2)
		self._fgs[layer][idx] = fg
	end
	if bg then
		checktype(bg, 6, _COLOR_TYPE, 2)
		self._bgs[layer][idx] = bg
	end
end

-- set the `char` component of the cell at coordinates `x`, `y`, in layer `layer`.
-- param 'char' : number | RPCell | table as {char, fg, bg}
function RPImage:set_char(layer, x, y, char)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then return end
	checktype(char, 4, "number", 2)
	self._chars[layer][x+y*self._w] = char
end

-- set the `fg` component of the cell at coordinates `x`, `y`, in layer `layer`.
-- param 'fg'   : _COLOR_TYPE
function RPImage:set_fg(layer, x, y, fg)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then return end
	checktype(fg, 4, "table", 2)
	self._fgs[layer][x+y*self._w] = fg
end

-- set the `bg` component of the cell at coordinates `x`, `y`, in layer `layer`.
-- param 'bg'   : _COLOR_TYPE
function RPImage:set_bg(layer, x, y, bg)
	checktype(layer, 1, "number", 2)
	checktype(x, 2, "number", 2)
	checktype(y, 3, "number", 2)
	if not _validate_position(self, layer, x, y) then return end
	checktype(bg, 4, "table", 2)
	self._bgs[layer][x+y*self._w] = bg
end

-- TODO: this function doesn't need all args
local function _is_cell_transp_rex(_, _, bg)
	return bg == _PINK
end

local function _is_cell_transp_custom(char, fg, bg)
	return bg == _TRANSP and (fg == _TRANSP or char == 0)
end


-- Check if a cell is transparent at the given coordinates and layer.
-- An RPCell object can be passed in instead.
function RPImage:is_transparent(layer_or_cell, x, y)
	local char, fg, bg

	if not x then
		local cell = layer_or_cell
		checktype(cell, 1, "RPCell", 2)
		char, fg, bg = cell.char, cell.fg, cell.bg
	else
		local layer = layer_or_cell
		checktype(layer, 1, "number", 2)
		checktype(x, 2, "number", 2)
		checktype(y, 3, "number", 2)
		local idx = x+y*self._w
		char, fg, bg = self._chars[layer][idx], self._fgs[layer][idx], self._bgs[layer][idx]
	end

	if self._transp_mode == _REX_TRANSP_MODE then
		return _is_cell_transp_rex(char, fg, bg)
	else
		return _is_cell_transp_custom(char, fg, bg)
	end
end


-- Merge layers down from `top` to `bottom`.
-- If called without arguments, it merges all layers.
function RPImage:merge_layers(top, bottom)
	bottom, top = bottom or 1, top or self._layers

	top    = min( max(bottom, top), self._layers )
	bottom = max( min(bottom, top), 1 )

	if self._layers == 1 or bottom == top then return end

	local transp_func = self._transp_mode == _REX_TRANSP_MODE
					and _is_cell_transp_rex
					 or _is_cell_transp_custom

	local bc, bf, bb = self._chars[bottom], self._fgs[bottom], self._bgs[bottom]
	for l = bottom+1, top do
		local tc, tf, tb = self._chars[l], self._fgs[l], self._bgs[l]
		for j=0, self._h-1 do
			for i=0, self._w-1 do
				local idx = i+j*self._w
				if not transp_func(tc[idx], tf[idx], tb[idx]) then
					bc[idx] = tc[idx]
					bf[idx] = tf[idx]
					bb[idx] = tb[idx]
				end
			end
		end
	end

	-- remove merged layers
	while top ~= bottom do
		remove(self._chars, top)
		remove(self._fgs, top)
		remove(self._bgs, top)
		top = top - 1
		self._layers = self._layers - 1
	end

	return self
end


-- Set custom cell components to use for transparent cells. If a component is nil, the default one is used.
-- NOTE: this is a heavy operation, as it converts all the transparent cells
-- in the entire image.
function RPImage:set_custom_transp(char, fg, bg)
	local cell = {
		char or _CUSTOM_EMPTY_CELL[1],
		fg or _CUSTOM_EMPTY_CELL[2],
		bg or _CUSTOM_EMPTY_CELL[3],
	}

	self._transp_mode = _CUSTOM_TRANSP_MODE
	self._empty_cell = cell

	for l=1, self._layers do
		local cl, fl, bl = self._chars[l], self._fgs[l], self._bgs[l]
		for i=0, self._w*self._h-1 do
			if bl[i] == _PINK then
				cl[i] = cell[1]
				fl[i] = cell[2]
				bl[i] = cell[3]
			end
		end
	end
end

-- Reset the transparent cells back to REXPaint's default (32, black, pink)
-- NOTE: this is a heavy operation, as it converts all the transparent cells
-- in the entire image.
function RPImage:reset_transp()
	if self._transp_mode == _REX_TRANSP_MODE then
		print("RPImage.reset_transp: transparency mode is already RexPaint mode - skipping")
		return
	end
	self._transp_mode = _REX_TRANSP_MODE
	self._empty_cell = _REX_EMPTY_CELL

	local func = _is_cell_transp_custom

	for l=1, self._layers do
		cl, fl, bl = self._chars[l], self._fgs[l], self._bgs[l]
		for i=0, self._w*self._h-1 do
			if func(cl[i], fl[i], bl[i]) then
				cl[i] = _REX_EMPTY_CELL[1]
				fl[i] = _REX_EMPTY_CELL[2]
				bl[i] = _REX_EMPTY_CELL[3]
			end
		end
	end
end

-- Inserts a new layer at index `index`. Does nothing if image has maximum layers.
-- TODO: check bounds
function RPImage:insert_layer_at(index)
	if self._layers >= 9 then return end
	local lc, lf, lb = _init_layer(self)
	insert(self._chars, index, lc)
	insert(self._fgs, index, lf)
	insert(self._bgs, index, lb)
	self._layers = self._layers + 1
end

-- Removes layer at index 'index'. Does nothing if there's only one layer.
-- TODO: check bounds
function RPImage:remove_layer_at(index)
	if self._layers < 1 then return end
	if index < 1 or index > self._layers then return end
	remove(self._chars, index)
	remove(self._fgs, index)
	remove(self._bgs, index)
	self._layers = self._layers - 1
end



--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--

-- 		rplove API

--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--=--
local rplove = {}

-- Replace the default color metatable with one defined by the user
-- IMPORTANT: must be called before using anything else in rplove
function rplove.use_custom_color(color_mt, func_new_from_floats)
	COL_MT = color_mt
	_COLOR_TYPE = COL_MT.__type
	_new_color = func_new_from_floats

	_PINK   = _new_color(1, 0, 1, 1)
	_TRANSP = _new_color(0, 0, 0, 0)
	_BLACK  = _new_color(0, 0, 0, 1)

	_REX_EMPTY_CELL = {32, _BLACK, _PINK}
	_CUSTOM_EMPTY_CELL = {0, _TRANSP, _TRANSP}
end

-- Create a new RPImage object
-- param 'w'      : number
-- param 'h'      : number
-- param 'layers' : number
function rplove.new_image(w, h, layers)
	return _new_image(w, h, layers, __VERSION)
end

-- Create a new color object
-- all components must be numbers between 0 - 1
function rplove.new_color(r, g, b, a)
	return _new_color(r, g, b, a)
end

-- load a RexPaint image file (.xp)
function rplove.load(filepath)
	if type(filepath) ~= "string" then
		errorf(2, "invalid file path '%s'", filepath)
	end

	local file = File(filepath)

	local version = file:get_32() --move(4)    -- ignore image version
	local layers = file:get_32()
	local w = file:get_32()
	local h = file:get_32()

	local img = _new_image(w, h, layers, version)

	for l=1, layers do
		-- ignore width and height at the start of each layer
		if l > 1 then file:move(8) end
		local chars, fgs, bgs = img._chars[l], img._fgs[l], img._bgs[l]

		for i=0, w-1 do -- rex paint uses column major order
			for j=0, h-1 do
				local idx = i+j*w
				chars[idx] = file:get_32()
				fgs[idx] = _new_color( file:get_8()/255, file:get_8()/255, file:get_8()/255 )
				bgs[idx] = _new_color( file:get_8()/255, file:get_8()/255, file:get_8()/255 )
			end
		end
	end

	for l=1, layers do
		local chars, fgs, bgs = img._chars[l], img._fgs[l], img._bgs[l]
		for j=0, h-1 do
			for i=0, w-1 do
				local idx = i+j*w
			end
		end
	end

	return img
end

-- TODO: function RPLove.save(filepath) end



return rplove
