/* Select the documented ARGB fbdev format, keeping geometry/timings intact.
 * Sony's RGBA red mask is outside Xorg depth24's valid plane mask. */
#include <linux/fb.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
int main(int argc,char**argv){
 int fd=open("/dev/fb0",O_RDWR);struct fb_var_screeninfo v;
 if(fd<0||ioctl(fd,FBIOGET_VSCREENINFO,&v)<0){perror("fb get");return 1;}
 printf("fb: %ux%u bpp%u R%u/%u G%u/%u B%u/%u A%u/%u\n",v.xres,v.yres,v.bits_per_pixel,v.red.length,v.red.offset,v.green.length,v.green.offset,v.blue.length,v.blue.offset,v.transp.length,v.transp.offset);
 if(argc==2){
  v.bits_per_pixel=32;v.red=(struct fb_bitfield){16,8,0};v.green=(struct fb_bitfield){8,8,0};v.blue=(struct fb_bitfield){0,8,0};v.transp=(struct fb_bitfield){24,8,0};
  v.activate=!strcmp(argv[1],"--test")?FB_ACTIVATE_TEST:FB_ACTIVATE_NOW;
  if(strcmp(argv[1],"--test")&&strcmp(argv[1],"--set-argb"))return 2;
  if(ioctl(fd,FBIOPUT_VSCREENINFO,&v)<0){perror("fb put");return 3;}
  printf("ARGB %s OK\n",argv[1]);
 }
 close(fd);return 0;
}
