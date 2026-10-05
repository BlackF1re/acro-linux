#!/usr/bin/env python3
"""Deterministic CPU-texture GLES2 probe for Qualcomm Adreno 220.

This is a diagnostic test, not a compositor workaround. It renders a
deterministic RGBA pattern into an FBO and validates every output byte.
"""

import argparse
import ctypes
import hashlib
import os
import subprocess
import sys
import time
from pathlib import Path


EGL_NONE = 0x3038
EGL_OPENGL_ES_API = 0x30A0
EGL_RENDERABLE_TYPE = 0x3040
EGL_OPENGL_ES2_BIT = 0x0004
EGL_CONTEXT_CLIENT_VERSION = 0x3098
EGL_PLATFORM_GBM_KHR = 0x31D7

GL_VENDOR = 0x1F00
GL_RENDERER = 0x1F01
GL_VERSION = 0x1F02
GL_TEXTURE_2D = 0x0DE1
GL_ARRAY_BUFFER = 0x8892
GL_ELEMENT_ARRAY_BUFFER = 0x8893
GL_STATIC_DRAW = 0x88E4
GL_TEXTURE_MIN_FILTER = 0x2801
GL_TEXTURE_MAG_FILTER = 0x2800
GL_TEXTURE_WRAP_S = 0x2802
GL_TEXTURE_WRAP_T = 0x2803
GL_NEAREST = 0x2600
GL_CLAMP_TO_EDGE = 0x812F
GL_RGBA = 0x1908
GL_UNSIGNED_BYTE = 0x1401
GL_FRAMEBUFFER = 0x8D40
GL_COLOR_ATTACHMENT0 = 0x8CE0
GL_FRAMEBUFFER_COMPLETE = 0x8CD5
GL_COLOR_BUFFER_BIT = 0x00004000
GL_VERTEX_SHADER = 0x8B31
GL_FRAGMENT_SHADER = 0x8B30
GL_COMPILE_STATUS = 0x8B81
GL_LINK_STATUS = 0x8B82
GL_FLOAT = 0x1406
GL_TRIANGLE_STRIP = 0x0005
GL_TRIANGLES = 0x0004
GL_UNSIGNED_SHORT = 0x1403

WIDTH = 4
HEIGHT = 4
SENTINEL_RGBA = (9, 18, 27, 255)
SOLID_RGBA = (193, 71, 149, 255)
VERTEX_SOURCE = b"""
attribute vec2 a_position;
attribute vec2 a_texcoord;
varying vec2 v_texcoord;
void main() {
    gl_Position = vec4(a_position, 0.0, 1.0);
    v_texcoord = a_texcoord;
}
"""
TEXTURE_FRAGMENT_SOURCE = b"""
precision highp float;
uniform sampler2D u_texture;
varying vec2 v_texcoord;
void main() {
    gl_FragColor = texture2D(u_texture, v_texcoord);
}
"""
SOLID_FRAGMENT_SOURCE = b"""
precision mediump float;
void main() {
    gl_FragColor = vec4(0.75686276, 0.27843139, 0.58431375, 1.0);
}
"""
VARYING_FRAGMENT_SOURCE = b"""
precision highp float;
varying vec2 v_texcoord;
void main() {
    gl_FragColor = vec4(v_texcoord, 0.0, 1.0);
}
"""
CONSTANT_VARYING_FRAGMENT_SOURCE = VARYING_FRAGMENT_SOURCE
CONSTANT_TEXTURE_FRAGMENT_SOURCE = b"""
precision highp float;
uniform sampler2D u_texture;
void main() {
    gl_FragColor = texture2D(u_texture, vec2(0.5, 0.5));
}
"""
SHADER_MODE = "texture-varying"
TOPOLOGY = "strip"
PATTERN_STYLE = "coordinate"


def check(ok, what, egl=None):
    if ok:
        return
    suffix = f" (EGL error 0x{egl.eglGetError():04x})" if egl else ""
    raise RuntimeError(what + suffix)


def source_pattern():
    # The mixed pattern is the original intermittent trigger; coordinate RGB
    # instead makes texture-sample provenance easy to decode.
    data = bytearray()
    for y in range(HEIGHT):
        row = bytearray()
        for x in range(WIDTH):
            if PATTERN_STYLE == "mixed":
                row.extend(((17 + 41 * x) & 255, (23 + 43 * y) & 255,
                            (31 + 23 * x + 46 * y) & 255, 255))
            else:
                row.extend((x & 255, y & 255, (x >> 8) | ((y >> 8) << 3), 255))
        data.extend(row)
    return bytes(data)


EXPECTED = source_pattern()


def alternate_pattern():
    data = bytearray()
    for y in range(HEIGHT):
        row = bytearray()
        for x in range(WIDTH):
            if PATTERN_STYLE == "mixed":
                row.extend(((17 + 41 * x) & 255, (23 + 43 * y) & 255,
                            (31 + 23 * x + 46 * y) & 255, 127))
            else:
                row.extend((x & 255, y & 255, (x >> 8) | ((y >> 8) << 3), 127))
        data.extend(row)
    return bytes(data)


EXPECTED_B = alternate_pattern()


