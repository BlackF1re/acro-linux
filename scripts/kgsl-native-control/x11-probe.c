#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <stdlib.h>
#include <unistd.h>
/* Native ARMv7 hard-float GLES2 KGSL control probe.
 * Workload mirrors test-hikari-a220-texture.py's planar static VBO,
 * one initial clear and same-program S1c -> UV update -> S1 transition.
 * Platform/bootstrap adapted from the project's Android golden probe.
 */
typedef unsigned int u32;
typedef int i32;
typedef unsigned char u8;
typedef unsigned int size_t;
typedef void *EGLDisplay;
typedef void *EGLConfig;
typedef void *EGLSurface;
typedef void *EGLContext;
typedef unsigned int EGLBoolean;
typedef unsigned int EGLenum;
typedef int EGLint;
typedef unsigned int GLenum;
typedef unsigned int GLuint;
typedef int GLint;
typedef int GLsizei;
typedef unsigned char GLboolean;
typedef float GLfloat;
typedef char GLchar;
typedef void GLvoid;

#define EGL_DEFAULT_DISPLAY ((void *)0)
#define EGL_NONE 0x3038
#define EGL_VENDOR 0x3053
#define EGL_VERSION 0x3054
#define EGL_EXTENSIONS 0x3055
#define EGL_SURFACE_TYPE 0x3033
#define EGL_PBUFFER_BIT 0x0001
#define EGL_RENDERABLE_TYPE 0x3040
#define EGL_OPENGL_ES2_BIT 0x0004
#define EGL_RED_SIZE 0x3024
#define EGL_GREEN_SIZE 0x3023
#define EGL_BLUE_SIZE 0x3022
#define EGL_ALPHA_SIZE 0x3021
#define EGL_WIDTH 0x3057
#define EGL_HEIGHT 0x3056
#define EGL_OPENGL_ES_API 0x30A0
#define EGL_CONTEXT_CLIENT_VERSION 0x3098
#define GL_VENDOR 0x1F00
#define GL_RENDERER 0x1F01
#define GL_VERSION 0x1F02
#define GL_EXTENSIONS 0x1F03
#define GL_VERTEX_SHADER 0x8B31
#define GL_FRAGMENT_SHADER 0x8B30
#define GL_COMPILE_STATUS 0x8B81
#define GL_LINK_STATUS 0x8B82
#define GL_ARRAY_BUFFER 0x8892
#define GL_STATIC_DRAW 0x88E4
#define GL_FLOAT 0x1406
#define GL_TRIANGLES 0x0004
#define GL_TEXTURE_2D 0x0DE1
#define GL_TEXTURE0 0x84C0
#define GL_TEXTURE_MIN_FILTER 0x2801
#define GL_TEXTURE_MAG_FILTER 0x2800
#define GL_TEXTURE_WRAP_S 0x2802
#define GL_TEXTURE_WRAP_T 0x2803
#define GL_NEAREST 0x2600
#define GL_CLAMP_TO_EDGE 0x812F
#define GL_RGBA 0x1908
#define GL_UNSIGNED_BYTE 0x1401
#define GL_FRAMEBUFFER 0x8D40
#define GL_COLOR_ATTACHMENT0 0x8CE0
#define GL_FRAMEBUFFER_COMPLETE 0x8CD5
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_PACK_ALIGNMENT 0x0D05
#define GL_UNPACK_ALIGNMENT 0x0CF5

