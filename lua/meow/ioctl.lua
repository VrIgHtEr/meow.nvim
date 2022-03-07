local M = {}

local ffi = require 'ffi'
ffi.cdef [[
    struct winsize {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
    };
    void * malloc(size_t);
    int ioctl(int , int, ... );
]]

local wsize = ffi.cast('struct winsize *', ffi.C.malloc(8))
function M.resolution()
    local ret = ffi.C.ioctl(
        0,
        21523, --[[TIOCGWINSZ]]
        wsize
    )
    if ret == 0 then
        return { h = wsize[0].ws_ypixel, w = wsize[0].ws_xpixel, rows = wsize[0].ws_row, cols = wsize[0].ws_col }
    end
end
return M
