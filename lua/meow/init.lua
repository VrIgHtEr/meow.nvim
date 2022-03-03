local terminal = {}

local uv = vim.loop
local stdout = uv.new_tty(1, false)
terminal.stdout = stdout

local queue = require('toolshed.util.generic.queue').new()
local ansi = require 'meow.ansi'
local writing = false
local faulted, fault = false, nil
local transaction_count = 0
local cursor_saved = false

local function commit()
    local tbl, index = {}, 0
    while queue:size() > 0 do
        index = index + 1
        tbl[index] = queue:dequeue()
    end
    vim.defer_fn(function()
        local ret = uv.write(stdout, tbl)
        if not ret then
            writing = false
            faulted = true
            fault = ret
            error(ret)
        end
    end, 0)
end

local function write(data)
    if not faulted then
        if transaction_count > 0 or writing then
            queue:enqueue(data)
        else
            queue:enqueue(data)
            commit()
        end
    end
end

function terminal.last_error()
    return faulted, fault
end
function terminal.begin_transaction(dont_save_cursor)
    if transaction_count == 0 and not dont_save_cursor then
        cursor_saved = true
        write(ansi.save_cursor())
    end
    transaction_count = transaction_count + 1
end

function terminal.end_transaction()
    if transaction_count > 0 then
        transaction_count = transaction_count - 1
        if transaction_count == 0 then
            if queue:size() > 0 then
                commit()
            end
            if cursor_saved then
                cursor_saved = false
                write(ansi.restore_cursor())
            end
        end
    end
end

function terminal.write(...)
    for _, data in ipairs { ... } do
        local t = type(data)
        if t == 'string' then
            write(data)
        elseif t == 'table' then
            local amt = #data
            if amt > 0 then
                for _, x in ipairs(data) do
                    if type(x) ~= 'string' then
                        error 'Invalid data in terminal write'
                    end
                end
                write(table.concat(data))
            end
        elseif t == 'number' then
            write(tostring(data))
        else
            error 'Invalid data in terminal write'
        end
    end
end

function terminal.execute_at(row, col, func, ...)
    terminal.begin_transaction()
    write(ansi.cursor_position(row, col))
    local ret = { pcall(func, row, col, ...) }
    terminal.end_transaction()
    if not ret[1] then
        return nil, ret[2]
    end
    return unpack(ret, 1)
end

function terminal.size()
    return uv.tty_get_winsize(stdout)
end

return terminal
