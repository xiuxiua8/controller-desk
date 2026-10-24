#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDManager.h>
@interface Capture:NSObject { @public uint8_t buffer[512]; IOHIDDeviceRef device; double last; }
@property NSString *address;
@property NSMutableArray *gaps;
@property NSMutableArray *edges;
@property NSMutableDictionary *reports;
@property NSArray *lastMotion;
@property uint32_t buttons;
@property double peakGyro;
@property int previousTimer;
@property NSMutableDictionary *timerDeltas;
@end
@implementation Capture
@end
static void receive(void *context,IOReturn result,void *sender,IOHIDReportType type,uint32_t rid,uint8_t *p,CFIndex n) {
    Capture *s=(__bridge Capture *)context;
    if(result) return;
    NSString *key=[NSString stringWithFormat:@"%02x/%ld",rid,(long)n]; s.reports[key]=@([s.reports[key] intValue]+1);
    if(rid!=0x30 || n<49) return;
    double now=NSProcessInfo.processInfo.systemUptime;
    if(s->last) { int delta=(p[1]-s.previousTimer)&255;NSString *key=[NSString stringWithFormat:@"%d",delta];s.timerDeltas[key]=@([s.timerDeltas[key] intValue]+1); } s.previousTimer=p[1];
    if(s->last) [s.gaps addObject:@((now-s->last)*1000)]; s->last=now;
    uint32_t buttons=p[3]|p[4]<<8|p[5]<<16;
    if(buttons!=s.buttons) { [s.edges addObject:@{@"time":@(now),@"bits":@(buttons)}]; s.buttons=buttons; }
    NSMutableArray *motion=[NSMutableArray array];
    for(int i=0;i<6;i++) { int16_t value=p[37+2*i]|p[38+2*i]<<8; [motion addObject:@(value)]; if(i>=3) s.peakGyro=fmax(s.peakGyro,abs(value)); }
    s.lastMotion=motion;
}
int main(int argc,const char **argv) { @autoreleasepool {
    IOHIDManagerRef manager=IOHIDManagerCreate(kCFAllocatorDefault,0);
    IOHIDManagerSetDeviceMatching(manager,(__bridge CFDictionaryRef)@{@kIOHIDVendorIDKey:@0x057e});
    NSSet *devices=(__bridge_transfer NSSet *)IOHIDManagerCopyDevices(manager);
    NSMutableArray *captures=[NSMutableArray array];
    for(id item in devices) {
        IOHIDDeviceRef device=(__bridge IOHIDDeviceRef)item;
        Capture *s=[Capture new]; s->device=device; s.address=(__bridge id)IOHIDDeviceGetProperty(device,CFSTR(kIOHIDSerialNumberKey))?:@"unknown";
        if(argc>3 && [s.address caseInsensitiveCompare:[NSString stringWithUTF8String:argv[3]]]!=NSOrderedSame) continue;
        s.timerDeltas=[NSMutableDictionary dictionary];s.reports=[NSMutableDictionary dictionary];s.gaps=[NSMutableArray array];s.edges=[NSMutableArray array];
        IOOptionBits options=argc>4 && strcmp(argv[4],"seize")==0 ? kIOHIDOptionsTypeSeizeDevice:0;
        IOReturn opened=IOHIDDeviceOpen(device,options); if(opened) { printf("open result=%x\n",opened);continue; }
        [captures addObject:s];
        IOHIDDeviceRegisterInputReportCallback(device,s->buffer,sizeof s->buffer,receive,(__bridge void *)s);
        IOHIDDeviceScheduleWithRunLoop(device,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);
    }
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:argc>2?atoi(argv[2]):25]];
    NSMutableArray *output=[NSMutableArray array];
    for(Capture *s in captures) {
        NSArray *gaps=[s.gaps sortedArrayUsingSelector:@selector(compare:)]; NSUInteger n=gaps.count;
        NSDictionary *row=@{@"address":s.address,@"reports":s.reports,@"timerDeltas":s.timerDeltas,@"motionRaw":s.lastMotion?:@[],@"gyroPeakRaw":@(s.peakGyro),@"edges":s.edges,
            @"medianGapMs":n?gaps[n/2]:@0,@"p95GapMs":n?gaps[(NSUInteger)(n*.95)]:@0,@"maxGapMs":gaps.lastObject?:@0};
        [output addObject:row];
        printf("%s reports=%s median=%.1fms p95=%.1fms gyroPeak=%.0f\n",[s.address UTF8String],[s.reports.description UTF8String],n?[gaps[n/2] doubleValue]:0,n?[gaps[(NSUInteger)(n*.95)] doubleValue]:0,s.peakGyro);
        IOHIDDeviceUnscheduleFromRunLoop(s->device,CFRunLoopGetCurrent(),kCFRunLoopDefaultMode);IOHIDDeviceClose(s->device,0);
    }
    if(argc>1) [[NSJSONSerialization dataWithJSONObject:output options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
    CFRelease(manager);
} return 0; }
