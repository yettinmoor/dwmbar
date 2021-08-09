#include <X11/Xlib.h>

void display(const char* s)
{
    Display* dpy = XOpenDisplay(NULL);
    if (!dpy) {
        return;
    }
    int    screen = DefaultScreen(dpy);
    Window root   = RootWindow(dpy, screen);
    XStoreName(dpy, root, s);
    XCloseDisplay(dpy);
}
