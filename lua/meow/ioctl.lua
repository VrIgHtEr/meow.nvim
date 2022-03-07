local M = {}

local ffi = require 'ffi'
-- declare c things we may use
ffi.cdef [[
    // structures
    // fake sigset 128 bytes long
    typedef void sigset_t;
    struct signalfd_siginfo {
        uint32_t ssi_signo;
        int32_t ssi_errno;
        int32_t ssi_code;
        uint32_t ssi_pid;
        uint32_t ssi_uid;
        int32_t ssi_fd;
        uint32_t ssi_tid;
        uint32_t ssi_band;
        uint32_t ssi_overrun;
        uint32_t ssi_trapno;
        int32_t ssi_status;
        int32_t ssi_int;
        uint64_t ssi_ptr;
        uint64_t ssi_utime;
        uint64_t ssi_stime;
        uint64_t ssi_addr;
        uint16_t ssi_addr_lsb;
        uint16_t __pad2;
        int32_t ssi_syscall;
        uint64_t ssi_call_addr;
        uint32_t ssi_arch;
        uint8_t __pad[28];
    };
    // epoll_event: size is 12, things is {u32, u64}
    typedef uint32_t epoll_event_t;
    struct winsize {
        unsigned short ws_row;
        unsigned short ws_col;
        unsigned short ws_xpixel;
        unsigned short ws_ypixel;
    };
    // dirent.h
    struct dirent {
        uint64_t          d_ino;    /* Inode number */
        uint64_t          ___padding;
        unsigned short d_reclen;    /* Length of this record */
        unsigned char  d_type;      /* Type of file; not supported
                                      by all filesystem types */
        char           d_name[256]; /* Null-terminated filename */
    };
    // fake php things, needs phpstub
    struct fakeme {
        unsigned short size;
        unsigned int api;
        unsigned char debug;
        unsigned char zts;
        void *_ini_entry;
	    void *_deps;
	    const char *name;
    };


    // epoll functions 
    int epoll_create(int size);
    int epoll_create1(int flags);
    int epoll_wait(int epfd, epoll_event_t *events, int maxevents, int timeout);
    //int epoll_pwait(int epfd, epoll_event_t *events, int maxevents, int timeout, const sigset_t *sigmask);
    int epoll_ctl(int epfd, int op, int fd, epoll_event_t *event);
    
    // sigfd functions
    int sigemptyset(sigset_t *set);
    int sigaddset(sigset_t *set, int signum);
    int sigprocmask(int how, const sigset_t *restrict set, sigset_t *restrict oset);
    int signalfd(int fd, const sigset_t *mask, int flags);

    // curses function
    void * initscr(void);
    int raw(void);
    int cbreak(void);
    int nocbreak(void);
    int noecho(void);
    int scrollok(void*,bool);
    int wscrl(void*,int);
    int beep(void);
    int flash(void);
    int clear(void);
    int wclear(void*);
    int refresh(void);
    int wrefresh(void*);
    int endwin(void);
    int start_color(void);
    int init_pair(short pair, short f, short b);
    int attron(int attrs);
    int attroff(int attrs);
    int wattron(void*, int attrs);
    int wattroff(void*,int attrs);
    int attr_on(int attrs);
    int attr_off(int attrs);
    int wattr_on(void*, int attrs);
    int wattr_off(void*,int attrs);
    int wresize(void *w, int y, int x);
    int resizeterm(int lines, int columns);
    int resize_term(int lines, int columns);
    int isendwin(void);
    int getch(void);
    int keypad(void*, bool);
    int nodelay(void *win, bool bf);
    int timeout(int);
    int wtimeout(void*,int);
    int getmaxx(void *win);
    int getmaxy(void *win);
    typedef uint16_t chtype;
    int border(chtype ls, chtype rs, chtype ts, chtype bs, chtype tl, chtype tr, chtype bl, chtype br);
    int wborder(void *win, chtype ls, chtype rs, chtype ts, chtype bs, chtype tl, chtype tr, chtype bl, chtype br);
    void *newwin(int nlines, int ncols, int begin_y, int begin_x);
    void *derwin(void*, int nlines, int ncols, int begin_y, int begin_x);
    int delwin(void *);
    int waddnwstr(void *win, const wchar_t *wstr, int n);
    int waddnstr(void *win, const char *str, int n);
    int waddstr(void *win, const char *str);
    int mvwaddnwstr(void *win, int y, int x, const wchar_t *str, int n);
    int mvwaddwstr(void *win, int y, int x, const wchar_t *str);
    int mvwaddnstr(void *win, int y, int x, const char *str, int n);
    char *keyname(int c);
    int mvwin(void *win, int y, int x);
    int wmove(void *win, int y, int x);
    int curs_set(int visibility);
    int mvwhline(void *, int y, int x, chtype ch, int n);
    int ungetch( int );
    int get_wch(int *);
    int touchwin(void*);

    // errno.h things
    void perror(const char *s);

    // io things
    int __xstat(int, const char *, void *);
    size_t read(int, void *, size_t);
    size_t write(int, void *, size_t);
    int open(const char*, int, uint32_t);
    int chmod(const char *pathname, uint32_t mode);
    int access(const char *path, int amode);

    // stdio.h things
    void *fdopen(int fd, const char *mode);
    int printf(const char * fmt, ...);
    int dprintf(int fd, const char * fmt, ...);
    int fwprintf(void *stream, const wchar_t *format, ...);
    
    // stdlib/strings
    void * malloc(size_t);
    void free(void *);
    void * memcpy(void *, void *, size_t);
    char *getenv(const char *name);
    int sleep(int);

    // dlfcn.h things
    void *dlopen(const char *filename, int flags);
    void *dlsym(void *, const char *);
    uint64_t dlerror(void);

    //
    int ioctl(int , int, ... );

    // locale.h
    char *setlocale(int category, const char *locale);

    // dirent.h
    int scandir(const char *dirp, struct dirent ***namelist,
              int (*filter)(const struct dirent *),
              int (*compar)(const struct dirent **, const struct dirent **));
    int alphasort(const struct dirent **a, const struct dirent **b);

    // mydiag: a simple diagnostic library by myself, only for ffi debug
    int setout(int);
    void inspect(const char*,size_t);
    void diagdiag();
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
print(vim.inspect(M.resolution()))
return M
