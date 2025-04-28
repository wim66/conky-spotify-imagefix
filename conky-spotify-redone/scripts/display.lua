-- display.lua
-- by @wim66
-- v.1.2
-- April 28, 2025

-- === Required Cairo Modules ===
require 'cairo'

-- Attempt to safely require the 'cairo_xlib' module
local status, cairo_xlib = pcall(require, 'cairo_xlib')

if not status then
    -- If not found, fall back to a dummy table
    -- Redirects unknown keys to the global namespace (_G)
    -- Allows use of global Cairo functions like cairo_xlib_surface_create
    cairo_xlib = setmetatable({}, {
        __index = function(_, key)
            return _G[key]
        end
    })
end

-- === Load settings.lua from parent directory ===
local script_path = debug.getinfo(1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
local parent_path = script_path:match("^(.*[\\/])resources[\\/].*$") or ""
package.path = package.path .. ";" .. parent_path .. "?.lua"

local status, err = pcall(function() require("settings") end)
if not status then
    print("Error loading settings.lua: " .. err)
    return
end
if not conky_vars then
    print("Error: conky_vars not defined")
    return
end
conky_vars()

-- === Utility ===
local unpack = table.unpack or unpack  -- Compatibility for Lua 5.1 and newer

-- === Execute shell scripts and fetch output ===
local function execute_script(script_path)
    local handle = io.popen(script_path .. " 2>/dev/null")
    if not handle then
        print("Error executing script: " .. script_path)
        return "Unknown"
    end
    local result = handle:read("*a")
    handle:close()
    -- Trim whitespace and return result, or fallback if empty
    result = result:gsub("^%s*(.-)%s*$", "%1")
    return result ~= "" and result or "Unknown"
end

-- === Check if Spotify is running with caching ===
local last_status = nil
local last_check_time = 0
local function is_spotify_running()
    local now = os.time()
    if now - last_check_time < 5 and last_status ~= nil then
        return last_status
    end
    local cmd = [[dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'PlaybackStatus' 2>/dev/null]]
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    last_status = result:match("string") ~= nil
    last_check_time = now
    return last_status
end

-- === Execute cover script (no output expected) ===
local function execute_cover_script()
    local script_path = parent_path .. "scripts/cover.sh"
    local handle = io.popen("timeout 2 " .. script_path .. " 2>&1")
    if not handle then
        print("Error executing cover script")
        return false
    end
    handle:close()
    return true
end

-- === Fetch all Spotify metadata in one call ===
local function get_spotify_metadata()
    local cmd = [[dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata']]
    local handle = io.popen(cmd .. " 2>&1")
    if not handle then
        print("Error fetching metadata")
        return { title = "Unknown Title", artist = "Unknown Artist", album = "Unknown Album", status = "Paused" }
    end
    local output = handle:read("*a")
    handle:close()

    local metadata = { title = "Unknown Title", artist = "Unknown Artist", album = "Unknown Album", status = "Paused" }

    -- Extract title
    local title = output:match('xesam:title.-variant%s+string%s+"([^"]+)"')
    if title then
        metadata.title = title
    end

    -- Extract artist
    local artist = output:match('xesam:artist.-string%s+"([^"]+)"')
    if artist then
        metadata.artist = artist
    end

    -- Extract album
    local album = output:match('xesam:album.-variant%s+string%s+"([^"]+)"')
    if album then
        metadata.album = album
    end

    -- Extract playback status
    local status_cmd = [[dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'PlaybackStatus' 2>/dev/null]]
    local status_handle = io.popen(status_cmd)
    if status_handle then
        local status_output = status_handle:read("*a")
        status_handle:close()
        local status = status_output:match('string%s+"([^"]+)"')
        if status then
            metadata.status = status
        end
    end

    return metadata
end

-- === Fetch progress data ===
local function get_progress_data()
    local script_path = parent_path .. "scripts/progress.sh"
    local progress = execute_script(script_path)
    local percent, elapsed, remaining = progress:match("(%d+)|([^|]+)|([^|]+)")
    percent = tonumber(percent) or 0
    elapsed = elapsed or "0:00"
    remaining = remaining or "0:00"
    return {
        percent = percent,
        elapsed = elapsed,
        remaining = remaining
    }
end

-- === Color parsing helpers ===
local function parse_border_color(border_color_str)
    local gradient = {}
    for position, color, alpha in border_color_str:gmatch("([%d%.]+),0x(%x+),([%d%.]+)") do
        table.insert(gradient, {tonumber(position), tonumber(color, 16), tonumber(alpha)})
    end
    if #gradient == 3 then
        return gradient
    end
    return { {0, 0x003E00, 1}, {0.5, 0x03F404, 1}, {1, 0x003E00, 1} }
end

local function parse_border_color2(border_color2_str)
    local gradient = {}
    for position, color, alpha in border_color2_str:gmatch("([%d%.]+),0x(%x+),([%d%.]+)") do
        table.insert(gradient, {tonumber(position), tonumber(color, 16), tonumber(alpha)})
    end
    if #gradient == 3 then
        return gradient
    end
    return { {0, 0x003E00, 1}, {0.5, 0x03F404, 1}, {1, 0x003E00, 1} }
end

local function parse_bg_color(bg_color_str)
    local hex, alpha = bg_color_str:match("0x(%x+),([%d%.]+)")
    if hex and alpha then
        return { {1, tonumber(hex, 16), tonumber(alpha)} }
    end
    return { {1, 0x000000, 1} }
end

-- === Color values from settings.lua ===
local border_color = parse_border_color(border_COLOR)
local bg_color = parse_bg_color(bg_COLOR)
local border_color2 = parse_border_color2(border_COLOR2)

-- === Table of drawable elements ===
local boxes_settings = {
    {
        type = "background", -- Track info background
        x = 172, y = 2, w = 488, h = 167,
        centre_x = false,
        corners = {0, 0, 0, 0},
        draw_me = true,
        colour = bg_color
    },

    {
        type = "layer2", -- Track info background
        x = 172, y = 2, w = 488, h = 167,
        centre_x = false,
        corners = {0, 0, 0, 0},
        draw_me = true,
        linear_gradient = {172, 2, 172, 169}, -- Gradient from top to bottom
        colours = {
            {0, 0x000000, 0.2},
            {0.33, 0xC0C0C0, 0.2},
            {0.66, 0xC0C0C0, 0.2},
            {1, 0x000000, 0.2}
        }
    },

    {
        type = "border", -- Track info border
        x = 172, y = 2, w = 488, h = 167,
        centre_x = false,
        corners = {0, 0, 0, 0},
        draw_me = true,
        border = 3,
        colour = border_color,
        linear_gradient = {172, 85, 653, 85}
    },

    {
        type = "image", -- Album art image
        path = parent_path .. "current/current.png",
        x = 5, y = 5, w = 164, h = 164,
        draw_me = true
    },

    {
        type = "border", -- Image border
        x = 2, y = 2, w = 167, h = 167,
        centre_x = false,
        corners = {0, 0, 0, 0},
        draw_me = true,
        border = 3,
        colour = border_color2,
        linear_gradient = {2, 85, 169, 85}
    },

    -- Label: Title
    {
        type = "text",
        x = 180, y = 20,
        text = "Title:",
        font = "Noto Sans",
        font_size = 12,
        colour = {{1, 0xFFFF00, 1}}, 
        draw_me = true
    },

    -- Metadata: Title
    {
        type = "text",
        x = 190, y = 44,
        text = "title",
        font = "GE Inspira",
        font_size = 22,
        colour = {{1, 0xFFBC6B, 1}}, 
        draw_me = true
    },

    -- Label: Artist
    {
        type = "text",
        x = 180, y = 64,
        text = "Artist:",
        font = "Noto Sans",
        font_size = 12,
        colour = {{1, 0xFFFF00, 1}}, 
        draw_me = true
    },

    -- Metadata: Artist
    {
        type = "text",
        x = 190, y = 88,
        text = "artist",
        font = "GE Inspira",
        font_size = 22,
        colour = {{1, 0xFFBC6B, 1}}, 
        draw_me = true
    },

    -- Label: Album
    {
        type = "text",
        x = 180, y = 108,
        text = "Album:",
        font = "Noto Sans",
        font_size = 12,
        colour = {{1, 0xFFFF00, 1}}, 
        draw_me = true
    },

    -- Metadata: Album
    {
        type = "text",
        x = 190, y = 132,
        text = "album",
        font = "GE Inspira",
        font_size = 22,
        colour = {{1, 0xFFBC6B, 1}}, 
        draw_me = true
    },

    -- Progress bar (filled)
    {
        type = "background",
        x = 210, y = 158, w = 0, h = 6,
        centre_x = false,
        corners = {3, 3, 3, 3}, -- Rounded corners
        draw_me = true,
        linear_gradient = {210, 161, 640, 161}, -- Adjusted for 430px
        colours = { 
            {0, 0xFFAA00, 1},
            {0.5, 0xFF5500, 1},
            {1, 0x802a00, 1}
        }
    },

    -- Progress bar border
    {
        type = "border",
        x = 210, y = 158, w = 430, h = 6,
        centre_x = false,
        corners = {3, 3, 3, 3}, -- Adjusted for consistency
        draw_me = true,
        border = 1,
        colour = {{1, 0xaa7b9e, 1}},
        linear_gradient = {210, 161, 640, 161} -- Adjusted for 430px
    },

    -- Elapsed time
    {
        type = "text",
        x = 210, y = 154,
        text = "elapsed",
        font = "Noto Sans",
        font_size = 12,
        colour = {{1, 0xFFFFFF, 1}}, 
        draw_me = true
    },

    -- Remaining time
    {
        type = "text",
        x = 610, y = 154,
        text = "remaining",
        font = "Noto Sans",
        font_size = 12,
        colour = {{1, 0xFFFFFF, 1}}, 
        draw_me = true
    },

    -- Playback status indicator
    {
        type = "text",
        x = 184, y = 158,
        text = "status",
        font = "Symbola",
        font_size = 24,
        colour = {{1, 0xFFFFFF, 1}}, 
        draw_me = true
    }
}

-- === Convert hex to RGBA ===
local function hex_to_rgba(hex, alpha)
    return ((hex >> 16) & 0xFF) / 255, ((hex >> 8) & 0xFF) / 255, (hex & 0xFF) / 255, alpha
end

-- === Draw custom rounded rectangle with independent corners ===
local function draw_custom_rounded_rectangle(cr, x, y, w, h, r)
    local tl, tr, br, bl = unpack(r)

    cairo_new_path(cr)
    cairo_move_to(cr, x + tl, y)
    cairo_line_to(cr, x + w - tr, y)
    if tr > 0 then cairo_arc(cr, x + w - tr, y + tr, tr, -math.pi/2, 0) else cairo_line_to(cr, x + w, y) end
    cairo_line_to(cr, x + w, y + h - br)
    if br > 0 then cairo_arc(cr, x + w - br, y + h - br, br, 0, math.pi/2) else cairo_line_to(cr, x + w, y + h) end
    cairo_line_to(cr, x + bl, y + h)
    if bl > 0 then cairo_arc(cr, x + bl, y + h - bl, bl, math.pi/2, math.pi) else cairo_line_to(cr, x, y + h) end
    cairo_line_to(cr, x, y + tl)
    if tl > 0 then cairo_arc(cr, x + tl, y + tl, tl, math.pi, 3*math.pi/2) else cairo_line_to(cr, x, y) end
    cairo_close_path(cr)
end

-- === Draw text with shadow ===
local function draw_text(cr, x, y, text, font, font_size, color)
    if not text or text == "" then
        text = "Unknown"
    end
    cairo_select_font_face(cr, font, CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL)
    cairo_set_font_size(cr, font_size)
    -- Draw shadow
    cairo_set_source_rgba(cr, 0, 0, 0, 0.5)
    cairo_move_to(cr, x+1, y+1)
    cairo_show_text(cr, text)
    -- Draw text
    cairo_set_source_rgba(cr, hex_to_rgba(color[1][2], color[1][3]))
    cairo_move_to(cr, x, y)
    cairo_show_text(cr, text)
end

-- === Centering helper ===
local function get_centered_x(canvas_width, box_width)
    return (canvas_width - box_width) / 2
end

-- === Draw image with scaling ===
function conky_draw_image(path, x, y, w, h)
    if conky_window == nil then return end
    local cs = cairo_xlib_surface_create(conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    local cr = cairo_create(cs)

    -- Check if file exists and is not empty
    local file = io.open(path, "rb")
    if not file or file:read("*a"):len() == 0 then
        if file then file:close() end
        print("Error: Image file not found or empty: " .. path)
        cairo_destroy(cr)
        cairo_surface_destroy(cs)
        return
    end
    file:close()

    -- Load the image
    local image = cairo_image_surface_create_from_png(path)
    if image and cairo_surface_status(image) == 0 then
        local img_width = cairo_image_surface_get_width(image)
        local img_height = cairo_image_surface_get_height(image)
        if img_width > 0 and img_height > 0 then
            local scale_x = w / img_width
            local scale_y = h / img_height
            cairo_scale(cr, scale_x, scale_y)
            cairo_set_source_surface(cr, image, x / scale_x, y / scale_y)
            cairo_paint(cr)
        else
            print("Error: Invalid image dimensions: " .. path)
        end
        cairo_surface_destroy(image)
    else
        print("Error: Failed to load image: " .. path)
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end

-- === Main drawing function ===
function conky_draw_display()
    if conky_window == nil then
        print("Error: conky_window is nil")
        return
    end

    -- Check if Spotify is running
    if not is_spotify_running() then
        print("Spotify is not running")
        return
    end

    -- Execute cover script to update album art
    execute_cover_script()

    -- Fetch all metadata in one call
    local metadata = get_spotify_metadata()

    -- Fetch progress data
    local progress = get_progress_data()

    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    local canvas_width = conky_window.width

    for i, box in ipairs(boxes_settings) do
        if box.draw_me then
            local x, y, w, h = box.x, box.y, box.w or 0, box.h or 0
            if box.centre_x then x = get_centered_x(canvas_width, w) end

            if box.type == "background" then
                if i == 12 then -- Progress bar (index 12 in boxes_settings)
                    w = math.max(1, 430 * (progress.percent / 100)) -- Match border width (430px)
                end
                if box.linear_gradient and box.colours then
                    local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                    for _, color in ipairs(box.colours) do
                        cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                    end
                    cairo_set_source(cr, grad)
                    draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                    cairo_fill(cr)
                    cairo_pattern_destroy(grad)
                else
                    cairo_set_source_rgba(cr, hex_to_rgba(box.colour[1][2], box.colour[1][3]))
                    draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                    cairo_fill(cr)
                end

            elseif box.type == "layer2" then
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colours) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)
                draw_custom_rounded_rectangle(cr, x, y, w, h, box.corners)
                cairo_fill(cr)
                cairo_pattern_destroy(grad)

            elseif box.type == "border" then
                local grad = cairo_pattern_create_linear(unpack(box.linear_gradient))
                for _, color in ipairs(box.colour) do
                    cairo_pattern_add_color_stop_rgba(grad, color[1], hex_to_rgba(color[2], color[3]))
                end
                cairo_set_source(cr, grad)
                cairo_set_line_width(cr, box.border)
                draw_custom_rounded_rectangle(
                    cr,
                    x + box.border / 2,
                    y + box.border / 2,
                    w - box.border,
                    h - box.border,
                    {
                        math.max(0, box.corners[1] - box.border / 2),
                        math.max(0, box.corners[2] - box.border / 2),
                        math.max(0, box.corners[3] - box.border / 2),
                        math.max(0, box.corners[4] - box.border / 2)
                    }
                )
                cairo_stroke(cr)
                cairo_pattern_destroy(grad)

            elseif box.type == "image" then
                conky_draw_image(box.path, x, y, w, h)

            elseif box.type == "text" then
                local text = box.text
                if box.text == "title" then
                    text = metadata.title
                elseif box.text == "artist" then
                    text = metadata.artist
                elseif box.text == "album" then
                    text = metadata.album
                elseif box.text == "elapsed" then
                    text = progress.elapsed
                elseif box.text == "remaining" then
                    text = "-" .. progress.remaining
                elseif box.text == "status" then
                    text = metadata.status == "Playing" and "▶" or "⏸"
                end
                draw_text(cr, x, y, text, box.font, box.font_size, box.colour)
            end
        end
    end

    cairo_destroy(cr)
    cairo_surface_destroy(cs)
end