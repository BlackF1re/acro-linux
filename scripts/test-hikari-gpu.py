#!/usr/bin/env python3
"""Exercise one GLES2 context through Mesa's DRM/GBM backend."""

import ctypes
import os
import sys


EGL_NONE = 0x3038
EGL_OPENGL_ES_API = 0x30A0
EGL_RENDERABLE_TYPE = 0x3040
EGL_OPENGL_ES2_BIT = 0x0004
EGL_CONTEXT_CLIENT_VERSION = 0x3098
EGL_PLATFORM_GBM_KHR = 0x31D7
GL_RENDERER = 0x1F01
GL_VERSION = 0x1F02
GL_VENDOR = 0x1F00
GL_COLOR_ATTACHMENT0 = 0x8CE0
GL_COLOR_BUFFER_BIT = 0x00004000
GL_FRAMEBUFFER = 0x8D40
GL_FRAMEBUFFER_COMPLETE = 0x8CD5
GL_COMPILE_STATUS = 0x8B81
GL_LINK_STATUS = 0x8B82
GL_FLOAT = 0x1406
GL_FRAGMENT_SHADER = 0x8B30
GL_RGBA = 0x1908
GL_TEXTURE_2D = 0x0DE1
GL_TRIANGLES = 0x0004
GL_UNSIGNED_BYTE = 0x1401
GL_VERTEX_SHADER = 0x8B31


def stage(message):
    print(f"HIKARI_GPU_STAGE={message}", flush=True)


def fail(message, egl=None):
    if egl is not None:
        message += f" (EGL error 0x{egl.eglGetError():04x})"
    raise RuntimeError(message)


