#import "../Sources/HIDBridge.m"
#include <assert.h>
int main(void) { @autoreleasepool {
    PadHID *s=[PadHID new]; s->live=YES; s->right=YES; s->buttons=[NSMutableSet set];
    s.calibration=@"default";
    for(int i=0;i<3;i++) { s->accScale[i]=1./4096; s->gyroScale[i]=0.1; s->gyroOrigin[i]=10; }
    for(int i=0;i<2;i++) { s->center[i]=2048; s->below[i]=s->above[i]=1024; }
    uint8_t p[49]={0}; p[0]=0x30; p[2]=0x80; p[3]=8|128; p[4]=2;
    p[9]=0; p[10]=8; p[11]=128;
    for(int k=0;k<3;k++) { p[13+12*k]=0; p[14+12*k]=16; p[19+12*k]=110; p[21+12*k]=210; p[23+12*k]=54; p[24+12*k]=1; }
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x30,p,48);
    assert(s->count==0);
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x30,p,49);
    assert(s->count==3 && s->battery==100);
    assert([s->buttons containsObject:@"A"] && [s->buttons containsObject:@"ZR"] && [s->buttons containsObject:@"+"]);
    assert(fabs(s->gyro[0]-10)<0.001 && fabs(s->gyro[1]+20)<0.001 && fabs(s->gyro[2]+30)<0.001);
    assert(s->acc[0]==1 && s->acc[1]==0 && s->acc[2]==0);
    assert(s->stick[0]==0 && s->stick[1]==0);
    p[3]=0; p[4]=0;
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x30,p,49);
    assert(s->buttons.count==0);
    // A live button report with an empty IMU payload must not look like live motion.
    uint64_t motionCount=s->count, inputs=s->reportCount;
    double motionTime=s->motionLast;
    memset(p+13,0,36); p[3]=8;
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x30,p,49);
    assert(s->reportCount==inputs+1 && s->count==motionCount && s->motionLast==motionTime);
    assert([s->buttons containsObject:@"A"]);
    uint8_t color[32]={0}; color[0]=0x21; color[13]=0x80; color[14]=0x10;
    color[15]=0x50; color[16]=0x60; color[19]=12;
    color[20]=0xf0; color[21]=0x46; color[22]=0x14;
    color[23]=0x1e; color[24]=0x19; color[25]=0x14;
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x21,color,25);
    assert(!s->hasColor);
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x21,color,32);
    assert(s->hasColor && s->bodyColor==0xf04614 && s->buttonColor==0x1e1914);
    memset(color+20,0xff,12);
    report((__bridge void *)s,0,NULL,kIOHIDReportTypeInput,0x21,color,32);
    assert(s->bodyColor==0xf04614);
    s->live=NO;
    puts("PASS HID bounds, buttons, release, battery, sticks, IMU samples, right-hand signs, gyro bias, actual RGB color format, truncated and erased SPI data");
} return 0; }
