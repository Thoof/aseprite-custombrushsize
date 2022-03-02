-------------------------------------------------------------------------------
-- Aseprite script that lets the user change the size of a custom brush
-- By Thoof (@Thoof4 on twitter)
-------------------------------------------------------------------------------

local base_width = 0
local base_height = 0
local base_image = nil

local fgcolor_changed = false
local bgcolor_changed = false 

local last_recolored_image = nil

local resized_last_update = false
local last_image_scale_x = 100
local last_image_scale_y = 100

-- If we've got a custom brush currently then store it
if app.activeBrush.type == BrushType.IMAGE then
	base_width = app.activeBrush.image.width
	base_height = app.activeBrush.image.height
	base_image = app.activeBrush.image
end

local function convert_color_to_app_pixelcolor(color)
	return app.pixelColor.rgba(color.red, color.green, color.blue, color.alpha)
end 

local function get_image_alpha_array(image)
	local a = {}
	local count = 0
	for it in image:pixels() do
		local pixelValue = it()
		a[count] = app.pixelColor.rgbaA(pixelValue)
		
	end 
	
	return a
end

-- Compares the alphas of two images and returns true if they're the same --
local function image_alpha_comparison(image1, image2)
	if (image1 == nil or image2 == nil) then
		return false
	end
	
	if (image1.width ~= image2.width) or (image1.height ~= image2.height) then
		return false
	end
	
	-- Wasn't sure how to use the api iterator to compare two images so this is not efficient
	local alpha_array_1 = get_image_alpha_array(image1)
	local alpha_array_2 = get_image_alpha_array(image2)
	
	for i = 1, #alpha_array_1 do
		if alpha_array_1[i] ~= alpha_array_2[i] then
			return false
		end
	end
	
	return true

end 

local function does_image_have_transparency(image)
	for it in image:pixels() do
		local pixelValue = it()
		if app.pixelColor.rgbaA(pixelValue) < 255 then
			return true
		end 
	end 
	return false
end 

-- Colors a whole image with the specified color, without changing any alpha values --
local function color_whole_image_rgb(image, app_pixel_color)

	local color_r = app.pixelColor.rgbaR(app_pixel_color)
	local color_g = app.pixelColor.rgbaG(app_pixel_color)
	local color_b = app.pixelColor.rgbaB(app_pixel_color)
	
	for it in image:pixels() do
		local pixelValue = it()
		local alpha = app.pixelColor.rgbaA(pixelValue)
		local new_pixel_value = app.pixelColor.rgba(color_r, color_g, color_b, alpha)
		it(new_pixel_value) -- Set pixel

	end
end 


--[[  Applies the current foreground color to the image, in the same/a similar way to how brush colors change
	Rules for color change (These are only via my observations so may be somewhat inaccurate):
 		- If you have an image with any transparency at all, the foreground color is applied to all pixels in the image.
        Semitransparent pixels also get the same color but maintain their alpha value. When bg color is changed in this situation, nothing happens. 
		- If the image is a full image with no transparency, then:
			The foreground color will change the color of everything EXCEPT the first color found in the image.
			The background color will change the color of only pixels that were the first color found in the image. ]]--

local function apply_selected_colors_to_image(image, apply_foreground, apply_background)

	local current_fgcolor = convert_color_to_app_pixelcolor(app.fgColor)
	local current_bgcolor = convert_color_to_app_pixelcolor(app.bgColor)
	
	local image_has_transparency = does_image_have_transparency(image)
	
	-- Image transparent, so just apply the foreground color if applicable
	if image_has_transparency then
		
		if apply_foreground == false then
			return
		end
		
		color_whole_image_rgb(image, current_fgcolor)
	else
		local first_color = nil -- First color in the image, starting from the top left 
		local second_color = nil  -- Second color in the image, starting from the top left
		
		for it in image:pixels() do
			local pixelValue = it()
			
			-- Determine the first and second colors in the image
			if first_color == nil then
				first_color = pixelValue
			elseif (second_color == nil and pixelValue ~= first_color) then 
				second_color = pixelValue
			end
			
			-- Apply the fgcolor to any pixels that are not the first color found in the image
			if (apply_foreground and second_color ~= nil and pixelValue ~= first_color) then 
				it(current_fgcolor)
			elseif (apply_background and first_color ~= nil and pixelValue == first_color) then 
				it(current_bgcolor)
			end 
			
		end
	end 
	
end 

