local meow = setmetatable({}, { __index = require 'meow.terminal', __metatable = function() end })
local string, util = require 'toolshed.util.string', require 'toolshed.util'

meow.constants = {
    control_keys = {
        format = 'f',
        image_width = 's',
        image_height = 'v',
        compression = 'o',
        transmission_medium = 't',
        continuation = 'm',
        read_offset = 'O',
        read_length = 'S',
        id = 'i',
        placement_id = 'p',
        action = 'a',
        x_offset = 'X',
        y_offset = 'Y',
        clip_x = 'x',
        clip_y = 'y',
        clip_w = 'w',
        clip_h = 'h',
        display_rows = 'r',
        display_cols = 'c',
        z_index = 'z',
        quiet = 'q',
        cursor_mode = 'C',
        delete = 'd',
    },
    format = { rgb = 24, rgba = 32, png = 100 },
    compression = { zlib_deflate = 'z' },
    transmission_medium = { direct = 'd', file = 'f', temp_file = 't', shared_memory = 's' },
    continuation = { in_progress = '1', finished = '0' },
    action = { query = 'q', delete = 'd', transmit = 't', transmit_and_display = 'T', put = 'p' },
    quiet = { ok = '1', errors = '2' },
}

function meow.supported()
    local term = vim.fn.getenv 'TERM'
    return term == 'xterm-kitty' or term == 'wezterm'
end

local valid_keys = {}
for _, v in pairs(meow.constants.control_keys) do
    valid_keys[v] = true
end

local function chunks(data, size)
    size = math.floor(math.abs(size or 4096))
    assert(size > 0, 'size cannot be negative')
    local len = data:len()
    local blocks = math.floor((len + size - 1) / size)
    local ret = {}
    for i = 1, blocks do
        local start = size * (i - 1)
        ret[i] = data:sub(start + 1, math.min(len, start + size))
    end
    return ret
end

local function build_cmd(cmd)
    local ret = {}
    for k, v in pairs(cmd) do
        if valid_keys[k] then
            table.insert(ret, k .. '=' .. tostring(v))
        end
    end
    return table.concat(ret, ',')
end

function meow.validate(opts)
    opts = opts == nil and {} or opts
    if type(opts) ~= 'table' then
        return util.error('TYPE', type(opts))
    end
    for k, v in pairs(opts) do
        if not valid_keys[k] then
            return util.error('KEY', k)
        end
        local t = type(v)
        if t ~= 'number' then
            return util.error(k, 'TYPE', t)
        end
    end
    return opts
end

function meow.send_cmd(cmd, data)
    cmd = build_cmd(cmd)
    meow.begin_transaction(true)
    cmd, data = cmd or '', chunks(string.base64_encode(data or ''))
    local num_chunks = #data
    if cmd == '' or num_chunks <= 1 then
        local esc = { '\x1b_G', cmd, ';' }
        if num_chunks == 1 then
            table.insert(esc, data[1])
        end
        table.insert(esc, '\x1b\\')
        meow.write(table.concat(esc))
    else
        for i = 1, num_chunks do
            local esc = { '\x1b_G' }
            if i == 1 then
                table.insert(esc, cmd)
                if cmd ~= '' then
                    table.insert(esc, ',')
                end
            end
            table.insert(esc, 'm=')
            table.insert(esc, i == num_chunks and '0;' or '1;')
            table.insert(esc, data[i])
            table.insert(esc, '\x1b\\')
            meow.write(table.concat(esc))
        end
    end
    meow.end_transaction()
end

local discovering = false
function meow.is_initialized()
    return not discovering
end
local discovery_callbacks = {}

function meow.when_initialized(cb)
    if meow.supported() then
        cb = type(cb) == 'function' and cb or nil
        if discovering then
            if cb then
                table.insert(discovery_callbacks, cb)
            end
        else
            discovering = true
            if cb then
                table.insert(discovery_callbacks, cb)
            end
            meow.stdin:read_start(function(_, data)
                if data and discovering then
                    local len = data:len()
                    if len >= 8 and data:sub(len, len) == 't' and data:sub(1, 4) == '\x1b[4;' then
                        data = data:sub(5, len - 1)
                        len = len - 5
                        local idx = data:find ';'
                        if idx then
                            meow.win_h, meow.win_w = tonumber(data:sub(1, idx - 1)), tonumber(data:sub(idx + 1))
                            if meow.win_h and meow.win_w then
                                meow.cell_w, meow.cell_h = math.floor(meow.win_w / meow.cols), math.floor(meow.win_h / meow.rows)
                                meow.win_h, meow.win_w = meow.cell_h * meow.rows, meow.cell_w * meow.cols
                                meow.stdin:read_stop()
                                discovering = false
                                local callbacks = discovery_callbacks
                                discovery_callbacks = {}
                                vim.schedule(function()
                                    for _, x in ipairs(callbacks) do
                                        pcall(x)
                                    end
                                end)
                            end
                        end
                    end
                end
            end)
            local function send_command()
                if discovering then
                    meow.write '\x1b[14t'
                    vim.defer_fn(send_command, 40)
                end
            end
            send_command()
        end
    end
end
meow.add_resize_event_handler(meow.when_initialized)
meow.when_initialized()

return meow
