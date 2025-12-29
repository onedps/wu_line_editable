--!native
--!optimize 2

--@one_dps

local function abs(number) return number < 0 and -number or number end
local bor = bit32.bor
local lshift = bit32.lshift
local function floor(number) return number - number % 1 end
local rshift = bit32.rshift
local band = bit32.band

local user_input_service = game:GetService("UserInputService")
local asset_service = game:GetService("AssetService")
local run_service = game:GetService("RunService")
local gui_service = game:GetService("GuiService")

local image_label = script.Parent
local size = image_label.AbsoluteSize
local editable_image = asset_service:CreateEditableImage({Size = size})

local frame_buffer = buffer.create(editable_image.Size.X * editable_image.Size.Y * 4)

local draw_pixel = function(x: number, y: number, color: number)
	buffer.writeu32(frame_buffer, (y * editable_image.Size.X + x) * 4, color)
end

local Color4_new = function(r: number, g: number, b: number, a: number): number
	return bor(
		lshift(a * 255, 24),
		lshift(b * 255, 16), 
		lshift(g * 255, 8),
		r * 255
	)
end

local get_relative_mouse_pos = function(image_label: ImageLabel): Vector2
	local inset, _ = gui_service:GetGuiInset()
	local inset_pos = user_input_service:GetMouseLocation() - image_label.AbsolutePosition - inset
	local scale = inset_pos / image_label.AbsoluteSize
	local relative_pos = scale * editable_image.Size
	
	local x, y = floor(relative_pos.X + .5), floor(relative_pos.Y + .5)
	
	return Vector2.new(x, y)
end

-- алгоритм ву, но... чуток оптимизирован. вы можете поэкспериментировать с fixed_point, я советую 65536 потому что больше стабильности.
local draw_line = function(x0, y0, x1, y1, color: Color3)
	local fixed_point = 16384
	local mask = fixed_point - 1

	local r, g, b = color.R, color.G, color.B
	
	local dx = x1 - x0
	local dy = y1 - y0

	if abs(y1 - y0) < abs(x1 - x0) then
		if x1 < x0 then
			x0, x1 = x1, x0
			y0, y1 = y1, y0
		end

		local m = (dx ~= 0) and floor((dy * fixed_point) / dx) or 1

		local start_x, end_x = floor(x0 + .5), floor(x1 + .5)
		local y_fp = floor((y0 + (start_x - x0) * (dy / dx)) * fixed_point)

		for ix = start_x, end_x do
			local overlap = (ix == start_x and 1 - ((x0 + .5) - floor(x0 + .5))) or (ix == end_x and ((x1 + .5) - floor(x1 + .5))) or 1

			local iy = rshift(y_fp, 16)
			local dist = band(y_fp, mask) / fixed_point

			local a1 = (1 - dist) * overlap
			local a2 = dist * overlap

			draw_pixel(ix, iy,  Color4_new(r, g, b, a1))
			draw_pixel(ix, iy + 1, Color4_new(r, g, b, a2))

			y_fp = y_fp + m
		end
	else
		if y1 < y0 then
			x0, x1 = x1, x0
			y0, y1 = y1, y0
		end

		local m = (dy ~= 0) and floor((dx * fixed_point) / dy) or 1

		local start_y, end_y = floor(y0 + .5), floor(y1 + .5)
		local x_fp = floor((x0 + (start_y - y0) * (dx / dy)) * fixed_point)

		for iy = start_y, end_y do
			local overlap = (iy == start_y and 1 - ((y0 + .5) - floor(y0 + .5))) or (iy == end_y and ((y1 + .5) - floor(y1 + .5))) or 1

			local ix = rshift(x_fp, 16)
			local dist = band(x_fp, mask) / fixed_point

			local a1 = (1 - dist) * overlap
			local a2 = dist * overlap

			draw_pixel(ix, iy, Color4_new(r, g, b, a1))
			draw_pixel(ix + 1, iy, Color4_new(r, g, b, a2))

			x_fp = x_fp + m
		end
	end
end

run_service.RenderStepped:Connect(function()
	frame_buffer = buffer.create(editable_image.Size.X * editable_image.Size.Y * 4)
	
	local mouse = get_relative_mouse_pos(image_label)
	draw_line(editable_image.Size.X / 2, editable_image.Size.Y / 2, mouse.X, mouse.Y, Color3.fromRGB(255, 255, 255))
	
	editable_image:WritePixelsBuffer(Vector2.zero, editable_image.Size, frame_buffer)
	image_label.ImageContent = Content.fromObject(editable_image)
end)