class EGLDevice:
    def __init__(self):
        self.gbm = ctypes.CDLL("libgbm.so.1")
        self.egl = ctypes.CDLL("libEGL.so.1")
        self.gl = ctypes.CDLL("libGLESv2.so.2")
        self._declare_egl()
        self._declare_gl()

        self.gbm.gbm_create_device.argtypes = [ctypes.c_int]
        self.gbm.gbm_create_device.restype = ctypes.c_void_p
        self.gbm.gbm_device_destroy.argtypes = [ctypes.c_void_p]

        proc = self.egl.eglGetProcAddress(b"eglGetPlatformDisplayEXT")
        check(bool(proc), "eglGetPlatformDisplayEXT unavailable", self.egl)
        get_platform_display = ctypes.CFUNCTYPE(
            ctypes.c_void_p,
            ctypes.c_uint,
            ctypes.c_void_p,
            ctypes.POINTER(ctypes.c_int),
        )(proc)

        self.fd = os.open("/dev/dri/renderD128", os.O_RDWR | os.O_CLOEXEC)
        self.gbm_device = self.gbm.gbm_create_device(self.fd)
        check(bool(self.gbm_device), "gbm_create_device failed")
        self.display = get_platform_display(EGL_PLATFORM_GBM_KHR, self.gbm_device, None)
        check(bool(self.display), "eglGetPlatformDisplayEXT failed", self.egl)
        major, minor = ctypes.c_int(), ctypes.c_int()
        check(self.egl.eglInitialize(self.display, ctypes.byref(major), ctypes.byref(minor)),
              "eglInitialize failed", self.egl)
        check(self.egl.eglBindAPI(EGL_OPENGL_ES_API), "eglBindAPI failed", self.egl)
        config_attrs = (ctypes.c_int * 3)(EGL_RENDERABLE_TYPE, EGL_OPENGL_ES2_BIT, EGL_NONE)
        self.config = ctypes.c_void_p()
        count = ctypes.c_int()
        check(self.egl.eglChooseConfig(self.display, config_attrs,
                                       ctypes.byref(self.config), 1, ctypes.byref(count))
              and count.value, "no GLES2 EGL config", self.egl)

    def _declare_egl(self):
        e = self.egl
        e.eglGetProcAddress.argtypes = [ctypes.c_char_p]
        e.eglGetProcAddress.restype = ctypes.c_void_p
        e.eglInitialize.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int),
                                    ctypes.POINTER(ctypes.c_int)]
        e.eglInitialize.restype = ctypes.c_uint
        e.eglBindAPI.argtypes = [ctypes.c_uint]
        e.eglBindAPI.restype = ctypes.c_uint
        e.eglChooseConfig.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int),
                                      ctypes.POINTER(ctypes.c_void_p), ctypes.c_int,
                                      ctypes.POINTER(ctypes.c_int)]
        e.eglChooseConfig.restype = ctypes.c_uint
        e.eglCreateContext.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                                       ctypes.POINTER(ctypes.c_int)]
        e.eglCreateContext.restype = ctypes.c_void_p
        e.eglMakeCurrent.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p,
                                     ctypes.c_void_p]
        e.eglMakeCurrent.restype = ctypes.c_uint
        e.eglDestroyContext.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
        e.eglDestroyContext.restype = ctypes.c_uint
        e.eglTerminate.argtypes = [ctypes.c_void_p]
        e.eglTerminate.restype = ctypes.c_uint
        e.eglGetError.restype = ctypes.c_uint

    def _declare_gl(self):
        g = self.gl
        g.glGetString.argtypes = [ctypes.c_uint]
        g.glGetString.restype = ctypes.c_char_p
        g.glCreateShader.argtypes = [ctypes.c_uint]
        g.glCreateShader.restype = ctypes.c_uint
        g.glShaderSource.argtypes = [ctypes.c_uint, ctypes.c_int,
                                     ctypes.POINTER(ctypes.c_char_p),
                                     ctypes.POINTER(ctypes.c_int)]
        g.glCompileShader.argtypes = [ctypes.c_uint]
        g.glGetShaderiv.argtypes = [ctypes.c_uint, ctypes.c_uint,
                                    ctypes.POINTER(ctypes.c_int)]
        g.glGetShaderInfoLog.argtypes = [ctypes.c_uint, ctypes.c_int,
                                         ctypes.POINTER(ctypes.c_int), ctypes.c_char_p]
        g.glCreateProgram.restype = ctypes.c_uint
        g.glAttachShader.argtypes = [ctypes.c_uint, ctypes.c_uint]
        g.glBindAttribLocation.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_char_p]
        g.glLinkProgram.argtypes = [ctypes.c_uint]
        g.glGetProgramiv.argtypes = [ctypes.c_uint, ctypes.c_uint,
                                     ctypes.POINTER(ctypes.c_int)]
        g.glGetProgramInfoLog.argtypes = [ctypes.c_uint, ctypes.c_int,
                                          ctypes.POINTER(ctypes.c_int), ctypes.c_char_p]
        g.glUseProgram.argtypes = [ctypes.c_uint]
        g.glGetAttribLocation.argtypes = [ctypes.c_uint, ctypes.c_char_p]
        g.glGetAttribLocation.restype = ctypes.c_int
        g.glGetUniformLocation.argtypes = [ctypes.c_uint, ctypes.c_char_p]
        g.glGetUniformLocation.restype = ctypes.c_int
        g.glUniform1i.argtypes = [ctypes.c_int, ctypes.c_int]
        g.glVertexAttribPointer.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_uint,
                                            ctypes.c_ubyte, ctypes.c_int, ctypes.c_void_p]
        g.glEnableVertexAttribArray.argtypes = [ctypes.c_uint]
        g.glViewport.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        g.glGenTextures.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glDeleteTextures.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glBindTexture.argtypes = [ctypes.c_uint, ctypes.c_uint]
        g.glActiveTexture.argtypes = [ctypes.c_uint]
        g.glTexParameteri.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_int]
        g.glTexImage2D.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p]
        g.glTexSubImage2D.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_int,
                                      ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                      ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p]
        g.glGenFramebuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glDeleteFramebuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glBindFramebuffer.argtypes = [ctypes.c_uint, ctypes.c_uint]
        g.glFramebufferTexture2D.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.c_uint,
                                             ctypes.c_uint, ctypes.c_int]
        g.glCheckFramebufferStatus.argtypes = [ctypes.c_uint]
        g.glCheckFramebufferStatus.restype = ctypes.c_uint
        g.glClearColor.argtypes = [ctypes.c_float] * 4
        g.glClear.argtypes = [ctypes.c_uint]
        g.glDrawArrays.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_int]
        g.glDrawElements.argtypes = [ctypes.c_uint, ctypes.c_int, ctypes.c_uint,
                                     ctypes.c_void_p]
        g.glFinish.argtypes = []
        g.glReadPixels.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                                   ctypes.c_uint, ctypes.c_uint, ctypes.c_void_p]
        g.glGetError.restype = ctypes.c_uint
        g.glDeleteProgram.argtypes = [ctypes.c_uint]
        g.glDeleteShader.argtypes = [ctypes.c_uint]
        g.glGenBuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glDeleteBuffers.argtypes = [ctypes.c_int, ctypes.POINTER(ctypes.c_uint)]
        g.glBindBuffer.argtypes = [ctypes.c_uint, ctypes.c_uint]
        g.glBufferData.argtypes = [ctypes.c_uint, ctypes.c_ssize_t,
                                   ctypes.c_void_p, ctypes.c_uint]
        g.glBufferSubData.argtypes = [ctypes.c_uint, ctypes.c_ssize_t,
                                      ctypes.c_ssize_t, ctypes.c_void_p]

    def create_context(self):
        attrs = (ctypes.c_int * 3)(EGL_CONTEXT_CLIENT_VERSION, 2, EGL_NONE)
        context = self.egl.eglCreateContext(self.display, self.config, None, attrs)
        check(bool(context), "eglCreateContext failed", self.egl)
        self.make_current(context)
        return context

    def make_current(self, context):
        check(self.egl.eglMakeCurrent(self.display, None, None, context),
              "surfaceless eglMakeCurrent failed", self.egl)

    def destroy_context(self, context):
        self.egl.eglMakeCurrent(self.display, None, None, None)
        self.egl.eglDestroyContext(self.display, context)

    def close(self):
        self.egl.eglTerminate(self.display)
        self.gbm.gbm_device_destroy(self.gbm_device)
        os.close(self.fd)


