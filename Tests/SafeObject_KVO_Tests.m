#import <XCTest/XCTest.h>
#import "SafeObject.h"

@interface SafeObjectKVOTestClass : SafeObject

@property NSString *property1;
@property NSNumber *property2;

@property BOOL observationWasMade;

@end

@implementation SafeObjectKVOTestClass

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


@interface SafeObjectKVOTests : XCTestCase

@end

@implementation SafeObjectKVOTests

- (void)testKVO {
    SafeObjectKVOTestClass *clazz = [SafeObjectKVOTestClass new];

    XCTAssertFalse(clazz.observationWasMade, @"");

    clazz.property1 = @"Blip!";

    XCTAssertTrue(clazz.observationWasMade, @"");
}

@end
