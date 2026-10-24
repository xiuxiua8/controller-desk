#import "../Sources/HIDBridge.h"
int main(int argc,const char **argv) { @autoreleasepool {
    HIDBridge *bridge=[HIDBridge new]; [bridge start];
    [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:argc>2?atoi(argv[2]):6]];
    NSArray *snapshots=[bridge snapshots];
    NSData *data=[NSJSONSerialization dataWithJSONObject:snapshots options:NSJSONWritingPrettyPrinted error:NULL];
    if(argc>1) [data writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
    for(NSDictionary *s in snapshots) printf("%s: samples=%ld body=#%06x buttons=#%06x colorRead=%s\n",[s[@"name"] UTF8String],[s[@"count"] longValue],[s[@"bodyColor"] intValue],[s[@"buttonColor"] intValue],[s[@"hasColor"] boolValue]?"yes":"no");
    [bridge stop];
    return snapshots.count?0:2;
} }