class GLResources:
    def __init__(self, device, source_pixels=EXPECTED):
        self.d = device
        self.g = device.gl
        self.context = device.create_context()
        self.source = 0
        self.destination = 0
        self.framebuffer = 0
        self.texture_program = 0
        self.solid_program = 0
        self.client_arrays = []
        self.vertex_buffer = 0
        self.transition_vertex_buffer = 0
        self.index_buffer = 0
        self.positions, self.texcoords, self.vertex_count, self.draw_mode = self._vertex_data()
        self.indexed = TOPOLOGY == "indexed-quad"
        self.extra_textures = []
        self.extra_framebuffers = []
        self.source_pixels = source_pixels
        if getattr(device, "static_vbo", False):
            packed = (ctypes.c_float * (len(self.positions) + len(self.texcoords)))(
                *(self.positions + self.texcoords))
            handle = ctypes.c_uint()
            self.g.glGenBuffers(1, ctypes.byref(handle))
            self.vertex_buffer = handle.value
            self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
            self.g.glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(packed),
                                ctypes.cast(packed, ctypes.c_void_p), GL_STATIC_DRAW)
            if self.indexed:
                indices = (ctypes.c_ushort * 6)(0, 1, 2, 2, 1, 3)
                index = ctypes.c_uint()
                self.g.glGenBuffers(1, ctypes.byref(index))
                self.index_buffer = index.value
                self.g.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.index_buffer)
                self.g.glBufferData(GL_ELEMENT_ARRAY_BUFFER, ctypes.sizeof(indices),
                                    ctypes.cast(indices, ctypes.c_void_p), GL_STATIC_DRAW)
        self._create_programs()
        self.create_source()
        self.create_destination()
        self.g.glViewport(0, 0, WIDTH, HEIGHT)
        renderer = self.g.glGetString(GL_RENDERER)
        version = self.g.glGetString(GL_VERSION)
        print("HIKARI_A220_RENDERER=" + (renderer.decode() if renderer else "<null>"), flush=True)
        print("HIKARI_A220_GL_VERSION=" + (version.decode() if version else "<null>"), flush=True)

    def _shader(self, kind, source):
        shader = self.g.glCreateShader(kind)
        src = (ctypes.c_char_p * 1)(source)
        self.g.glShaderSource(shader, 1, src, None)
        self.g.glCompileShader(shader)
        compiled = ctypes.c_int()
        self.g.glGetShaderiv(shader, GL_COMPILE_STATUS, ctypes.byref(compiled))
        if not compiled.value:
            log = ctypes.create_string_buffer(2048)
            length = ctypes.c_int()
            self.g.glGetShaderInfoLog(shader, len(log), ctypes.byref(length), log)
            raise RuntimeError("shader compile failed: " + log.value.decode(errors="replace"))
        return shader

    def _program(self, fragment_source, textured):
        vertex = self._shader(GL_VERTEX_SHADER, VERTEX_SOURCE)
        fragment = self._shader(GL_FRAGMENT_SHADER, fragment_source)
        program = self.g.glCreateProgram()
        self.g.glAttachShader(program, vertex)
        self.g.glAttachShader(program, fragment)
        self.g.glBindAttribLocation(program, 0, b"a_position")
        if textured:
            self.g.glBindAttribLocation(program, 1, b"a_texcoord")
        self.g.glLinkProgram(program)
        linked = ctypes.c_int()
        self.g.glGetProgramiv(program, GL_LINK_STATUS, ctypes.byref(linked))
        if not linked.value:
            log = ctypes.create_string_buffer(2048)
            length = ctypes.c_int()
            self.g.glGetProgramInfoLog(program, len(log), ctypes.byref(length), log)
            raise RuntimeError("program link failed: " + log.value.decode(errors="replace"))
        self.g.glDeleteShader(vertex)
        self.g.glDeleteShader(fragment)
        self.g.glUseProgram(program)

        position = self.g.glGetAttribLocation(program, b"a_position")
        check(position >= 0, "a_position attribute missing")
        if self.vertex_buffer:
            self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
            self.g.glVertexAttribPointer(position, 2, GL_FLOAT, 0, 0, None)
        else:
            positions = (ctypes.c_float * len(self.positions))(*self.positions)
            self.client_arrays.append(positions)
            self.g.glVertexAttribPointer(position, 2, GL_FLOAT, 0, 0,
                                         ctypes.cast(positions, ctypes.c_void_p))
        self.g.glEnableVertexAttribArray(position)
        uv = self.g.glGetAttribLocation(program, b"a_texcoord")
        if uv >= 0:
            if self.vertex_buffer:
                self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
                self.g.glVertexAttribPointer(uv, 2, GL_FLOAT, 0, 0,
                                            ctypes.c_void_p(len(self.positions) * ctypes.sizeof(ctypes.c_float)))
            else:
                texcoords = (ctypes.c_float * len(self.texcoords))(*self.texcoords)
                self.client_arrays.append(texcoords)
                self.g.glVertexAttribPointer(uv, 2, GL_FLOAT, 0, 0,
                                             ctypes.cast(texcoords, ctypes.c_void_p))
            self.g.glEnableVertexAttribArray(uv)
        if textured:
            sampler = self.g.glGetUniformLocation(program, b"u_texture")
            check(sampler >= 0, "u_texture uniform missing")
            self.g.glUniform1i(sampler, 0)
        return program

    def _create_programs(self):
        fragment = {
            "solid": SOLID_FRAGMENT_SOURCE,
            "varying": VARYING_FRAGMENT_SOURCE,
            "varying-constant": CONSTANT_VARYING_FRAGMENT_SOURCE,
            "texture-constant": CONSTANT_TEXTURE_FRAGMENT_SOURCE,
            "texture-varying": TEXTURE_FRAGMENT_SOURCE,
        }[SHADER_MODE]
        self.texture_program = self._program(fragment, SHADER_MODE.startswith("texture-"))
        self.solid_program = self._program(SOLID_FRAGMENT_SOURCE, False)

    @staticmethod
    def _vertex_data():
        if TOPOLOGY in ("strip", "indexed-quad"):
            pos = (-1, -1, 1, -1, -1, 1, 1, 1)
            uv = (0, 0, 1, 0, 0, 1, 1, 1)
            count, mode = 4, GL_TRIANGLE_STRIP
        elif TOPOLOGY in ("triangles", "triangles-reversed", "two-triangle-draws",
                          "two-triangle-draws-reversed"):
            if TOPOLOGY in ("triangles-reversed", "two-triangle-draws-reversed"):
                # Same quad and winding, but submit the upper-right triangle first.
                pos = (-1, 1, 1, -1, 1, 1, -1, -1, 1, -1, -1, 1)
                uv = (0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1)
            else:
                pos = (-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1)
                uv = (0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1)
            count, mode = 6, GL_TRIANGLES
        else:
            pos = (-1, -1, 3, -1, -1, 3)
            uv = (0, 0, 2, 0, 0, 2)
            count, mode = 3, GL_TRIANGLES
        if SHADER_MODE == "varying-constant":
            # Keep the complete VBO -> VS attribute -> VS varying -> FS input
            # path active, while making the interpolated value constant over
            # the primitive. The compiler cannot infer buffer contents.
            uv = (0.25, 0.5) * (len(uv) // 2)
        return tuple(pos), tuple(uv), count, mode

    def _new_texture(self, pixels):
        texture = ctypes.c_uint()
        self.g.glGenTextures(1, ctypes.byref(texture))
        self.g.glBindTexture(GL_TEXTURE_2D, texture.value)
        self.g.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
        self.g.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
        self.g.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
        self.g.glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
        ptr = None
        if pixels is not None:
            data = (ctypes.c_ubyte * len(pixels)).from_buffer_copy(pixels)
            ptr = ctypes.cast(data, ctypes.c_void_p)
        self.g.glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, WIDTH, HEIGHT, 0,
                            GL_RGBA, GL_UNSIGNED_BYTE, ptr)
        return texture.value

    def create_source(self, pixels=None):
        if pixels is not None:
            self.source_pixels = pixels
        self.source = self._new_texture(self.source_pixels)

    def recreate_source(self, pixels=None):
        if self.source:
            old = ctypes.c_uint(self.source)
            self.g.glDeleteTextures(1, ctypes.byref(old))
        self.create_source(pixels)

    def update_source(self, pixels):
        data = (ctypes.c_ubyte * len(pixels)).from_buffer_copy(pixels)
        self.g.glBindTexture(GL_TEXTURE_2D, self.source)
        self.g.glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, WIDTH, HEIGHT,
                               GL_RGBA, GL_UNSIGNED_BYTE,
                               ctypes.cast(data, ctypes.c_void_p))

    def update_vbo_texcoords(self, texcoords):
        """Replace only the UV region of the persistent static vertex BO."""
        check(bool(self.vertex_buffer), "transition mode requires --static-vbo")
        data = (ctypes.c_float * len(texcoords))(*texcoords)
        self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
        offset = len(self.positions) * ctypes.sizeof(ctypes.c_float)
        self.g.glBufferSubData(GL_ARRAY_BUFFER, offset, ctypes.sizeof(data),
                               ctypes.cast(data, ctypes.c_void_p))

    def orphan_vbo_texcoords(self, texcoords):
        """Replace the VBO storage at the transition while retaining its GL name."""
        check(bool(self.vertex_buffer), "transition mode requires --static-vbo")
        packed = (ctypes.c_float * (len(self.positions) + len(texcoords)))(
            *(self.positions + tuple(texcoords)))
        self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
        self.g.glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(packed),
                            ctypes.cast(packed, ctypes.c_void_p), GL_STATIC_DRAW)

    def switch_to_new_vbo(self, texcoords):
        """Switch to a distinct vertex BO while keeping the old BO alive."""
        packed = (ctypes.c_float * (len(self.positions) + len(texcoords)))(
            *(self.positions + tuple(texcoords)))
        handle = ctypes.c_uint()
        self.g.glGenBuffers(1, ctypes.byref(handle))
        self.transition_vertex_buffer = handle.value
        self.g.glBindBuffer(GL_ARRAY_BUFFER, self.transition_vertex_buffer)
        self.g.glBufferData(GL_ARRAY_BUFFER, ctypes.sizeof(packed),
                            ctypes.cast(packed, ctypes.c_void_p), GL_STATIC_DRAW)
        self.g.glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, None)
        self.g.glEnableVertexAttribArray(0)
        uv_offset = len(self.positions) * ctypes.sizeof(ctypes.c_float)
        self.g.glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0,
                                     ctypes.c_void_p(uv_offset))
        self.g.glEnableVertexAttribArray(1)

    def reemit_current_vbo(self):
        """Reissue existing vertex-fetch bindings without changing their BO."""
        check(bool(self.vertex_buffer), "transition mode requires --static-vbo")
        self.g.glBindBuffer(GL_ARRAY_BUFFER, self.vertex_buffer)
        self.g.glVertexAttribPointer(0, 2, GL_FLOAT, 0, 0, None)
        self.g.glEnableVertexAttribArray(0)
        uv_offset = len(self.positions) * ctypes.sizeof(ctypes.c_float)
        self.g.glVertexAttribPointer(1, 2, GL_FLOAT, 0, 0,
                                     ctypes.c_void_p(uv_offset))
        self.g.glEnableVertexAttribArray(1)

    def create_destination(self):
        self.destination = self._new_texture(None)
        fbo = ctypes.c_uint()
        self.g.glGenFramebuffers(1, ctypes.byref(fbo))
        self.framebuffer = fbo.value
        self.g.glBindFramebuffer(GL_FRAMEBUFFER, self.framebuffer)
        self.g.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                      GL_TEXTURE_2D, self.destination, 0)
        status = self.g.glCheckFramebufferStatus(GL_FRAMEBUFFER)
        check(status == GL_FRAMEBUFFER_COMPLETE,
              f"FBO incomplete: 0x{status:04x}")

    def recreate_destination(self):
        if self.framebuffer:
            old = ctypes.c_uint(self.framebuffer)
            self.g.glDeleteFramebuffers(1, ctypes.byref(old))
        if self.destination:
            old = ctypes.c_uint(self.destination)
            self.g.glDeleteTextures(1, ctypes.byref(old))
        self.create_destination()

    def recreate_resources(self, source_pixels=None):
        """Recreate both texture BOs while retaining this EGL/GL context."""
        if self.framebuffer:
            old = ctypes.c_uint(self.framebuffer)
            self.g.glDeleteFramebuffers(1, ctypes.byref(old))
            self.framebuffer = 0
        textures = [value for value in (self.source, self.destination) if value]
        if textures:
            handles = (ctypes.c_uint * len(textures))(*textures)
            self.g.glDeleteTextures(len(textures), handles)
        self.source = 0
        self.destination = 0
        self.create_source(source_pixels)
        self.create_destination()

    def bind(self, framebuffer=None):
        self.g.glBindFramebuffer(GL_FRAMEBUFFER,
                                 self.framebuffer if framebuffer is None else framebuffer)
        self.g.glViewport(0, 0, WIDTH, HEIGHT)

    def texture_draw(self, source=None, framebuffer=None):
        self.bind(framebuffer)
        self.g.glUseProgram(self.texture_program)
        self.g.glActiveTexture(0x84C0)  # GL_TEXTURE0
        self.g.glBindTexture(GL_TEXTURE_2D, self.source if source is None else source)
        if self.indexed:
            self.g.glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, self.index_buffer)
            self.g.glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_SHORT, None)
        elif TOPOLOGY.startswith("two-triangle-draws"):
            self.g.glDrawArrays(GL_TRIANGLES, 0, 3)
            self.g.glDrawArrays(GL_TRIANGLES, 3, 3)
        else:
            self.g.glDrawArrays(self.draw_mode, 0, self.vertex_count)

    def clear_sentinel(self, framebuffer=None):
        self.bind(framebuffer)
        r, g, b, a = SENTINEL_RGBA
        self.g.glClearColor(r / 255.0, g / 255.0, b / 255.0, a / 255.0)
        self.g.glClear(GL_COLOR_BUFFER_BIT)

    def readback(self, framebuffer=None):
        self.bind(framebuffer)
        data = (ctypes.c_ubyte * (WIDTH * HEIGHT * 4))()
        self.g.glReadPixels(0, 0, WIDTH, HEIGHT, GL_RGBA, GL_UNSIGNED_BYTE,
                            ctypes.cast(data, ctypes.c_void_p))
        error = self.g.glGetError()
        check(error == 0, f"GL error 0x{error:04x}")
        return bytes(data)

    def create_matrix_resources(self):
        source = self._new_texture(EXPECTED_B)
        destination = self._new_texture(None)
        framebuffer = ctypes.c_uint()
        self.g.glGenFramebuffers(1, ctypes.byref(framebuffer))
        self.g.glBindFramebuffer(GL_FRAMEBUFFER, framebuffer.value)
        self.g.glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                                      GL_TEXTURE_2D, destination, 0)
        check(self.g.glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE,
              "alternate FBO incomplete")
        self.extra_textures.extend((source, destination))
        self.extra_framebuffers.append(framebuffer.value)
        return source, framebuffer.value

    def solid_after_failure(self):
        self.bind()
        self.g.glUseProgram(self.solid_program)
        self.g.glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)
        self.g.glFinish()
        data = self.readback()
        expected = bytes(SOLID_RGBA) * WIDTH * HEIGHT
        print("HIKARI_A220_SOLID_AFTER_FAIL=" + ("PASS" if data == expected else "FAIL")
              + " rgba=" + data[:4].hex(), flush=True)

    def solid_draw_only(self):
        """Submit one full-screen S0 draw without readback or validation draws."""
        self.bind()
        self.g.glUseProgram(self.solid_program)
        self.g.glDrawArrays(GL_TRIANGLE_STRIP, 0, 4)

    def cleanup(self):
        self.d.make_current(self.context)
        self.g.glFinish()
        for program in (self.texture_program, self.solid_program):
            if program:
                self.g.glDeleteProgram(program)
        for name in ("framebuffer",):
            value = getattr(self, name)
            if value:
                handle = ctypes.c_uint(value)
                self.g.glDeleteFramebuffers(1, ctypes.byref(handle))
        if self.extra_framebuffers:
            handles = (ctypes.c_uint * len(self.extra_framebuffers))(*self.extra_framebuffers)
            self.g.glDeleteFramebuffers(len(handles), handles)
        textures = [v for v in (self.source, self.destination) if v]
        textures.extend(self.extra_textures)
        if textures:
            handles = (ctypes.c_uint * len(textures))(*textures)
            self.g.glDeleteTextures(len(textures), handles)
        if self.vertex_buffer:
            handle = ctypes.c_uint(self.vertex_buffer)
            self.g.glDeleteBuffers(1, ctypes.byref(handle))
        if self.transition_vertex_buffer:
            handle = ctypes.c_uint(self.transition_vertex_buffer)
            self.g.glDeleteBuffers(1, ctypes.byref(handle))
        if self.index_buffer:
            handle = ctypes.c_uint(self.index_buffer)
            self.g.glDeleteBuffers(1, ctypes.byref(handle))
        self.d.destroy_context(self.context)


