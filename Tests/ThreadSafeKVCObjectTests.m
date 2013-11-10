#import <Kiwi/Kiwi.h>
#import "ThreadSafeKVCObject.h"

@interface ThreadSafeClass : ThreadSafeKVCObject
@property NSString *property1;
@property NSNumber *property2;
@end

@implementation ThreadSafeClass
@dynamic property1,
         property2;
@end

SPEC_BEGIN(ThreadSafeKVCObjectSpecs)

describe(@"ThreadSafeKVCObject", ^{
    describe(@"Properties", ^{
        it(@"should dynamically synthesize properties implementations", ^{
            ThreadSafeClass *clazz = [ThreadSafeClass new];

            clazz.property1 = @"Blip!";
            clazz.property2 = @(YES);

            [[clazz.property1 should] equal:@"Blip!"];
            [[clazz.property2 should] equal:@(YES)];
        });
    });

    describe(@"Transactional access", ^{
        specify(^{
            ThreadSafeClass *clazz = [ThreadSafeClass new];

            [clazz writeAccess:^(ThreadSafeClass *clazz) {
                clazz.property1 = @"Blip!";
                clazz.property2 = @(YES);
            }];

            [clazz readAccess:^(ThreadSafeClass *clazz) {
                [[clazz.property1 should] equal:@"Blip!"];
                [[clazz.property2 should] equal:@(YES)];
            }];
        });
    });
});

SPEC_END
