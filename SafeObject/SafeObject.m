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
    NSString *_safeObjectKey;
}

- (NSMutableDictionary *)properties;
- (NSString *)safeObjectKey;

- (void)_readAccess:(void (^)(id))accessBlock;
- (void)_writeAccess:(void(^)(id))accessBlock;

@end

@implementation SafeObject

-(id)init {
    self = [super init];

    if (self == nil) return nil;

    NSString *queueName = [NSString stringWithFormat:@"com.%@.isolationqueue", NSStringFromClass([self class])];

    [self setIsolationQueue:dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT)];

    _properties = [NSMutableDictionary new];
    _safeObjectKey = [NSString stringWithFormat:@"SafeObjectKey%u", (NSUInteger)self];

    return self;
}

- (void)dealloc {
    _properties = nil;
    [self setIsolationQueue:nil];
}

- (NSMutableDictionary *)properties {
    return _properties;
}

- (NSString *)safeObjectKey {
    return _safeObjectKey;
}

#pragma mark
#pragma mark Isolation queue

- (void)setIsolationQueue:(dispatch_queue_t)isolationQueue {
#if !OS_OBJECT_USE_OBJC
    if (_isolationQueue) dispatch_release(_isolationQueue);

    if (isolationQueue) {
        dispatch_retain(isolationQueue);
    }
#endif

    _isolationQueue = isolationQueue;
}

#pragma mark
#pragma mark Dynamic properties

static id propertyIMP(id self, SEL _cmd) {
    __block id value;

    [self _readAccess:^(id object) {
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

    [self _writeAccess:^(id object) {
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
    dispatch_sync(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:[self safeObjectKey]];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:[self safeObjectKey]];
    });
}

- (void)readWriteAccess:(void(^)(id))accessBlock {
    dispatch_barrier_sync(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:[self safeObjectKey]];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:[self safeObjectKey]];
    });
}

- (void)writeAccess:(void(^)(id))accessBlock {
    dispatch_barrier_async(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:[self safeObjectKey]];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:[self safeObjectKey]];
    });
}

#pragma mark
#pragma mark Private API (level 0)

- (void)_readAccess:(void (^)(id))accessBlock {
    if ([[NSThread currentThread].threadDictionary valueForKey:[self safeObjectKey]]) {
        accessBlock(self);
    } else {
        dispatch_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)_writeAccess:(void(^)(id))accessBlock {
    if ([[NSThread currentThread].threadDictionary valueForKey:[self safeObjectKey]]) {
        accessBlock(self);
    } else {
        dispatch_barrier_async(_isolationQueue, ^{
            [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:[self safeObjectKey]];

            accessBlock(self);

            [[NSThread currentThread].threadDictionary setValue:nil forKey:[self safeObjectKey]];
        });
    }
}

@end