def main():
    stage("load-libraries")
    gbm = ctypes.CDLL("libgbm.so.1")
    egl = ctypes.CDLL("libEGL.so.1")
    gles = ctypes.CDLL("libGLESv2.so.2")

    gbm.gbm_create_device.argtypes = [ctypes.c_int]
    gbm.gbm_create_device.restype = ctypes.c_void_p
    gbm.gbm_device_destroy.argtypes = [ctypes.c_void_p]
    egl.eglGetProcAddress.argtypes = [ctypes.c_char_p]
    egl.eglGetProcAddress.restype = ctypes.c_void_p
    egl.eglInitialize.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
    egl.eglInitialize.restype = ctypes.c_uint
    egl.eglBindAPI.argtypes = [ctypes.c_uint]
    egl.eglBindAPI.restype = ctypes.c_uint
    egl.eglChooseConfig.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_void_p), ctypes.c_int, ctypes.POINTER(ctypes.c_int)]
    egl.eglChooseConfig.restype = ctypes.c_uint
    egl.eglCreateContext.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)]
    egl.eglCreateContext.restype = ctypes.c_void_p
    egl.eglMakeCurrent.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
    egl.eglMakeCurrent.restype = ctypes.c_uint
    egl.eglDestroyContext.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    egl.eglTerminate.argtypes = [ctypes.c_void_p]
    egl.eglGetError.restype = ctypes.c_uint
    gles.glGetString.argtypes = [ctypes.c_uint]
    gles.glGetString.restype = ctypes.c_char_p
    gles.glClearColor.argtypes = [ctypes.c_float] * 4
    gles.glClear.argtypes = [ctypes.c_uint]
    gles.glFinish.argtypes = []
    gles.glGenFramebuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
    gles.glBindFramebuffer.argtypes = [ctypes.c_uint, ctypes.c_uint]
    gles.glDeleteFramebuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
    gles.glGenTextures.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
    gles.glBindTexture.argtypes = [ctypes.c_uint, ctypes.c_uint]
    gles.glTexImage2D.argtypes = [
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_void_p,
    ]
    gles.glDeleteTextures.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
    gles.glFramebufferTexture2D.argtypes = [
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_int,
    ]
    gles.glCheckFramebufferStatus.argtypes = [ctypes.c_uint]
    gles.glCheckFramebufferStatus.restype = ctypes.c_uint
    gles.glReadPixels.argtypes = [
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_int,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_void_p,
    ]
    gles.glGetError.restype = ctypes.c_uint
    gles.glCreateShader.argtypes = [ctypes.c_uint]
    gles.glCreateShader.restype = ctypes.c_uint
    gles.glShaderSource.argtypes = [
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.POINTER(ctypes.c_char_p),
        ctypes.POINTER(ctypes.c_int),
    ]
    gles.glCompileShader.argtypes = [ctypes.c_uint]
    gles.glGetShaderiv.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)]
    gles.glCreateProgram.restype = ctypes.c_uint
    gles.glAttachShader.argtypes = [ctypes.c_uint, ctypes.c_uint]
    gles.glLinkProgram.argtypes = [ctypes.c_uint]
    gles.glGetProgramiv.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)]
    gles.glUseProgram.argtypes = [ctypes.c_uint]
    gles.glGetAttribLocation.argtypes = [ctypes.c_uint, ctypes.c_char_p]
    gles.glGetAttribLocation.restype = ctypes.c_int
    gles.glVertexAttribPointer.argtypes = [
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_uint,
        ctypes.c_uint,
        ctypes.c_int,
        ctypes.c_void_p,
    ]
    gles.glEnableVertexAttribArray.argtypes = [ctypes.c_uint]
    gles.glDrawArrays.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_int]
    gles.glViewport.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
    gles.glDeleteProgram.argtypes = [ctypes.c_uint]
    gles.glDeleteShader.argtypes = [ctypes.c_uint]

    get_platform_display_type = ctypes.CFUNCTYPE(
        ctypes.c_void_p, ctypes.c_uint, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)
    )
    stage("resolve-platform-display")
    address = egl.eglGetProcAddress(b"eglGetPlatformDisplayEXT")
    if not address:
        fail("eglGetPlatformDisplayEXT is unavailable")
    get_platform_display = get_platform_display_type(address)

    stage("open-render-node")
    fd = os.open("/dev/dri/renderD128", os.O_RDWR | os.O_CLOEXEC)
    stage("gbm-create-device")
    device = gbm.gbm_create_device(fd)
    if not device:
        fail("gbm_create_device failed")
    stage("egl-get-platform-display")
    display = get_platform_display(EGL_PLATFORM_GBM_KHR, device, None)
    if not display:
        fail("eglGetPlatformDisplayEXT failed", egl)

    major = ctypes.c_int()
    minor = ctypes.c_int()
    stage("egl-initialize")
    if not egl.eglInitialize(display, ctypes.byref(major), ctypes.byref(minor)):
        fail("eglInitialize failed", egl)
    print(f"HIKARI_GPU_EGL={major.value}.{minor.value}", flush=True)
    stage("egl-bind-api")
    if not egl.eglBindAPI(EGL_OPENGL_ES_API):
        fail("eglBindAPI failed", egl)

    attributes = (ctypes.c_int * 3)(
        EGL_RENDERABLE_TYPE,
        EGL_OPENGL_ES2_BIT,
        EGL_NONE,
    )
    config = ctypes.c_void_p()
    count = ctypes.c_int()
    stage("egl-choose-config")
    if not egl.eglChooseConfig(display, attributes, ctypes.byref(config), 1, ctypes.byref(count)) or not count.value:
        fail("no GLES2 EGL config", egl)
    context_attributes = (ctypes.c_int * 3)(EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE)
    stage("egl-create-context")
    context = egl.eglCreateContext(display, config, None, context_attributes)
    if not context:
        fail("eglCreateContext failed", egl)
    stage("egl-make-current")
    if not egl.eglMakeCurrent(display, None, None, context):
        fail("surfaceless eglMakeCurrent failed", egl)

    stage("gles-query")
    for name, selector in (("vendor", GL_VENDOR), ("renderer", GL_RENDERER), ("version", GL_VERSION)):
        value = gles.glGetString(selector)
        print(f"{name}: {value.decode() if value else '<null>'}")
    stage("gles-create-framebuffer")
    texture = ctypes.c_uint()
    framebuffer = ctypes.c_uint()
    gles.glGenTextures(1, ctypes.byref(texture))
    gles.glBindTexture(GL_TEXTURE_2D, texture)
    gles.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 4, 4, 0, GL_RGBA, GL_UNSIGNED_BYTE, None)
    gles.glGenFramebuffers(1, ctypes.byref(framebuffer))
    gles.glBindFramebuffer(GL_FRAMEBUFFER, framebuffer)
    gles.glFramebufferTexture2D(
        GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0
    )
    status = gles.glCheckFramebufferStatus(GL_FRAMEBUFFER)
    if status != GL_FRAMEBUFFER_COMPLETE:
        fail(f"incomplete GLES2 framebuffer 0x{status:04x}")

    stage("gles-compile-shaders")
    shaders = []
    for shader_type, source in (
        (GL_VERTEX_SHADER, b"attribute vec2 position; void main() { gl_Position = vec4(position, 0.0, 1.0); }"),
        (GL_FRAGMENT_SHADER, b"precision mediump float; void main() { gl_FragColor = vec4(0.2, 0.4, 0.6, 1.0); }"),
    ):
        shader = gles.glCreateShader(shader_type)
        sources = (ctypes.c_char_p * 1)(source)
        gles.glShaderSource(shader, 1, sources, None)
        gles.glCompileShader(shader)
        compiled = ctypes.c_int()
        gles.glGetShaderiv(shader, GL_COMPILE_STATUS, ctypes.byref(compiled))
        if not compiled.value:
            fail(f"shader compilation failed for type 0x{shader_type:04x}")
        shaders.append(shader)
    program = gles.glCreateProgram()
    for shader in shaders:
        gles.glAttachShader(program, shader)
    gles.glLinkProgram(program)
    linked = ctypes.c_int()
    gles.glGetProgramiv(program, GL_LINK_STATUS, ctypes.byref(linked))
    if not linked.value:
        fail("GLES2 program link failed")
    gles.glUseProgram(program)
    position = gles.glGetAttribLocation(program, b"position")
    if position < 0:
        fail("GLES2 position attribute is unavailable")
    vertices = (ctypes.c_float * 6)(-1.0, -1.0, 3.0, -1.0, -1.0, 3.0)
    gles.glVertexAttribPointer(position, 2, GL_FLOAT, 0, 0, vertices)
    gles.glEnableVertexAttribArray(position)

    stage("gles-draw-readback")
    gles.glViewport(0, 0, 4, 4)
    gles.glClearColor(0.0, 0.0, 0.0, 1.0)
    gles.glClear(GL_COLOR_BUFFER_BIT)
    gles.glDrawArrays(GL_TRIANGLES, 0, 3)
    gles.glFinish()
    pixel = (ctypes.c_ubyte * 4)()
    gles.glReadPixels(0, 0, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel)
    error = gles.glGetError()
    if error:
        fail(f"GLES2 rendering failed with GL error 0x{error:04x}")
    expected = (51, 102, 153, 255)
    actual = tuple(pixel)
    if any(abs(value - reference) > 1 for value, reference in zip(actual, expected)):
        fail(f"unexpected RGBA readback {actual}, expected approximately {expected}")
    print(f"HIKARI_GPU_RGBA={actual}")
    print("HIKARI_GPU_GLES2=PASS")

    gles.glDeleteProgram(program)
    for shader in shaders:
        gles.glDeleteShader(shader)
    gles.glDeleteFramebuffers(1, ctypes.byref(framebuffer))
    gles.glDeleteTextures(1, ctypes.byref(texture))

    egl.eglMakeCurrent(display, None, None, None)
    egl.eglDestroyContext(display, context)
    egl.eglTerminate(display)
    gbm.gbm_device_destroy(device)
    os.close(fd)


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"HIKARI_GPU_GLES2=FAIL {error}", file=sys.stderr)
        sys.exit(1)