extern EGLDisplay eglGetDisplay(void *);
extern EGLBoolean eglInitialize(EGLDisplay, EGLint *, EGLint *);
extern EGLBoolean eglBindAPI(EGLenum);
extern EGLBoolean eglChooseConfig(EGLDisplay, const EGLint *, EGLConfig *, EGLint, EGLint *);
extern EGLSurface eglCreatePbufferSurface(EGLDisplay, EGLConfig, const EGLint *);
extern EGLContext eglCreateContext(EGLDisplay, EGLConfig, EGLContext, const EGLint *);
extern EGLBoolean eglMakeCurrent(EGLDisplay, EGLSurface, EGLSurface, EGLContext);
extern EGLBoolean eglDestroySurface(EGLDisplay, EGLSurface);
extern EGLBoolean eglDestroyContext(EGLDisplay, EGLContext);
extern EGLBoolean eglTerminate(EGLDisplay);
extern const char *eglQueryString(EGLDisplay, EGLint);
extern EGLint eglGetError(void);
extern const u8 *glGetString(GLenum);
extern GLuint glCreateShader(GLenum);
extern void glShaderSource(GLuint, GLsizei, const GLchar *const *, const GLint *);
extern void glCompileShader(GLuint);
extern void glGetShaderiv(GLuint, GLenum, GLint *);
extern void glGetShaderInfoLog(GLuint, GLsizei, GLsizei *, GLchar *);
extern GLuint glCreateProgram(void);
extern void glAttachShader(GLuint, GLuint);
extern void glBindAttribLocation(GLuint, GLuint, const GLchar *);
extern void glLinkProgram(GLuint);
extern void glGetProgramiv(GLuint, GLenum, GLint *);
extern void glGetProgramInfoLog(GLuint, GLsizei, GLsizei *, GLchar *);
extern void glUseProgram(GLuint);
extern GLint glGetAttribLocation(GLuint, const GLchar *);
extern GLint glGetUniformLocation(GLuint, const GLchar *);
extern void glUniform1i(GLint, GLint);
extern void glGenBuffers(GLsizei, GLuint *);
extern void glBindBuffer(GLenum, GLuint);
extern void glBufferData(GLenum, int, const GLvoid *, GLenum);
extern void glVertexAttribPointer(GLuint, GLint, GLenum, GLboolean, GLsizei, const GLvoid *);
extern void glEnableVertexAttribArray(GLuint);
extern void glViewport(GLint, GLint, GLsizei, GLsizei);
extern void glPixelStorei(GLenum, GLint);
extern void glGenTextures(GLsizei, GLuint *);
extern void glBindTexture(GLenum, GLuint);
extern void glActiveTexture(GLenum);
extern void glTexParameteri(GLenum, GLenum, GLint);
extern void glTexImage2D(GLenum, GLint, GLint, GLsizei, GLsizei, GLint, GLenum, GLenum, const GLvoid *);
extern void glGenFramebuffers(GLsizei, GLuint *);
extern void glBindFramebuffer(GLenum, GLuint);
extern void glFramebufferTexture2D(GLenum, GLenum, GLenum, GLuint, GLint);
extern GLenum glCheckFramebufferStatus(GLenum);
extern void glClearColor(GLfloat, GLfloat, GLfloat, GLfloat);
extern void glClear(GLenum);
extern void glDrawArrays(GLenum, GLint, GLsizei);
extern void glFinish(void);
extern void glReadPixels(GLint, GLint, GLsizei, GLsizei, GLenum, GLenum, GLvoid *);
extern GLenum glGetError(void);
extern int open(const char *, int, ...);
extern int read(int, void *, unsigned int);
extern int write(int, const void *, unsigned int);
extern int close(int);
extern unsigned int sleep(unsigned int);
extern int strcmp(const char *, const char *);
extern int getpid(void);
extern int ioctl(int, unsigned long, ...);

#define WIDTH 256
#define HEIGHT 256
#define PIXELS (WIDTH * HEIGHT * 4)

static const char vs_source[] =
    "attribute vec2 a_position;\n"
    "attribute vec2 a_texcoord;\n"
    "varying vec2 v_texcoord;\n"
    "void main(){gl_Position=vec4(a_position,0.0,1.0);v_texcoord=a_texcoord;}\n";
static const char fs_s0[] =
    "precision mediump float;\n"
    "void main(){gl_FragColor=vec4(0.75686276,0.27843139,0.58431375,1.0);}\n";
static const char fs_s1[] =
    "precision highp float; varying vec2 v_texcoord;\n"
    "void main(){gl_FragColor=vec4(v_texcoord,0.0,1.0);}\n";
static const char fs_s2[] =
    "precision highp float; uniform sampler2D u_texture;\n"
    "void main(){gl_FragColor=texture2D(u_texture,vec2(0.5,0.5));}\n";
static const char fs_s3[] =
    "precision highp float; uniform sampler2D u_texture; varying vec2 v_texcoord;\n"
    "void main(){gl_FragColor=texture2D(u_texture,v_texcoord);}\n";

static GLfloat vertices_s1[] = {
    -1.f,-1.f, 0.f,0.f,  3.f,-1.f, 2.f,0.f,  -1.f,3.f, 0.f,2.f
};
static GLfloat vertices_s1c[] = {
    -1.f,-1.f,.25f,.5f,  3.f,-1.f,.25f,.5f,  -1.f,3.f,.25f,.5f
};
static u8 readback[PIXELS];
static u8 source[4 * 4 * 4];
static char logbuf[8192];
static GLuint target_fbo;
static const char *output_dir;
static char mapsbuf[32768];

