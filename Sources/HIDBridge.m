#import "HIDBridge.h"
#import <IOKit/hid/IOHIDManager.h>
#include <math.h>
#include <stdatomic.h>

static int16_t signed16(const uint8_t *p) { return (int16_t)(p[0] | p[1]<<8); }
static int packed12(const uint8_t *p, int axis) { return axis ? (p[1]>>4 | p[2]<<4) : (p[0] | (p[1]&15)<<8); }

@interface PadHID : NSObject {
@public
    IOHIDDeviceRef device;
    uint8_t buffer[512];
    uint8_t packet;
    atomic_bool live;
    BOOL right, userMotion, userStick;
    dispatch_queue_t inputQueue,outputQueue;
    double accScale[3], gyroScale[3], gyroOrigin[3];
    int center[2], below[2], above[2];
    double acc[3], gyro[3], stick[2];
    uint64_t count;
    uint64_t reportCount,windowCount;
    double windowStart,reportHz;
    NSTimeInterval last, startTime, motionLast;
    NSTimeInterval lastRequest;
    int battery;
    uint32_t bodyColor, buttonColor;
    BOOL hasColor;
    NSMutableSet<NSString *> *buttons;
}
@property NSString *address;
@property NSString *name;
@property NSString *calibration;
- (void)send:(uint8_t)command data:(const uint8_t *)data length:(size_t)length;
- (void)close;
@end
@implementation PadHID
- (void)send:(uint8_t)command data:(const uint8_t *)data length:(size_t)length {
    NSData *args=[NSData dataWithBytes:data length:MIN(length,38)];
    dispatch_async(outputQueue,^{
        if(!self->live) return;
        uint8_t out[49]={1,self->packet++&15,0,1,0x40,0x40,0,1,0x40,0x40,command};
        memcpy(out+11,args.bytes,args.length);
        IOHIDDeviceSetReport(self->device,kIOHIDReportTypeOutput,1,out,sizeof out);
    });
}
- (void)close {
    if (!live) return;
    live=NO;
    IOHIDDeviceCancel(device);
    IOHIDDeviceClose(device,kIOHIDOptionsTypeNone);
}
- (void)dealloc { [self close]; if(device) CFRelease(device); }
@end

static void motionCalibration(PadHID *s,const uint8_t *c,BOOL user) {
    if(s->userMotion && !user) return;
    for(int i=0;i<3;i++) {
        double ao=signed16(c+2*i), as=signed16(c+6+2*i);
        double go=signed16(c+12+2*i), gs=signed16(c+18+2*i);
        if(fabs(as-ao)<100 || fabs(gs-go)<100) return;
    }
    for(int i=0;i<3;i++) {
        double go=signed16(c+12+2*i), gs=signed16(c+18+2*i);
        s->accScale[i]=4.0/(signed16(c+6+2*i)-signed16(c+2*i));
        s->gyroScale[i]=936.0/(gs-go);
        s->gyroOrigin[i]=fabs(go)<1000 ? go : 0;
    }
    s->userMotion=user;
    s.calibration=user ? @"用户校准" : @"出厂校准";
}
static void stickCalibration(PadHID *s,const uint8_t *c,BOOL user) {
    if(s->userStick && !user) return;
    int ci=s->right?0:3, mi=s->right?3:6, ai=s->right?6:0;
    for(int i=0;i<2;i++) if(packed12(c+ci,i)<100 || packed12(c+mi,i)<100 || packed12(c+ai,i)<100) return;
    for(int i=0;i<2;i++) { s->center[i]=packed12(c+ci,i); s->below[i]=packed12(c+mi,i); s->above[i]=packed12(c+ai,i); }
    s->userStick=user;
}
static void report(void *context,IOReturn result,void *sender,IOHIDReportType type,uint32_t rid,uint8_t *p,CFIndex n) {
    PadHID *s=(__bridge PadHID *)context;
    if(result || !s->live) return;
    if(rid==0x21 && n>=20 && p[14]==0x10 && (p[13]&0x80)) {
        uint32_t addr=p[15]|p[16]<<8|p[17]<<16|p[18]<<24;
        if(n<20+p[19]) return;
        if(addr==0x6050 && p[19]>=6) {
            uint32_t body=p[20]<<16|p[21]<<8|p[22], buttons=p[23]<<16|p[24]<<8|p[25];
            // 0xffffff in both fields is an erased/unimplemented SPI region.
            if(!(body==0xffffff && buttons==0xffffff)) {
                s->bodyColor=body; s->buttonColor=buttons; s->hasColor=YES;
            }
        }
        if(addr==0x6020 && p[19]>=24) motionCalibration(s,p+20,NO);
        if(addr==0x8026 && p[19]>=26 && p[20]==0xb2 && p[21]==0xa1) motionCalibration(s,p+22,YES);
        if(addr==(s->right?0x6046:0x603d) && p[19]>=9) stickCalibration(s,p+20,NO);
        if(addr==(s->right?0x801b:0x8010) && p[19]>=11 && p[20]==0xb2 && p[21]==0xa1) stickCalibration(s,p+22,YES);
    }
    if(rid!=0x30 || n<49) return;
    s->last=NSProcessInfo.processInfo.systemUptime;
    s->reportCount++;s->windowCount++;
    if(!s->windowStart) s->windowStart=s->last;
    if(s->last-s->windowStart>=1) { s->reportHz=s->windowCount/(s->last-s->windowStart);s->windowCount=0;s->windowStart=s->last; }
    if(!s->startTime) s->startTime=s->last;
    s->battery=MIN(100,((p[2]>>4)&0xe)*100/8);
    [s->buttons removeAllObjects];
    NSDictionary *rightMap=@{@0:@"Y",@1:@"X",@2:@"B",@3:@"A",@4:@"SR",@5:@"SL",@6:@"R",@7:@"ZR"};
    NSDictionary *leftMap=@{@0:@"↓",@1:@"↑",@2:@"→",@3:@"←",@4:@"SR",@5:@"SL",@6:@"L",@7:@"ZL"};
    NSDictionary *map=s->right?rightMap:leftMap;
    uint8_t bits=p[s->right?3:5];
    for(NSNumber *bit in map) if(bits&(1<<bit.intValue)) {
        NSString *name=map[bit];
        if([name isEqual:@"SL"] || [name isEqual:@"SR"]) name=[name stringByAppendingString:s->right?@"-R":@"-L"];
        [s->buttons addObject:name];
    }
    if(p[4]&1) [s->buttons addObject:@"−"];
    if(p[4]&2) [s->buttons addObject:@"+"];
    if(p[4]&(s->right?4:8)) [s->buttons addObject:s->right?@"R3":@"L3"];
    if(p[4]&16) [s->buttons addObject:@"Home"];
    if(p[4]&32) [s->buttons addObject:@"Capture"];
    const uint8_t *st=p+(s->right?9:6);
    for(int i=0;i<2;i++) {
        double delta=packed12(st,i)-s->center[i];
        s->stick[i]=fmax(-1,fmin(1,delta/(delta<0?s->below[i]:s->above[i])));
    }
    for(int k=0;k<3;k++) {
        for(int i=0;i<3;i++) {
            double a=signed16(p+13+12*k+2*i)*s->accScale[i];
            double g=(signed16(p+19+12*k+2*i)-s->gyroOrigin[i])*s->gyroScale[i];
            // Common physical axes for both Joy-Con halves, in G and degrees per second.
            double sign=(s->right && i>0)?-1:1;
            s->acc[i]=a*sign; s->gyro[i]=g*sign;
        }
        if(fabs(s->acc[0])+fabs(s->acc[1])+fabs(s->acc[2])>0.01) {
            s->count++; s->motionLast=s->last;
        }
    }
}

