#import <XCTest/XCTest.h>
#import "SafeObject.h"

@interface SafeObjectKVCTestClass : SafeObject
@property NSString *property1;
@property NSNumber *property2;
@end

@implementation SafeObjectKVCTestClass
@dynamic property1,
         property2;
@end


@interface SafeObjectKVCTests : XCTestCase

@end

@implementation SafeObjectKVCTests

- (void)testKVC {
    SafeObjectKVCTestClass *clazz = [SafeObjectKVCTestClass new];

    clazz.property1 = @"Blip!";
    clazz.property2 = @(YES);

    XCTAssertTrue([clazz.property1 isEqualToString:@"Blip!"], @"");
    XCTAssertTrue(clazz.property2, @"");
}

- (void)testTransactionKVC {
    SafeObjectKVCTestClass *clazz = [SafeObjectKVCTestClass new];

    [clazz writeAccess:^(SafeObjectKVCTestClass *clazz) {
        clazz.property1 = @"Blip!";
        clazz.property2 = @(YES);
    }];

    __block id property1value;
    __block id property2value;

    [clazz readAccess:^(SafeObjectKVCTestClass *clazz) {
        property1value = clazz.property1;
        property2value = clazz.property2;
    }];

    XCTAssertTrue([clazz.property1 isEqualToString:@"Blip!"], @"");
    XCTAssertTrue(clazz.property2, @"");
}

@end
