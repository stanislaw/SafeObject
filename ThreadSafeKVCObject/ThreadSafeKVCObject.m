// ThreadSafeKVCObject
//
// ThreadSafeKVCObject/ThreadSafeKVCObject.h
//
// Copyright (c) 2013 Stanislaw Pankevich
// Released under the MIT license

#import "ThreadSafeKVCObject.h"

#import <objc/runtime.h>

@interface ThreadSafeKVCObject () {
    dispatch_queue_t _isolationQueue;
    NSMutableDictionary *_properties;
}

- (NSMutableDictionary *)properties;

- (void)_readAccess:(void (^)(id))accessBlock;
- (void)_readWriteAccess:(void(^)(id))accessBlock;
- (void)_writeAccess:(void(^)(id))accessBlock;

@end

static NSString * const ThreadSafeKVCObjectKey = @"ThreadSafeKVCObjectTransactionKey";

@implementation ThreadSafeKVCObject

-(id)init {
    self = [super init];

    if (self == nil) return nil;

    NSString *queueName = [NSString stringWithFormat:@"com.%@.isolationqueue", NSStringFromClass([self class])];

    [self setIsolationQueue:dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT)];

    _properties = [NSMutableDictionary new];

    return self;
}

- (void)dealloc {
    _properties = nil;
    [self setIsolationQueue:nil];
}

- (NSMutableDictionary *)properties {
    return _properties;
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
        [[self properties] setValue:value forKey:key];
    }];
}

+ (BOOL)resolveInstanceMethod:(SEL)aSEL {
    NSMutableString *key = [NSStringFromSelector(aSEL) mutableCopy];

    if ([NSStringFromSelector(aSEL) hasPrefix:@"set"]) {
        // delete "set" and ":" and lowercase first letter
        [key deleteCharactersInRange:NSMakeRange(0, 3)];
        [key deleteCharactersInRange:NSMakeRange([key length] - 1, 1)];

        NSString *firstChar = [key substringToIndex:1];
        [key replaceCharactersInRange:NSMakeRange(0, 1) withString:[firstChar lowercaseString]];

        if ([[[self class] propertyKeys] containsObject:key] == NO) {
            return NO;
        }

        class_addMethod([self class], aSEL, (IMP)setPropertyIMP, "v@:@");
    } else {
        if ([[[self class] propertyKeys] containsObject:key] == NO) {
            return NO;
        }

        class_addMethod([self class], aSEL,(IMP)propertyIMP, "@@:");
    }

    return YES;
}

#pragma mark
#pragma mark Public API: Transactional access

- (void)readAccess:(void (^)(id))accessBlock {
    dispatch_sync(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:ThreadSafeKVCObjectKey];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:ThreadSafeKVCObjectKey];
    });
}

- (void)readWriteAccess:(void(^)(id))accessBlock {
    dispatch_barrier_sync(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:ThreadSafeKVCObjectKey];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:ThreadSafeKVCObjectKey];
    });
}

- (void)writeAccess:(void(^)(id))accessBlock {
    dispatch_barrier_async(_isolationQueue, ^{
        [[NSThread currentThread].threadDictionary setValue:@(YES) forKey:ThreadSafeKVCObjectKey];

        accessBlock(self);

        [[NSThread currentThread].threadDictionary setValue:nil forKey:ThreadSafeKVCObjectKey];
    });
}

#pragma mark
#pragma mark Private API (level 0)

- (void)_readAccess:(void (^)(id))accessBlock {
    if ([[NSThread currentThread].threadDictionary valueForKey:ThreadSafeKVCObjectKey]) {
        accessBlock(self);
    } else {
        dispatch_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)_readWriteAccess:(void(^)(id))accessBlock {
    if ([[NSThread currentThread].threadDictionary valueForKey:ThreadSafeKVCObjectKey]) {
        accessBlock(self);
    } else {
        dispatch_barrier_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)_writeAccess:(void(^)(id))accessBlock {
    if ([[NSThread currentThread].threadDictionary valueForKey:ThreadSafeKVCObjectKey]) {
        accessBlock(self);
    } else {
        dispatch_barrier_async(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

@end
