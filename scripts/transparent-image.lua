--[[
2024 Koentje
Modified by @wim66 April 22 2025
usage: ${lua conky_image /path/to/picture 0 0 164 164}
]]

require 'cairo'
local status, cairo_xlib = pcall(require, 'cairo_xlib')
if not status then
    cairo_xlib = setmetatable({}, { __index = _G })
end
home_path = os.getenv('HOME')

function fDrawImage(cr, path, xx, yy, ww, hh)
    cairo_save(cr)
    local img = cairo_image_surface_create_from_png(path)
    local w_img, h_img = cairo_image_surface_get_width(img), cairo_image_surface_get_height(img)
    if w_img == 0 or h_img == 0 then
        print("Error: Invalid image dimensions for: ", path)
        cairo_surface_destroy(img)
        return
    end
    local scale_x = ww / w_img
    local scale_y = hh / h_img
    cairo_translate(cr, xx, yy)
    cairo_scale(cr, scale_x, scale_y)
    cairo_set_source_surface(cr, img, 0, 0)
    cairo_paint(cr)
    cairo_surface_destroy(img)
    collectgarbage()
    cairo_restore(cr)
end

function conky_image(img, xxx, yyy, www, hhh)
    if img == nil then
        print("Error: Image path is nil")
        return ''
    end
    if string.sub(img, 1, 1) == '~' then
        img = os.getenv('HOME') .. string.sub(img, 2)
    end
    if conky_window == nil then return '' end
    local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable, conky_window.visual, conky_window.width, conky_window.height)
    local cr = cairo_create(cs)
    local updates = conky_parse('${updates}')
    local update_num = tonumber(updates)

    xxx = tonumber(xxx) or 0
    yyy = tonumber(yyy) or 0
    www = tonumber(www) or 100
    hhh = tonumber(hhh) or 100

    if update_num > 4 then
        fDrawImage(cr, img, xxx, yyy, www, hhh)
    end

    cairo_surface_destroy(cs)
    cairo_destroy(cr)
    return ''
end