def byte_pattern(rgba):
    return bytes(rgba) * WIDTH * HEIGHT


def reference_for_mode(source):
    if SHADER_MODE == "solid":
        return byte_pattern(SOLID_RGBA)
    if SHADER_MODE == "texture-constant":
        x, y = min(WIDTH - 1, WIDTH // 2), min(HEIGHT - 1, HEIGHT // 2)
        pixel = source[(y * WIDTH + x) * 4:(y * WIDTH + x + 1) * 4]
        return pixel * (WIDTH * HEIGHT)
    if SHADER_MODE == "varying":
        data = bytearray()
        for y in range(HEIGHT):
            for x in range(WIDTH):
                data.extend((int((x + 0.5) * 255 / WIDTH + 0.5),
                             int((y + 0.5) * 255 / HEIGHT + 0.5), 0, 255))
        return bytes(data)
    if SHADER_MODE == "varying-constant":
        return bytes((64, 128, 0, 255)) * (WIDTH * HEIGHT)
    return source


def runtime_status():
    try:
        with open("/sys/devices/platform/4300000.gpu/power/runtime_status",
                  encoding="ascii") as f:
            return f.read().strip()
    except OSError:
        return "unavailable"


def trace_marker(enabled, index, phase):
    if not enabled:
        return
    fd = os.open("/sys/kernel/debug/tracing/trace_marker", os.O_WRONLY)
    try:
        os.write(fd, f"DRAW {index} {phase} pid={os.getpid()}\n".encode())
    finally:
        os.close(fd)


def save_readback_capture(directory, stem, expected, actual):
    if not directory:
        return ""
    root = Path(directory)
    root.mkdir(parents=True, exist_ok=True)
    expected_path = root / f"{stem}-expected.rgba"
    actual_path = root / f"{stem}-actual.rgba"
    expected_path.write_bytes(expected)
    actual_path.write_bytes(actual)
    return f" capture_expected={expected_path} capture_actual={actual_path}"


def pixel_diff_summary(expected, actual):
    width = WIDTH
    mismatches = 0
    first = []
    for offset in range(0, len(actual), 4):
        if actual[offset:offset + 4] == expected[offset:offset + 4]:
            continue
        mismatches += 1
        if len(first) < 8:
            pixel = offset // 4
            first.append(f"{pixel % width},{pixel // width}:"
                         f"{expected[offset:offset + 4].hex()}>{actual[offset:offset + 4].hex()}")
    return mismatches, ";".join(first) if first else "none"


def varying_error_summary(expected, actual):
    severe = 0
    max_delta = 0
    for i in range(0, min(len(expected), len(actual)), 4):
        pixel_delta = max(abs(expected[i + channel] - actual[i + channel])
                          for channel in range(3))
        max_delta = max(max_delta, pixel_delta)
        severe += pixel_delta > 1
    return f"varying_pixels_gt1lsb={severe} max_channel_delta={max_delta}"


def classify_sampled_pixels(source, actual):
    """Classify texture-varying output by exact coordinate-coded source texel."""
    lookup = {source[i:i + 4]: (i // 4 % WIDTH, i // 4 // WIDTH)
              for i in range(0, len(source), 4)}
    correct = moved = unknown = 0
    examples = []
    for i in range(0, len(actual), 4):
        dst = (i // 4 % WIDTH, i // 4 // WIDTH)
        src = lookup.get(actual[i:i + 4])
        if src is None:
            unknown += 1
        elif src == dst:
            correct += 1
        else:
            moved += 1
            if len(examples) < 8:
                examples.append(f"{dst[0]},{dst[1]}<-{src[0]},{src[1]}")
    return f"source_pixels={correct} moved_texels={moved} unknown_values={unknown} " \
           f"coordinate_examples={';'.join(examples) if examples else 'none'}"


def run_worker(args, draw_index):
    device = EGLDevice()
    resource = None
    pattern_index = args.pattern_index + draw_index
    source = EXPECTED_B if args.alternate_source_each_draw and pattern_index % 2 else EXPECTED
    try:
        resource = GLResources(device, source)
        for dummy in range(args.dummy_draws):
            resource.texture_draw()
            if args.finish_between_draws:
                resource.g.glFinish()
            print(f"HIKARI_A220_DUMMY index={draw_index} ordinal={dummy}", flush=True)
        if args.mode == "recreate-texture":
            resource.recreate_source(source)
        elif args.mode == "recreate-destination":
            resource.recreate_destination()
        trace_marker(args.trace_marker, draw_index, "BEGIN")
        resource.clear_sentinel()
        resource.texture_draw()
        resource.g.glFinish()
        actual = resource.readback()
        expected = reference_for_mode(source)
        ok = actual == expected
        digest = hashlib.sha256(actual).hexdigest()
        sentinels = sum(actual[i:i + 4] == bytes(SENTINEL_RGBA)
                        for i in range(0, len(actual), 4))
        mismatches, first_diff = pixel_diff_summary(expected, actual)
        texture_class = (" " + classify_sampled_pixels(source, actual)
                         if SHADER_MODE == "texture-varying" else "")
        capture = save_readback_capture(args.capture_dir, f"draw-{draw_index}",
                                        expected, actual)
        print(f"HIKARI_A220_DRAW index={draw_index} result={'PASS' if ok else 'FAIL'} "
              f"width={WIDTH} height={HEIGHT} format=RGBA8 "
              f"pattern={'B' if expected == EXPECTED_B else 'A'} sha256={digest} "
              f"sentinel_pixels={sentinels} mismatch_pixels={mismatches} "
              f"first_diff={first_diff}{texture_class} "
              f"first64={actual[:64].hex()}{capture}", flush=True)
        trace_marker(args.trace_marker, draw_index, "PASS" if ok else "FAIL")
        if not ok and not args.skip_solid_after_fail:
            resource.solid_after_failure()
        return ok
    finally:
        if resource:
            resource.cleanup()
        device.close()


def run_fresh_processes(args):
    passed = 0
    for index in range(args.iterations):
        command = [sys.executable, os.path.abspath(__file__), "--mode", "same-context",
                   "--iterations", "1", "--dummy-draws", str(args.dummy_draws),
                   "--pattern-index", str(args.pattern_index + index),
                   "--width", str(args.width), "--height", str(args.height),
                   "--pattern-style", args.pattern_style]
        if args.finish_between_draws:
            command.append("--finish-between-draws")
        if args.trace_marker:
            command.append("--trace-marker")
        if args.alternate_source_each_draw:
            command.append("--alternate-source-each-draw")
        if args.skip_solid_after_fail:
            command.append("--skip-solid-after-fail")
        if args.static_vbo:
            command.append("--static-vbo")
        if args.capture_dir:
            command.extend(("--capture-dir", args.capture_dir))
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        if index == 0:
            for line in result.stdout.splitlines():
                if line.startswith(("HIKARI_A220_RENDERER=", "HIKARI_A220_GL_VERSION=")):
                    print(line, flush=True)
        lines = [line for line in result.stdout.splitlines()
                 if line.startswith("HIKARI_A220_DRAW ")]
        if result.returncode:
            sys.stderr.write(result.stderr)
        if lines:
            print(lines[-1].replace("index=0", f"index={index}"), flush=True)
        if result.returncode == 0 and lines and "result=PASS" in lines[-1]:
            passed += 1
    print(f"HIKARI_A220_SUMMARY mode=fresh-process pass={passed} "
          f"fail={args.iterations - passed} total={args.iterations}", flush=True)
    return passed == args.iterations


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("same-context", "new-context",
                                            "recreate-texture", "recreate-destination",
                                            "recreate-resources",
                                            "fresh-process", "source-destination-matrix"),
                        default="same-context")
    parser.add_argument("--iterations", type=int, default=100)
    parser.add_argument("--width", type=int, default=4)
    parser.add_argument("--height", type=int, default=4)
    parser.add_argument("--dummy-draws", type=int, default=0)
    parser.add_argument("--contexts", type=int, default=1,
                        help="rotate through this many persistent contexts (use 2 for A/B)")
    parser.add_argument("--finish-between-draws", action="store_true",
                        help="glFinish after each dummy draw as well as each measurement")
    parser.add_argument("--idle-ms", type=int, default=0,
                        help="wait this long between measured draws, retaining GL resources")
    parser.add_argument("--trace-marker", action="store_true",
                        help="write measured-draw boundaries to kernel trace_marker")
    parser.add_argument("--skip-solid-after-fail", action="store_true",
                        help="do not submit the diagnostic solid draw after a bad readback")
    parser.add_argument("--prime-solid-draws", type=int, default=0,
                        help="submit this many S0 draws once before measured draws")
    parser.add_argument("--finish-after-prime-solid", action="store_true",
                        help="glFinish once after the initial S0 draw sequence")
    parser.add_argument("--prime-varying-draws", type=int, default=0,
                        help="submit this many S1 draws once before measured draws")
    parser.add_argument("--compact", action="store_true",
                        help="skip per-pixel classification; keep PASS/FAIL and SHA256")
    parser.add_argument("--capture-dir",
                        help="write full CPU reference and GPU RGBA readback for each draw")
    parser.add_argument("--capture-failures-only", action="store_true",
                        help="when --capture-dir is set, save only failed draws")
    parser.add_argument("--static-vbo", action="store_true",
                        help="store quad vertices in one persistent GL_ARRAY_BUFFER")
    parser.add_argument("--alternate-source-each-draw", action="store_true",
                        help="alternate the CPU texture pattern when recreating resources")
    parser.add_argument("--pattern-index", type=int, default=0,
                        help=argparse.SUPPRESS)
    parser.add_argument("--shader-mode", choices=("solid", "varying", "varying-constant", "texture-constant",
                                                    "texture-varying"),
                        default="texture-varying")
    parser.add_argument("--topology", choices=("strip", "triangles", "triangles-reversed",
                                                "two-triangle-draws",
                                                "two-triangle-draws-reversed",
                                                "fullscreen-triangle",
                                                "indexed-quad"), default="strip")
    parser.add_argument("--pattern-style", choices=("coordinate", "mixed"),
                        default="coordinate",
                        help="coordinate provenance or original mixed RGB texture pattern")
    parser.add_argument("--readback-every", type=int, default=1,
                        help="read/validate after each N draws")
    parser.add_argument("--finish-every", type=int, default=1,
                        help="glFinish after each N draws; 0 means only at readback")
    parser.add_argument("--clear-every", type=int, default=1,
                        help="clear before each Nth draw; 0 means clear only once")
    parser.add_argument("--transition-s1c-to-s1", action="store_true",
                        help="in one context draw S1c then S1, updating only the persistent VBO UV bytes")
    parser.add_argument("--transition-s1c-prefix", type=int, default=0,
                        help="draw this many S1c frames, then transition to --transition-s1-count ordinary S1 frames")
    parser.add_argument("--transition-s1-count", type=int, default=0,
                        help="ordinary S1 frame count for --transition-s1c-prefix")
    parser.add_argument("--orphan-vbo-at-transition", action="store_true",
                        help="replace VBO storage instead of glBufferSubData at S1c→S1")
    parser.add_argument("--new-vbo-at-transition", action="store_true",
                        help="switch to a distinct VBO at S1c→S1 while keeping the old BO alive")
    parser.add_argument("--reemit-vbo-at-transition", action="store_true",
                        help="reissue vertex attribute bindings to the same VBO at S1c→S1")
    return parser.parse_args()


def main():
    args = parse_args()
    check(sum((args.orphan_vbo_at_transition, args.new_vbo_at_transition,
               args.reemit_vbo_at_transition)) <= 1,
          "choose at most one VBO transition mode")
    if (args.iterations < 1 or not 1 <= args.width <= 2048
            or not 1 <= args.height <= 2048
            or args.dummy_draws < 0 or args.prime_solid_draws < 0
            or args.prime_varying_draws < 0 or args.idle_ms < 0
            or args.pattern_index < 0 or args.transition_s1c_prefix < 0
            or args.transition_s1_count < 0
            or args.readback_every < 1 or args.finish_every < 0 or args.clear_every < 0
            or not 1 <= args.contexts <= 8):
        raise SystemExit("valid dimensions are 1..2048; iterations>=1, dummy-draws>=0, "
                         "idle-ms>=0, contexts in 1..8 required")
    global WIDTH, HEIGHT, EXPECTED, EXPECTED_B, SHADER_MODE, TOPOLOGY, PATTERN_STYLE
    WIDTH, HEIGHT = args.width, args.height
    SHADER_MODE = args.shader_mode
    TOPOLOGY = args.topology
    PATTERN_STYLE = args.pattern_style
    EXPECTED, EXPECTED_B = source_pattern(), alternate_pattern()
    print(f"HIKARI_A220_CASE width={WIDTH} height={HEIGHT} format=RGBA8 "
          f"source_sha256={hashlib.sha256(EXPECTED).hexdigest()} "
                  f"shader={SHADER_MODE} topology={TOPOLOGY} pattern_style={PATTERN_STYLE} "
                  f"reference_sha256={hashlib.sha256(reference_for_mode(EXPECTED)).hexdigest()}", flush=True)
    if args.mode == "fresh-process":
        ok = run_fresh_processes(args)
        return 0 if ok else 1

    device = EGLDevice()
    device.static_vbo = args.static_vbo
    resources = []
    passed = 0
    try:
        count = 1 if args.mode == "new-context" else args.contexts
        initial_pattern = (
            EXPECTED_B
            if args.alternate_source_each_draw and args.pattern_index % 2
            else EXPECTED
        )
        resources = [GLResources(device, initial_pattern) for _ in range(count)]
        if args.transition_s1c_prefix or args.transition_s1_count:
            check(args.transition_s1c_prefix > 0 and args.transition_s1_count > 0,
                  "both transition series lengths must be nonzero")
            check(SHADER_MODE == "varying-constant",
                  "transition sequence requires --shader-mode varying-constant")
            check(args.static_vbo, "transition sequence requires --static-vbo")
            resource = resources[0]
            device.make_current(resource.context)
            counts = {"EXACT": 0, "NEAR": 0, "SEVERE": 0}
            saved_outputs = set()
            classified_outputs = {}
            draw_index = 0

            def measured_draw(stage, expected):
                nonlocal draw_index
                # The full-screen triangle overwrites the complete target.
                # Clear once before the series, not between measured draws:
                # repeated clears submit A220 clear-state packets and perturb
                # the very persistent state this transition mode measures.
                resource.texture_draw()
                resource.g.glFinish()
                actual = resource.readback()
                digest = hashlib.sha256(actual).hexdigest()
                output_key = (stage, digest)
                cached = classified_outputs.get(output_key)
                if cached is None:
                    if actual == expected:
                        classification = "EXACT"
                        max_delta = 0
                        pixels_gt1 = 0
                    else:
                        deltas = [abs(actual[i + c] - expected[i + c])
                                  for i in range(0, len(expected), 4) for c in range(4)]
                        max_delta = max(deltas, default=0)
                        pixels_gt1 = sum(
                            max(abs(actual[i + c] - expected[i + c]) for c in range(4)) > 1
                            for i in range(0, len(expected), 4))
                        classification = "NEAR" if max_delta <= 1 else "SEVERE"
                    classified_outputs[output_key] = (
                        classification, max_delta, pixels_gt1)
                else:
                    classification, max_delta, pixels_gt1 = cached
                counts[classification] += 1
                capture = ""
                if args.capture_dir and output_key not in saved_outputs:
                    saved_outputs.add(output_key)
                    capture = save_readback_capture(
                        args.capture_dir, f"unique-{stage}-{digest[:16]}", expected, actual)
                print(f"HIKARI_A220_SEQUENCE index={draw_index} stage={stage} "
                      f"class={classification} sha256={digest} max_delta={max_delta} "
                      f"pixels_gt1lsb={pixels_gt1}{capture}", flush=True)
                draw_index += 1

            constant_expected = reference_for_mode(EXPECTED)
            resource.clear_sentinel()
            resource.g.glFinish()
            for _ in range(args.transition_s1c_prefix):
                measured_draw("S1c", constant_expected)

            previous_mode = SHADER_MODE
            SHADER_MODE = "varying"
            _, ordinary_texcoords, _, _ = resource._vertex_data()
            SHADER_MODE = previous_mode
            if args.orphan_vbo_at_transition:
                resource.orphan_vbo_texcoords(ordinary_texcoords)
            elif args.new_vbo_at_transition:
                resource.switch_to_new_vbo(ordinary_texcoords)
            else:
                resource.update_vbo_texcoords(ordinary_texcoords)
                if args.reemit_vbo_at_transition:
                    resource.reemit_current_vbo()
            previous_mode = SHADER_MODE
            SHADER_MODE = "varying"
            ordinary_expected = reference_for_mode(EXPECTED)
            SHADER_MODE = previous_mode
            for _ in range(args.transition_s1_count):
                measured_draw("S1", ordinary_expected)

            print("HIKARI_A220_SEQUENCE_SUMMARY " + " ".join(
                f"{name.lower()}={counts[name]}" for name in counts), flush=True)
            return 0
        if args.transition_s1c_to_s1:
            check(SHADER_MODE == "varying-constant",
                  "--transition-s1c-to-s1 requires --shader-mode varying-constant")
            check(args.static_vbo and args.iterations == 1,
                  "transition mode requires --static-vbo and --iterations 1")
            resource = resources[0]
            device.make_current(resource.context)
            capture_dir = args.capture_dir
            if capture_dir:
                Path(capture_dir).mkdir(parents=True, exist_ok=True)

            # First draw: constant vertex attribute values still travel through
            # the same VS output and interpolated FS input as ordinary S1.
            resource.clear_sentinel()
            trace_marker(args.trace_marker, 0, "S1C_BEGIN")
            resource.texture_draw()
            resource.g.glFinish()
            actual = resource.readback()
            expected = reference_for_mode(EXPECTED)
            digest = hashlib.sha256(actual).hexdigest()
            capture = save_readback_capture(capture_dir, "transition-s1c", expected, actual)
            print(f"HIKARI_A220_TRANSITION stage=S1c sha256={digest}{capture}", flush=True)
            trace_marker(args.trace_marker, 0, "S1C_DONE")

            # Keep context, shader, destination, and BO identity; alter only the
            # UV bytes in the existing VBO before the ordinary varying draw.
            previous_mode = SHADER_MODE
            SHADER_MODE = "varying"
            _, ordinary_texcoords, _, _ = resource._vertex_data()
            SHADER_MODE = previous_mode
            resource.update_vbo_texcoords(ordinary_texcoords)
            trace_marker(args.trace_marker, 1, "S1_BEGIN")
            resource.texture_draw()
            resource.g.glFinish()
            actual = resource.readback()
            previous_mode = SHADER_MODE
            SHADER_MODE = "varying"
            expected = reference_for_mode(EXPECTED)
            SHADER_MODE = previous_mode
            digest = hashlib.sha256(actual).hexdigest()
            capture = save_readback_capture(capture_dir, "transition-s1", expected, actual)
            print(f"HIKARI_A220_TRANSITION stage=S1 sha256={digest}{capture}", flush=True)
            trace_marker(args.trace_marker, 1, "S1_DONE")
            return 0

        if args.prime_solid_draws:
            resource = resources[0]
            device.make_current(resource.context)
            for _ in range(args.prime_solid_draws):
                resource.solid_draw_only()
            if args.finish_after_prime_solid:
                resource.g.glFinish()
            print(f"HIKARI_A220_PRIME_SOLID draws={args.prime_solid_draws} "
                  f"finish={int(args.finish_after_prime_solid)} readback=none", flush=True)
        if args.prime_varying_draws:
            resource = resources[0]
            device.make_current(resource.context)
            for _ in range(args.prime_varying_draws):
                resource.texture_draw()
            print(f"HIKARI_A220_PRIME_VARYING draws={args.prime_varying_draws} "
                  "finish=0 readback=none", flush=True)
        if (args.readback_every > 1 or args.finish_every != 1 or args.clear_every != 1):
            resource = resources[0]
            device.make_current(resource.context)
            if args.clear_every == 0:
                resource.clear_sentinel()
            group_pass, group_fail = 0, 0
            for index in range(args.iterations):
                pattern = (EXPECTED_B if args.alternate_source_each_draw and index % 2
                           else EXPECTED)
                if args.alternate_source_each_draw:
                    resource.update_source(pattern)
                if args.clear_every and index % args.clear_every == 0:
                    resource.clear_sentinel()
                resource.texture_draw()
                if args.finish_every and (index + 1) % args.finish_every == 0:
                    resource.g.glFinish()
                if (index + 1) % args.readback_every:
                    continue
                resource.g.glFinish()
                actual = resource.readback()
                expected = reference_for_mode(pattern)
                ok = actual == expected
                digest = hashlib.sha256(actual).hexdigest()
                print(f"HIKARI_A220_GROUP index={index} draws={args.readback_every} "
                      f"result={'PASS' if ok else 'FAIL'} sha256={digest}", flush=True)
                group_pass += int(ok)
                group_fail += int(not ok)
            total = group_pass + group_fail
            print(f"HIKARI_A220_SUMMARY mode=cadence pass={group_pass} "
                  f"fail={group_fail} total={total} draws={args.iterations}", flush=True)
            return 0 if group_fail == 0 else 1
        if args.mode == "source-destination-matrix":
            resource = resources[0]
            source_b, framebuffer_b = resource.create_matrix_resources()
            pairs = (("A", resource.source, "0", resource.framebuffer, EXPECTED),
                     ("A", resource.source, "1", framebuffer_b, EXPECTED),
                     ("B", source_b, "0", resource.framebuffer, EXPECTED_B),
                     ("B", source_b, "1", framebuffer_b, EXPECTED_B))
            passed = 0
            for iteration in range(args.iterations):
                for src_name, source, dst_name, framebuffer, expected in pairs:
                    trace_marker(args.trace_marker, iteration, "BEGIN")
                    resource.clear_sentinel(framebuffer)
                    resource.texture_draw(source, framebuffer)
                    resource.g.glFinish()
                    actual = resource.readback(framebuffer)
                    ok = actual == expected
                    digest = hashlib.sha256(actual).hexdigest()
                    mismatches, first_diff = pixel_diff_summary(expected, actual)
                    capture = save_readback_capture(
                        args.capture_dir, f"matrix-{iteration}-{src_name}-{dst_name}",
                        expected, actual)
                    print(f"HIKARI_A220_MATRIX iteration={iteration} source={src_name} "
                          f"destination={dst_name} result={'PASS' if ok else 'FAIL'} "
                          f"width={WIDTH} height={HEIGHT} format=RGBA8 sha256={digest} "
                          f"mismatch_pixels={mismatches} first_diff={first_diff} "
                          f"first64={actual[:64].hex()}{capture}", flush=True)
                    trace_marker(args.trace_marker, iteration,
                                 "PASS" if ok else "FAIL")
                    passed += int(ok)
            total = args.iterations * len(pairs)
            print(f"HIKARI_A220_SUMMARY mode=source-destination-matrix pass={passed} "
                  f"fail={total - passed} total={total}", flush=True)
            return 0 if passed == total else 1
        for index in range(args.iterations):
            if index and args.idle_ms:
                before = runtime_status()
                time.sleep(args.idle_ms / 1000)
                after = runtime_status()
                print(f"HIKARI_A220_IDLE index={index} ms={args.idle_ms} "
                      f"before={before} after={after}", flush=True)
            slot = index % count
            resource = resources[slot]
            pattern_index = args.pattern_index + index
            source = EXPECTED_B if args.alternate_source_each_draw and pattern_index % 2 else EXPECTED
            if args.mode == "new-context":
                resource.cleanup()
                resource = GLResources(device, source)
                resources[slot] = resource
            else:
                device.make_current(resource.context)
            if (args.alternate_source_each_draw
                    and args.mode not in ("new-context", "recreate-texture",
                                          "recreate-resources")):
                resource.update_source(source)
            for dummy in range(args.dummy_draws):
                resource.texture_draw()
                if args.finish_between_draws:
                    resource.g.glFinish()
                print(f"HIKARI_A220_DUMMY index={index} ordinal={dummy} context={slot}",
                      flush=True)
            if args.mode == "recreate-texture":
                resource.recreate_source(source)
            elif args.mode == "recreate-destination":
                resource.recreate_destination()
            elif args.mode == "recreate-resources":
                resource.recreate_resources(source)
            trace_marker(args.trace_marker, index, "BEGIN")
            resource.clear_sentinel()
            resource.texture_draw()
            resource.g.glFinish()
            actual = resource.readback()
            expected = reference_for_mode(source)
            # The tolerance scan is intentionally omitted in compact mode:
            # it is a Python loop over every pixel and can add seconds between
            # GPU submissions on the ARMv7 target. Compact runs retain the
            # exact readback bytes and hash; near-match results are classified
            # from those hashes after the run.
            interpolated = SHADER_MODE in ("varying", "varying-constant")
            ok = (actual == expected if args.compact or not interpolated else
                  "varying_pixels_gt1lsb=0" in varying_error_summary(expected, actual))
            digest = hashlib.sha256(actual).hexdigest()
            if args.compact:
                sentinels, mismatches, first_diff = 0, -1, "omitted"
                texture_class = varying_class = ""
            else:
                sentinels = sum(actual[i:i + 4] == bytes(SENTINEL_RGBA)
                                for i in range(0, len(actual), 4))
                mismatches, first_diff = pixel_diff_summary(expected, actual)
                texture_class = (" " + classify_sampled_pixels(source, actual)
                                 if SHADER_MODE == "texture-varying" else "")
                varying_class = (" " + varying_error_summary(expected, actual)
                                 if interpolated else "")
            capture = ""
            if args.capture_dir and (not args.capture_failures_only or not ok):
                capture = save_readback_capture(
                    args.capture_dir, f"draw-{index}-context-{slot}", expected, actual)
            print(f"HIKARI_A220_DRAW index={index} context={slot} "
                  f"result={'PASS' if ok else 'FAIL'} width={WIDTH} height={HEIGHT} "
                  f"format=RGBA8 "
                  f"pattern={'B' if expected == EXPECTED_B else 'A'} sha256={digest} "
                  f"sentinel_pixels={sentinels} mismatch_pixels={mismatches} "
                  f"first_diff={first_diff}{texture_class}{varying_class} "
                  f"first64={actual[:64].hex()}{capture}", flush=True)
            trace_marker(args.trace_marker, index, "PASS" if ok else "FAIL")
            if ok:
                passed += 1
            elif not args.skip_solid_after_fail:
                resource.solid_after_failure()
        print(f"HIKARI_A220_SUMMARY mode={args.mode} pass={passed} "
              f"fail={args.iterations - passed} total={args.iterations}", flush=True)
    finally:
        for resource in resources:
            if resource:
                resource.cleanup()
        device.close()
    return 0 if passed == args.iterations else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"HIKARI_A220_TEXTURE=FAIL {error}", file=sys.stderr, flush=True)
        raise SystemExit(1)