static void say(const char *s) {
    unsigned int n = 0;
    while (s[n]) n++;
    write(1, s, n);
}

static void say_hex(const char *label, const u8 *p, unsigned int n) {
    static const char hex[] = "0123456789abcdef";
    unsigned int i;
    say(label);
    for (i = 0; i < n; i++) {
        char c[2] = { hex[p[i] >> 4], hex[p[i] & 15] };
        write(1, c, 2);
    }
    say("\n");
}

static void uintstr(unsigned int v, char *b) {
    char tmp[16]; unsigned int n=0, i;
    do { tmp[n++] = (char)('0' + v % 10); v /= 10; } while (v);
    for (i=0;i<n;i++) b[i]=tmp[n-1-i];
    b[n]=0;
}

static void hex32(unsigned int v, char *b) {
    static const char hex[]="0123456789abcdef";
    int i;
    for(i=0;i<8;i++) b[i]=hex[(v >> (28-4*i)) & 15];
    b[8]=0;
}

static void query_kgsl(void) {
    struct devinfo { u32 device_id, chip_id, mmu_enabled, gmem_base, gpu_id, gmem_size; } info;
    struct getproperty { u32 type; void *value; u32 sizebytes; } prop;
    char b[16];
    int fd=open("/dev/kgsl-3d0",2,0);
    if(fd<0) { say("KGSL_DEVICE_INFO=unavailable\n"); return; }
    prop.type=1; prop.value=&info; prop.sizebytes=sizeof(info);
    if(ioctl(fd,0xc00c0902UL,&prop)<0) { say("KGSL_DEVICE_INFO=ioctl-failed\n"); close(fd); return; }
    say("KGSL_DEVICE_ID="); uintstr(info.device_id,b); say(b);
    say("\nKGSL_CHIP_ID=0x"); hex32(info.chip_id,b); say(b);
    say("\nKGSL_GPU_ID="); uintstr(info.gpu_id,b); say(b);
    say("\nKGSL_MMU_ENABLED="); uintstr(info.mmu_enabled,b); say(b);
    say("\nKGSL_GMEM_SIZE="); uintstr(info.gmem_size,b); say(b); say("\n");
    close(fd);
}

static void make_source(void) {
    unsigned int x,y,k=0;
    for (y=0;y<4;y++) for (x=0;x<4;x++) {
        source[k++]=(u8)x; source[k++]=(u8)y; source[k++]=0; source[k++]=255;
    }
}

static GLuint compile_shader(GLenum kind, const char *src) {
    GLuint s=glCreateShader(kind); GLint ok=0; const char *list[1]={src};
    glShaderSource(s,1,list,0); glCompileShader(s); glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if (!ok) { GLsizei n=0; glGetShaderInfoLog(s,sizeof(logbuf),&n,logbuf); say("SHADER_COMPILE_FAIL "); say(logbuf); say("\n"); return 0; }
    return s;
}

static GLuint make_program(const char *fs, int tex) {
    GLuint v=compile_shader(GL_VERTEX_SHADER,vs_source), f=compile_shader(GL_FRAGMENT_SHADER,fs), p;
    GLint ok=0;
    if (!v || !f) return 0;
    p=glCreateProgram(); glAttachShader(p,v); glAttachShader(p,f);
    glBindAttribLocation(p,0,"a_position"); glBindAttribLocation(p,1,"a_texcoord");
    glLinkProgram(p); glGetProgramiv(p,GL_LINK_STATUS,&ok);
    if (!ok) { GLsizei n=0; glGetProgramInfoLog(p,sizeof(logbuf),&n,logbuf); say("PROGRAM_LINK_FAIL "); say(logbuf); say("\n"); return 0; }
    glUseProgram(p);
    if (tex) { GLint u=glGetUniformLocation(p,"u_texture"); glUniform1i(u,0); }
    return p;
}

static GLuint make_vbo(GLfloat *data) {
    GLuint b; glGenBuffers(1,&b); glBindBuffer(GL_ARRAY_BUFFER,b);
    glBufferData(GL_ARRAY_BUFFER,sizeof(vertices_s1),data,GL_STATIC_DRAW);
    return b;
}

