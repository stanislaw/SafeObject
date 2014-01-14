// SafeObject
//
// SafeObject/SafeObject.m
//
// Copyright (c) 2013 Stanislaw Pankevich
// Released under the MIT license

#import "SafeObject.h"

#import <objc/runtime.h>

@interface SafeObject () {
    dispatch_queue_t _isolationQueue;
    NSMutableDictionary *_properties;
}

- (NSMutableDictionary *)properties;

@end

static const void * const SafeObjectKey = &SafeObjectKey;

@implementation SafeObject

-(id)init {
    self = [super init];

    if (self == nil) return nil;

    NSString *queueName = [NSString stringWithFormat:@"com.%@.isolationqueue", NSStringFromClass([self class])];

    _isolationQueue = dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT);
    dispatch_queue_set_specific(_isolationQueue, SafeObjectKey, (__bridge void *)(_isolationQueue), NULL);

    _properties = [NSMutableDictionary new];

    return self;
}

- (void)dealloc {
    _properties = nil;
    _isolationQueue = nil;
}

- (NSMutableDictionary *)properties {
    return _properties;
}

#pragma mark
#pragma mark Dynamic properties

static id propertyIMP(id self, SEL _cmd) {
    __block id value;

    [self readAccess:^(id object) {
        value = [[self properties] valueForKey:NSStringFromSelector(_cmd)];
    }];

    return value;
}

static void setPropertyIMP(id self, SEL _cmd, id aValue) {
    id value = [aValue copy];
    NSMutableString *key = [NSStringFromSelector(_cmd) mutableCopy];

    // delete "set" and ":" and lowercase first letter
    [key deleteCharactersInRange:NSMakeRange(0, 3)];
    [key deleteCharactersInRange:NSMakeRange([key length] - 1, 1)];

    NSString *firstChar = [key substringToIndex:1];
    [key replaceCharactersInRange:NSMakeRange(0, 1) withString:[firstChar lowercaseString]];

    [self writeAccess:^(id object) {
        id oldValue = [self valueForKey:key];

        if ([oldValue isEqual:value] == NO) {
            [self willChangeValueForKey:key];
            [[self properties] setValue:value forKey:key];
            [self didChangeValueForKey:key];
        }
    }];
}

+ (BOOL)resolveInstanceMethod:(SEL)aSEL {
    NSMutableString *key = [NSStringFromSelector(aSEL) mutableCopy];

    if ([key hasPrefix:@"set"] && [key hasSuffix:@":"]) {
        [key deleteCharactersInRange:NSMakeRange(0, 3)];
        [key deleteCharactersInRange:NSMakeRange([key length] - 1, 1)];

        NSString *firstChar = [key substringToIndex:1];
        [key replaceCharactersInRange:NSMakeRange(0, 1) withString:[firstChar lowercaseString]];

        if ([[[self class] propertyKeys] containsObject:key]) {
            class_addMethod([self class], aSEL, (IMP)setPropertyIMP, "v@:@");
            return YES;
        }
    } else {
        if ([[[self class] propertyKeys] containsObject:key]) {
            class_addMethod([self class], aSEL,(IMP)propertyIMP, "@@:");
            return YES;
        }
    }

    return [super resolveInstanceMethod:aSEL];
}

#pragma mark
#pragma mark Public API: Transactional access

- (void)readAccess:(void (^)(id))accessBlock {
    if (dispatch_get_specific(SafeObjectKey) == (__bridge void *)(_isolationQueue)) {
        accessBlock(self);
    }

    else {
        dispatch_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)readWriteAccess:(void(^)(id))accessBlock {
    if (dispatch_get_specific(SafeObjectKey) == (__bridge void *)(_isolationQueue)) {
        accessBlock(self);
    }

    else {
        dispatch_barrier_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)writeAccess:(void(^)(id))accessBlock {
    if (dispatch_get_specific(SafeObjectKey) == (__bridge void *)(_isolationQueue)) {
        accessBlock(self);
    }

    else {
        dispatch_barrier_async(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

@end
