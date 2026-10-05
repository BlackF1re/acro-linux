/* Xorg-only compatibility for legacy msm_fb framebuffer_alloc(..., NULL).
 * The real framebuffer is platform-backed, but has no sysfs parent link.
 * Preserve all real readlink results and all unrelated paths/errors.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
ssize_t readlink(const char *path, char *buf, size_t size)
{
    static ssize_t (*real_readlink)(const char *, char *, size_t);
    if (!real_readlink) real_readlink = dlsym(RTLD_NEXT, "readlink");
    ssize_t n = real_readlink(path, buf, size);
    if (n < 0 && errno == ENOENT &&
        !strcmp(path, "/sys/class/graphics/fb0/device/subsystem")) {
        const char bus[] = "/sys/bus/platform";
        size_t len = sizeof(bus) - 1;
        if (len > size) len = size;
        memcpy(buf, bus, len);
        return (ssize_t)len;
    }
    return n;
}