static void use_program_vbo(GLuint p, GLuint b, int has_varying) {
    GLint pos, uv;
    glUseProgram(p); glBindBuffer(GL_ARRAY_BUFFER,b);
    pos=glGetAttribLocation(p,"a_position");
    if (pos >= 0) { glVertexAttribPointer((GLuint)pos,2,GL_FLOAT,0,4*sizeof(GLfloat),(const void *)0); glEnableVertexAttribArray((GLuint)pos); }
    uv=glGetAttribLocation(p,"a_texcoord");
    if (uv >= 0 && has_varying) { glVertexAttribPointer((GLuint)uv,2,GL_FLOAT,0,4*sizeof(GLfloat),(const void *)(2*sizeof(GLfloat))); glEnableVertexAttribArray((GLuint)uv); }
    else if (uv >= 0) glEnableVertexAttribArray((GLuint)uv);
}

static int save_draw(const char *prefix, unsigned int index) {
    char path[256], num[16]; unsigned int n=0,i; int fd, wrote;
    const char *base=output_dir;
    uintstr(index,num);
    while (base[n]) { path[n]=base[n]; n++; }
    while (*prefix) { path[n++]=*prefix++; }
    path[n++]='-'; for(i=0;num[i];i++) path[n++]=num[i];
    path[n++]='.'; path[n++]='r'; path[n++]='g'; path[n++]='b'; path[n++]='a'; path[n]=0;
    fd=open(path,1|64|512,0644); if(fd<0) { say("OPEN_FAIL\n"); return -1; }
    wrote=write(fd,readback,PIXELS); close(fd);
    if (wrote != PIXELS) { say("WRITE_FAIL\n"); return -1; }
    return 0;
}

static void capture_maps(void) {
    int in=open("/proc/self/maps",0,0), out=open("/tmp/probe-maps.txt",1|64|512,0644);
    int n; char pidbuf[16];
    say("PROBE_PID="); uintstr((unsigned int)getpid(),pidbuf); say(pidbuf); say("\n");
    if (in<0 || out<0) { say("MAP_CAPTURE_FAIL\n"); if(in>=0)close(in); if(out>=0)close(out); return; }
    while ((n=read(in,mapsbuf,sizeof(mapsbuf)))>0) write(out,mapsbuf,(unsigned int)n);
    close(in); close(out);
}


