#import <Kiwi/Kiwi.h>
#import "ThreadSafeKVCObject.h"

@interface ThreadSafeKVOClass : ThreadSafeKVCObject

@property NSString *property1;
@property NSNumber *property2;

@property BOOL observationWasMade;

@end

@implementation ThreadSafeKVOClass

@dynamic property1,
         property2;

- (instancetype)init {
    self = [super init];

    if (self == nil) return nil;

    self.observationWasMade = NO;

    [self addObserver:self forKeyPath:@"property1" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:NULL];

    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"property1"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"property1"]) {
        self.observationWasMade = YES;
    }
}

@end

SPEC_BEGIN(ThreadSafeKVCObject_KVO_Specs)

describe(@"ThreadSafeKVCObject", ^{
    describe(@"Properties", ^{
        it(@"should dynamically synthesize properties implementations", ^{
            ThreadSafeKVOClass *clazz = [ThreadSafeKVOClass new];

            [[theValue(clazz.observationWasMade) should] beNo];

            clazz.property1 = @"Blip!";

            [[theValue(clazz.observationWasMade) should] beYes];
        });
    });
});

SPEC_END
