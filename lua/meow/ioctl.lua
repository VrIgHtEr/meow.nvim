local M = {}
local ffi = require 'ffi'
ffi.cdef [[
    struct winsize { unsigned short ws_row; unsigned short ws_col; unsigned short ws_xpixel; unsigned short ws_ypixel; };
    void * malloc(size_t);
    int ioctl(int , int, ... );
]]

local wsize = ffi.cast('struct winsize *', ffi.C.malloc(8))
function M.resolution()
    return ffi.C.ioctl(0, 21523, wsize) ~= 0 and { w = 0, h = 0, rows = 0, cols = 0 }
        or { h = wsize[0].ws_ypixel, w = wsize[0].ws_xpixel, rows = wsize[0].ws_row, cols = wsize[0].ws_col }
end
return M