extern void *gbm_create_device(int);
extern void glBufferSubData(GLenum, int, int, const void *);
static int measured(const char *stage, unsigned int n) {
 unsigned int i;
 for(i=0;i<n;i++) {
  glDrawArrays(GL_TRIANGLES,0,3); glFinish();
  glReadPixels(0,0,256,256,GL_RGBA,GL_UNSIGNED_BYTE,readback);
  if(glGetError()) { say("GL_ERROR\n"); return 8; }
  if(save_draw(stage,i)) return 9;
  say("DRAW_COMPLETE "); say(stage); say("\n");
 }
 return 0;
}
int main(int argc,char **argv) {
 EGLDisplay d; EGLConfig cfg; EGLContext ctx; EGLint ma,mi,n;
 const EGLint ca[]={EGL_RENDERABLE_TYPE,EGL_OPENGL_ES2_BIT,EGL_NONE};
 const EGLint xa[]={EGL_CONTEXT_CLIENT_VERSION,2,EGL_NONE};
 GLuint p,b,t,f; int fd,rc; void *gbm;
 static GLfloat data[]={-1,-1,3,-1,-1,3, .25,.5,.25,.5,.25,.5};
 static const GLfloat uv[]={0,0,2,0,0,2};
 const int solid=argc>1&&!strcmp(argv[1],"s0");
 output_dir=argc>2?argv[2]:"/tmp/";
 say("BOOTSTRAP_OPEN /dev/dri/card0\n");
 fd=open("/dev/dri/card0",2,0); if(fd<0)return 1;
 gbm=gbm_create_device(fd); if(!gbm){say("GBM_FAIL\n");return 2;}
 d=eglGetDisplay(gbm);
 if(!d||!eglInitialize(d,&ma,&mi)){say("EGL_INIT_FAIL\n");return 3;}
 if(!eglBindAPI(EGL_OPENGL_ES_API)||!eglChooseConfig(d,ca,&cfg,1,&n)||!n){say("EGL_CONFIG_FAIL\n");return 4;}
 ctx=eglCreateContext(d,cfg,0,xa);
 if(!ctx||!eglMakeCurrent(d,0,0,ctx)){say("EGL_CONTEXT_FAIL\n");return 5;}
 say("GL_RENDERER=");say((const char*)glGetString(GL_RENDERER));say("\nGL_VERSION=");say((const char*)glGetString(GL_VERSION));say("\n");
 query_kgsl();
 capture_maps();
 p=make_program(solid?fs_s0:fs_s1,0);if(!p)return 6;
 glGenBuffers(1,&b);glBindBuffer(GL_ARRAY_BUFFER,b);
 glBufferData(GL_ARRAY_BUFFER,sizeof(data),data,GL_STATIC_DRAW);
 GLint pos=glGetAttribLocation(p,"a_position"),coord=glGetAttribLocation(p,"a_texcoord");
 glVertexAttribPointer(pos,2,GL_FLOAT,0,0,0);glEnableVertexAttribArray(pos);
 if(coord>=0){glVertexAttribPointer(coord,2,GL_FLOAT,0,0,(void*)24);glEnableVertexAttribArray(coord);}
 glGenTextures(1,&t);glBindTexture(GL_TEXTURE_2D,t);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
 glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,256,256,0,GL_RGBA,GL_UNSIGNED_BYTE,0);
 glGenFramebuffers(1,&f);glBindFramebuffer(GL_FRAMEBUFFER,f);glFramebufferTexture2D(GL_FRAMEBUFFER,GL_COLOR_ATTACHMENT0,GL_TEXTURE_2D,t,0);
 if(glCheckFramebufferStatus(GL_FRAMEBUFFER)!=GL_FRAMEBUFFER_COMPLETE){say("FBO_FAIL\n");return 7;}
 glViewport(0,0,256,256);glPixelStorei(GL_PACK_ALIGNMENT,1);
 glClearColor(9.f/255,18.f/255,27.f/255,1);glClear(GL_COLOR_BUFFER_BIT);glFinish();
 if(argc>1&&!strcmp(argv[1],"x11")) {
  Display *xd=XOpenDisplay(0); if(!xd){say("XOPEN_FAIL\n");return 20;}
  int screen=DefaultScreen(xd); Window w=XCreateSimpleWindow(xd,RootWindow(xd,screen),0,0,512,512,0,0,0);
  XStoreName(xd,w,"KGSL Adreno 220 hardware GLES2");XMapWindow(xd,w);XSync(xd,0);
  unsigned char *image=malloc(512*512*4); XImage *xi=XCreateImage(xd,DefaultVisual(xd,screen),24,ZPixmap,0,(char*)image,512,512,32,0);
  GC gc=XCreateGC(xd,w,0,0); glBufferSubData(GL_ARRAY_BUFFER,24,sizeof(uv),uv);
  unsigned severe=0;
  for(unsigned k=0;k<300;k++) {
   glDrawArrays(GL_TRIANGLES,0,3);glFinish();glReadPixels(0,0,256,256,GL_RGBA,GL_UNSIGNED_BYTE,readback);
   int bad=0;
   for(unsigned y=0;y<256;y++)for(unsigned x=0;x<256;x++) {
    unsigned off=(y*256+x)*4;int rr=((2*x+1)*255+256)/512,gg=((2*y+1)*255+256)/512;
    int dr=(int)readback[off]-rr,dg=(int)readback[off+1]-gg;
    if(dr>1||dr < -1||dg>1||dg < -1||readback[off+2]>1||readback[off+3]!=255)bad=1;
   }
   severe+=bad;
   for(unsigned y=0;y<512;y++)for(unsigned x=0;x<512;x++) {unsigned src=((255-y/2)*256+x/2)*4,dst=(y*512+x)*4; image[dst]=readback[src+2];image[dst+1]=readback[src+1];image[dst+2]=readback[src];image[dst+3]=0;}
   if(k==0) save_draw("GPU-X11",0); XMoveWindow(xd,w,(k%10)*8,80); XPutImage(xd,w,gc,xi,0,0,0,0,512,512);XFlush(xd);usleep(100000);
  }
  char cnt[16];uintstr(severe,cnt);say("KGSL_X11_FRAMES=300 SEVERE=");say(cnt);say("\nKGSL_X11_GPU_COMPLETE\n");return severe?30:0;
 }
 if(solid)rc=measured("S0",4);
 else {rc=measured("S1c",24);if(!rc){glBindBuffer(GL_ARRAY_BUFFER,b);glBufferSubData(GL_ARRAY_BUFFER,24,sizeof(uv),uv);rc=measured("S1",32);}}
 eglMakeCurrent(d,0,0,0);eglDestroyContext(d,ctx);eglTerminate(d);
 return rc;
}
