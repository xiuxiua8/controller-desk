#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface HIDBridge : NSObject
- (void)start;
- (void)stop;
- (NSArray<NSDictionary *> *)snapshots;
@end
NS_ASSUME_NONNULL_END
