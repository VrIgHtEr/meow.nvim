local image = {}
local util, meow = require 'toolshed.util', require 'meow'

local last_image_id = 0
local image_ids = {}

local format = { rgb = 24, argb = 32, png = 100 }

local defaults = {
    format = format.png,
    auto_reclaim = false,
    active = true,
}

local function validate_opts(self, opts)
    opts = opts == nil and {} or opts

    if type(opts) ~= 'table' then
        return util.error('TYPE', type(opts))
    end

    if opts.pos ~= nil and type(opts.pos) ~= 'table' then
        return util.error('pos', 'TYPE', type(opts.pos))
    end
    opts.pos = opts.pos and opts.pos or { x = 0, y = 0 }

    if type(opts.pos.x) ~= 'number' then
        return util.error('pos.x', 'TYPE', type(opts.pos.x))
    end

    if type(opts.pos.y) ~= 'number' then
        return util.error('pos.y', 'TYPE', type(opts.pos.y))
    end

    opts.crop = opts.crop == nil and {} or opts.crop
    if type(opts.crop) ~= 'table' then
        return util.error('crop', 'TYPE', type(opts.crop))
    end

    opts.crop.x = opts.crop.x == nil and 0 or opts.crop.x
    if type(opts.crop.x) ~= 'number' then
        return util.error('crop.x', 'TYPE', type(opts.crop.x))
    end

    opts.crop.y = opts.crop.y == nil and 0 or opts.crop.y
    if type(opts.crop.y) ~= 'number' then
        return util.error('crop.y', 'TYPE', type(opts.crop.y))
    end

    if opts.crop.w ~= nil and type(opts.crop.w) ~= 'number' then
        return util.error('crop.w', 'TYPE', type(opts.crop.w))
    end
    opts.crop.w = opts.crop.w == nil and self.size.x - opts.pos.x or opts.crop.w

    if opts.crop.h ~= nil and type(opts.crop.h) ~= 'number' then
        return util.error('crop.h', 'TYPE', type(opts.crop.h))
    end
    opts.crop.h = opts.crop.h == nil and self.size.y - opts.pos.y or opts.crop.h

    if opts.crop.x < 0 or opts.crop.x >= self.size.x then
        return util.error('crop.x', 'VALUE', opts.crop.x)
    end

    if opts.crop.y < 0 or opts.crop.y >= self.size.y then
        return util.error('crop.y', 'VALUE', opts.crop.y)
    end

    if opts.crop.w < 0 or self.size.x - opts.crop.x < opts.crop.w then
        return util.error('crop.w', 'VALUE', opts.crop.w)
    end

    if opts.crop.h < 0 or (self.size.y - opts.crop.y) < opts.crop.h then
        return util.error('crop.h', 'VALUE', opts.crop.h)
    end

    opts.anchor = opts.anchor == nil and 0 or opts.anchor
    if type(opts.anchor) ~= 'number' then
        return util.error('anchor', 'TYPE', type(opts.anchor))
    end
    if opts.anchor < 0 or opts.anchor >= 4 then
        return util.error('anchor', 'VALUE', opts.anchor)
    end
    opts.anchor = math.floor(opts.anchor)

    if opts.placement ~= nil then
        if type(opts.placement) ~= 'number' then
            return util.error('placement', 'TYPE', type(opts.placement))
        end
        if opts.placement < 1 then
            return util.error('placement', 'VALUE', opts.placement)
        end
        opts.placement = math.floor(opts.placement)
    end

    if opts.z ~= nil then
        if type(opts.z) ~= 'number' then
            return util.error('placement', 'TYPE', type(opts.z))
        end
        opts.z = math.floor(opts.z)
    end

    return opts
end

function image.new(params)
    params = params == nil and {} or params
    params = vim.tbl_deep_extend('force', defaults, params)
    if not params.src then
        error 'src not provided'
    end
    local id
    if #image_ids > 0 then
        id = table.remove(image_ids)
    else
        last_image_id = last_image_id + 1
        id = last_image_id
    end

    local ps = {}
    local p_ids = {}
    local last_p_id = 0
    local active = true
    local auto_reclaim = params.auto_reclaim

    local i = { src = params.src }

    function i.transmit()
        if active then
            local data = util.read_file(i.src)
            meow.send_cmd({ a = 't', t = 'd', f = 100, i = id, q = 2 }, data)
        end
    end

    function i.display(opts)
        if active then
            local cmd = { a = 'p', i = id, C = 1, q = 2 }
            do
                local e
                opts, e = validate_opts(i, opts)
                if not opts then
                    return nil, e
                end
            end
            if opts.crop.w == 0 or opts.crop.h == 0 then
                return true
            end

            local top = opts.anchor > 1 and (opts.pos.y - opts.crop.h + 1) or opts.pos.y
            local left = (opts.anchor == 1 or opts.anchor == 2) and (opts.pos.x - opts.crop.w + 1) or opts.pos.x
            local bottom, right = top + opts.crop.w, left + opts.crop.h

            if left < 0 then
                if -left >= opts.crop.w then
                    return true
                end
                opts.crop.x, opts.crop.w, left = opts.crop.x - left, opts.crop.w + left, 0
            elseif left >= meow.win_w or right <= 0 then
                return true
            end
            if top < 0 then
                if -top >= opts.crop.h then
                    return true
                end
                opts.crop.y, opts.crop.h, top = opts.crop.y - top, opts.crop.h + top, 0
            elseif top >= meow.win_h or bottom <= 0 then
                return true
            end

            if bottom > meow.win_h then
                opts.crop.h = opts.crop.h - (bottom - meow.win_h)
            end
            if right > meow.win_w then
                opts.crop.w = opts.crop.w - (right - meow.win_w)
            end

            local xcell, ycell = math.floor(left / meow.cell_w), math.floor(top / meow.cell_h)
            cmd.X, cmd.Y = left % meow.cell_w, top % meow.cell_h
            cmd.x, cmd.y, cmd.w, cmd.h = opts.crop.x, opts.crop.y, opts.crop.w, opts.crop.h
            cmd.p = opts.placement
            cmd.z = opts.z
            meow.execute_at(ycell + 1, xcell + 1, function()
                meow.send_cmd(cmd)
            end)
            return true
        end
    end
    function i.hide()
        if active then
            meow.send_cmd { a = 'd', d = 'i', i = id }
        end
    end

    function i.destroy()
        if active then
            i.hide()
            table.insert(image_ids, id)
            active = false
            i = nil
        end
    end

    function i.create_placement()
        if active then
            local p_active, hidden, p_id = true, true, nil
            if #p_ids > 0 then
                p_id = table.remove(p_ids)
            else
                last_p_id = last_p_id + 1
                p_id = last_p_id
            end
            local p = {}
            if not ps[p_id] then
                ps[p_id] = 1
            else
                ps[p_id] = ps[p_id] + 1
            end
            function p.display(opts)
                if p_active and p_active then
                    opts.placement = p_id
                    i.display(opts)
                    hidden = false
                end
            end
            function p.hide()
                if p_active and p_active then
                    if not hidden then
                        meow.send_cmd { a = 'd', d = 'i', i = id, p = p_id }
                        hidden = true
                    end
                end
            end
            function p.destroy()
                if p_active and p_active then
                    p.hide()
                    ps[p_id] = ps[p_id] - 1
                    if ps[p_id] == 0 then
                        ps[p_id] = nil
                        table.insert(p_ids, p_id)
                        if auto_reclaim and #p_ids == last_p_id then
                            i.destroy()
                        end
                    end
                    p_active = false
                end
            end
            return p
        end
    end
    return i
end

return image