@interface HIDBridge ()
@property NSMutableDictionary<NSValue *,PadHID *> *pads;
@property dispatch_queue_t inputQueue;
@end
static const char queueKey;
@implementation HIDBridge { IOHIDManagerRef _manager; dispatch_source_t _watchdog; }
- (instancetype)init {
    if((self=[super init])) {
        _pads=[NSMutableDictionary dictionary];
        _inputQueue=dispatch_queue_create("ControllerDesk.HID.input",dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL,QOS_CLASS_USER_INTERACTIVE,0));
        dispatch_queue_set_specific(_inputQueue,&queueKey,(__bridge void *)self,NULL);
    }
    return self;
}
static void added(void *context,IOReturn result,void *sender,IOHIDDeviceRef d) {
    HIDBridge *b=(__bridge HIDBridge *)context;
    NSValue *key=[NSValue valueWithPointer:d]; if(b.pads[key]) return;
    NSNumber *pid=(__bridge id)IOHIDDeviceGetProperty(d,CFSTR(kIOHIDProductIDKey));
    if(pid.intValue!=0x2006 && pid.intValue!=0x2007) return;
    PadHID *s=[PadHID new]; s->device=(IOHIDDeviceRef)CFRetain(d); s->right=pid.intValue==0x2007;
    s->inputQueue=b.inputQueue;
    s->outputQueue=dispatch_queue_create("ControllerDesk.HID.device-commands",DISPATCH_QUEUE_SERIAL);
    s.name=(__bridge id)IOHIDDeviceGetProperty(d,CFSTR(kIOHIDProductKey))?:@"Joy-Con";
    s.address=(__bridge id)IOHIDDeviceGetProperty(d,CFSTR(kIOHIDSerialNumberKey))?:@"";
    s.calibration=@"默认比例"; s->buttons=[NSMutableSet set];
    for(int i=0;i<3;i++) { s->accScale[i]=8./32768; s->gyroScale[i]=2000./32768; }
    for(int i=0;i<2;i++) { s->center[i]=2048; s->below[i]=s->above[i]=1400; }
    if(IOHIDDeviceOpen(d,kIOHIDOptionsTypeNone)) return;
    s->live=YES; b.pads[key]=s;
    s->lastRequest=NSProcessInfo.processInfo.systemUptime;
    IOHIDDeviceRegisterInputReportCallback(d,s->buffer,sizeof s->buffer,report,(__bridge void *)s);
    IOHIDDeviceSetDispatchQueue(d,b.inputQueue);
    void *keepAlive=(void *)CFBridgingRetain(s);
    IOHIDDeviceSetCancelHandler(d,^{ id held=CFBridgingRelease(keepAlive); (void)held; });
    IOHIDDeviceActivate(d);
    for(int i=0;i<7;i++) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(i+1)*250*NSEC_PER_MSEC),b.inputQueue,^{
        if(!s->live) return;
        if(i==0) { uint8_t a=1; [s send:0x40 data:&a length:1]; }
        else if(i==1) { uint8_t a=0x30; [s send:3 data:&a length:1]; }
        else {
            uint32_t addr=i==2?0x6020:i==3?0x8026:i==4?(s->right?0x6046:0x603d):i==5?(s->right?0x801b:0x8010):0x6050;
            uint8_t a[5]={addr&255,(addr>>8)&255,0,0,i==2?24:i==3?26:i==4?9:i==5?11:12};
            [s send:0x10 data:a length:5];
        }
    });
}
static void removed(void *context,IOReturn result,void *sender,IOHIDDeviceRef d) {
    HIDBridge *b=(__bridge HIDBridge *)context; NSValue *key=[NSValue valueWithPointer:d];
    [b.pads[key] close]; [b.pads removeObjectForKey:key];
}
- (void)start {
    if(_manager) return;
    _manager=IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDManagerOptionIndependentDevices);
    IOHIDManagerSetDeviceMatching(_manager,(__bridge CFDictionaryRef)@{@kIOHIDVendorIDKey:@0x057e});
    IOHIDManagerRegisterDeviceMatchingCallback(_manager,added,(__bridge void *)self);
    IOHIDManagerRegisterDeviceRemovalCallback(_manager,removed,(__bridge void *)self);
    IOHIDManagerSetDispatchQueue(_manager,_inputQueue);
    IOHIDManagerRef manager=_manager;
    IOHIDManagerSetCancelHandler(manager,^{CFRelease(manager);});
    IOHIDManagerOpen(_manager,kIOHIDOptionsTypeNone);
    IOHIDManagerActivate(_manager);
    __weak HIDBridge *weakSelf=self;
    _watchdog=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,_inputQueue);
    dispatch_source_set_timer(_watchdog,dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),2*NSEC_PER_SEC,100*NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_watchdog,^{
        HIDBridge *bridge=weakSelf; if(!bridge) return;
        double now=NSProcessInfo.processInfo.systemUptime;
        for(PadHID *s in bridge.pads.allValues) {
            // macOS may change report mode after combining Joy-Con halves. Restore full
            // reports only when an open device has stopped delivering real input.
            if(!s->live || (now-s->last<3 && now-s->motionLast<3) || now-s->lastRequest<6) continue;
            s->lastRequest=now;
            uint8_t enable=1; [s send:0x40 data:&enable length:1];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,250*NSEC_PER_MSEC),bridge.inputQueue,^{
                if(!s->live) return;
                uint8_t mode=0x30; [s send:3 data:&mode length:1];
            });
        }
    });
    dispatch_resume(_watchdog);
}
- (NSArray<NSDictionary *> *)snapshots {
    __block NSMutableArray *a;
    void (^copyState)(void)=^{
    a=[NSMutableArray array];
    for(PadHID *s in self.pads.allValues) [a addObject:@{
        @"address":s.address,@"name":s.name,@"right":@(s->right),@"last":@(s->last),@"count":@(s->count),
        @"motionLast":@(s->motionLast),
        @"reportCount":@(s->reportCount),@"reportHz":@(s->reportHz),
        @"battery":@(s->battery),@"calibration":s.calibration,@"buttons":s->buttons.allObjects,
        @"hasColor":@(s->hasColor),@"bodyColor":@(s->bodyColor),@"buttonColor":@(s->buttonColor),
        @"acc":@[@(s->acc[0]),@(s->acc[1]),@(s->acc[2])],@"gyro":@[@(s->gyro[0]),@(s->gyro[1]),@(s->gyro[2])],
        @"stick":@[@(s->stick[0]),@(s->stick[1])]
    }];
    };
    if(dispatch_get_specific(&queueKey)==(__bridge void *)self) copyState(); else dispatch_sync(_inputQueue,copyState);
    return a;
}
- (void)stop {
    __unsafe_unretained HIDBridge *bridge=self;
    void (^cleanup)(void)=^{
        if(bridge->_watchdog) { dispatch_source_cancel(bridge->_watchdog);bridge->_watchdog=nil; }
        for(PadHID *s in bridge.pads.allValues) [s close]; [bridge.pads removeAllObjects];
        if(bridge->_manager) { IOHIDManagerCancel(bridge->_manager);IOHIDManagerClose(bridge->_manager,0);bridge->_manager=NULL; }
    };
    if(dispatch_get_specific(&queueKey)==(__bridge void *)self) cleanup(); else dispatch_sync(_inputQueue,cleanup);
}
- (void)dealloc { [self stop]; }
@end
