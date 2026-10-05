/* Convert Sony's legacy clearpad MT slot zero to a single Xorg pointer.
 * Diagnostic userspace adapter; physical device and kernel stay unchanged. */
#include <linux/input.h>
#include <linux/uinput.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
static void emit(int fd,unsigned short t,unsigned short c,int v){struct input_event e={0};e.type=t;e.code=c;e.value=v;if(write(fd,&e,sizeof(e))!=sizeof(e))perror("uinput write");}
int main(int argc,char**argv){
 if(argc!=2)return 2;
 int in=open(argv[1],O_RDONLY),out=open("/dev/uinput",O_WRONLY);
 if(in<0||out<0){perror("input open");return 3;}
 ioctl(out,UI_SET_EVBIT,EV_KEY);ioctl(out,UI_SET_KEYBIT,BTN_LEFT);
 ioctl(out,UI_SET_EVBIT,EV_ABS);ioctl(out,UI_SET_ABSBIT,ABS_X);ioctl(out,UI_SET_ABSBIT,ABS_Y);
 struct uinput_user_dev u={0};strcpy(u.name,"Hikari touch pointer");u.id.bustype=BUS_VIRTUAL;
 u.absmax[ABS_X]=719;u.absmax[ABS_Y]=1279;
 if(write(out,&u,sizeof(u))!=sizeof(u)||ioctl(out,UI_DEV_CREATE)<0){perror("uinput create");return 4;}
 fprintf(stderr,"HIKARI_TOUCH_ADAPTER_READY source=%s event_size=%zu\n",argv[1],sizeof(struct input_event));fflush(stderr);
 int slot=0,x=0,y=0,active=0,dirty=0;struct input_event e;
 while(read(in,&e,sizeof(e))==sizeof(e)){
  if(e.type==EV_ABS){if(e.code==ABS_MT_SLOT)slot=e.value;else if(slot==0){
   if(e.code==ABS_MT_POSITION_X){x=e.value;dirty=1;}
   if(e.code==ABS_MT_POSITION_Y){y=e.value;dirty=1;}
   if(e.code==ABS_MT_TRACKING_ID){active=e.value>=0;dirty=1;}
  }}
  if(e.type==EV_SYN&&e.code==SYN_REPORT&&dirty){emit(out,EV_ABS,ABS_X,x);emit(out,EV_ABS,ABS_Y,y>1279?1279:y);emit(out,EV_KEY,BTN_LEFT,active);emit(out,EV_SYN,SYN_REPORT,0);dirty=0;}
 }
 ioctl(out,UI_DEV_DESTROY);return 0;
}