-- Detects if a new brush is found --
-- Called any time the user interacts with the widgets or changes fgcolor or bgcolor --
local function detect_new_brush_and_update()
	-- Scale up the base image to the previous scale, and compare alphas. If they are the same, it's the same brush
	
	local former_slider_val_percent_x = 0
	local former_slider_val_percent_y = 0
	local width = 0
	local height = 0
	local base_copy = nil
	
	if base_image ~= nil then	
		former_slider_val_percent_x = last_image_scale_x / 100
		former_slider_val_percent_y = last_image_scale_y / 100
		width = math.floor(base_width * former_slider_val_percent_x)
		height = math.floor(base_height * former_slider_val_percent_y)
		
		base_copy = base_image:clone()
		base_copy:resize(width, height)
		
		
	end
	
	
	if (image_alpha_comparison(app.activeBrush.image, base_copy) == false or base_image == nil) then

		-- Update the brush parameters, as we've switched brushes entirely since the last update -- 
		base_width = app.activeBrush.image.width
		base_height = app.activeBrush.image.height
		base_image = app.activeBrush.image
		last_recolored_image = nil
		fgcolor_changed = false
		bgcolor_changed = false 
	end
	
end

-- Resets the brush to the base brush, setting the scale & color back to the original -- 
local function reset_brush()

	-- If the brush isn't an image brush we want nothing to do with it
	if app.activeBrush.type ~= BrushType.IMAGE then
		return
	end
	
	detect_new_brush_and_update()

	app.activeBrush = Brush(base_image)
	last_recolored_image = nil

	last_image_scale_x = 100
	last_image_scale_y = 100
	resized_last_update = false
	fgcolor_changed = false
	bgcolor_changed = false
end

-- Initialize the dialog --
local dlg = Dialog { title = "Brush Size for Custom Brushes", onclose = reset_brush }

-- Resizes the current brush based on the current slider values --
local function resize_brush()
	local slider_val_x = dlg.data.size_x
	local slider_val_y = dlg.data.size_y
	
	local image_copy
	-- If we've got a recolored image (from changing fg/bgcolor) then use that instead of the base
	if last_recolored_image ~= nil then
		image_copy = last_recolored_image:clone()
	else
		image_copy = base_image:clone()
	end 
	
	local slider_val_x_percent = slider_val_x / 100
	local slider_val_y_percent = slider_val_y / 100
	local width = math.floor(base_width * slider_val_x_percent)
	local height = math.floor(base_height * slider_val_y_percent)
	
	image_copy:resize(width, height)
	
	resized_last_update = true

	app.activeBrush = Brush(image_copy)
	last_image_scale_x = slider_val_x
	last_image_scale_y = slider_val_y
end


dlg:slider {
    id = "size_x",
    label = "Width (%): ",
    min = 1,
    max = 200,
    value = 100,
	onchange = function()
	
		if dlg.data.check == true then 
			dlg:modify {id = "size_y",
			value = dlg.data.size_x }
		end
	
		-- If the brush isn't an image brush we want nothing to do with it
		if app.activeBrush.type ~= BrushType.IMAGE then
			return
		end
		
		detect_new_brush_and_update()
	
		resize_brush()
			
	end
}

dlg:slider {
    id = "size_y",
    label = "Height (%): ",
    min = 1,
    max = 200,
    value = 100,
	onchange = function()
	
		if dlg.data.check == true then 
			dlg:modify {id = "size_x",
			value = dlg.data.size_y }
		end 
		
		-- If the brush isn't an image brush we want nothing to do with it
		if app.activeBrush.type ~= BrushType.IMAGE then
			return
		end
		
		detect_new_brush_and_update()
	
		resize_brush()
			
	end
}

dlg:check {
	id = "check",
	label = "Maintain original aspect ratio",
	text = string,
	selected = boolean,
	onclick = function()
	
		detect_new_brush_and_update()
		
		if dlg.data.check == true then 
			dlg:modify {id = "size_y",
			value = dlg.data.size_x }
		end 
		
		resize_brush()
	end
}


dlg:button {
	id = "reset",
	text = "Reset brush",
	onclick = function()
		dlg:modify {id = "size_x",
			value = 100 }
		dlg:modify {id = "size_y",
			value = 100 }

		reset_brush()
	end 
}

-- When the fgcolor/bgcolor change, we want to store a version of the brush image at the original image scale
app.events:on('fgcolorchange',
	function()
	
		-- If the brush isn't an image brush we want nothing to do with it
		if app.activeBrush.type ~= BrushType.IMAGE then
			return
		end
		
		detect_new_brush_and_update()
	
		fgcolor_changed = true
		last_recolored_image = base_image:clone()
		apply_selected_colors_to_image(last_recolored_image, fgcolor_changed, bgcolor_changed)
		

		end)
	
app.events:on('bgcolorchange',
	function()
	
		-- If the brush isn't an image brush we want nothing to do with it
		if app.activeBrush.type ~= BrushType.IMAGE then
			return
		end
		
		detect_new_brush_and_update() -- So we save the new brush here, but it's already a different color
		
		bgcolor_changed = true
		
		last_recolored_image = base_image:clone()
		apply_selected_colors_to_image(last_recolored_image, fgcolor_changed, bgcolor_changed)


		end)

dlg:show { 
	wait = false
}