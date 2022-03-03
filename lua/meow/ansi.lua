local ansi = {}
local esc = '\x1b['
function ansi.save_cursor()
    return esc .. 's'
end
function ansi.restore_cursor()
    return esc .. 'u'
end
function ansi.cursor_position(row, col)
    return esc .. tostring(math.floor(math.abs(row))) .. ';' .. tostring(math.floor(math.abs(col))) .. 'H'
end
return ansi
