//
//  ThreadSafeKVCObject.m
//  aaah
//
//  Created by Stanislaw Pankevich on 10/11/13.
//  Copyright (c) 2013 IProjecting. All rights reserved.
//

#import "ThreadSafeKVCObject.h"

#import <objc/runtime.h>

@interface ThreadSafeKVCObject () {
    dispatch_queue_t _isolationQueue;
    NSUInteger _isolationHash;
}

@property NSMutableDictionary *properties;

- (void)_readAccess:(void (^)(id))accessBlock;
- (void)_readWriteAccess:(void(^)(id))accessBlock;
- (void)_writeAccess:(void(^)(id))accessBlock;

@end

@implementation ThreadSafeKVCObject

-(id)init {
    self = [super init];

    if (self == nil) return nil;

    NSString *queueName = [NSString stringWithFormat:@"com.%@.isolationqueue", NSStringFromClass([self class])];

    [self setIsolationQueue:dispatch_queue_create([queueName UTF8String], DISPATCH_QUEUE_CONCURRENT)];

    self.properties = [NSMutableDictionary new];
    _isolationHash = NSNotFound;

    return self;
}

- (void)dealloc {
    _properties = nil;
    [self setIsolationQueue:nil];
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
        accessBlock(self);
    });
}

- (void)readWriteAccess:(void(^)(id))accessBlock {
    dispatch_barrier_sync(_isolationQueue, ^{
        _isolationHash = [NSThread currentThread].hash;

        accessBlock(self);

        _isolationHash = NSNotFound;
    });
}

- (void)writeAccess:(void(^)(id))accessBlock {
    dispatch_barrier_async(_isolationQueue, ^{
        _isolationHash = [NSThread currentThread].hash;

        accessBlock(self);

        _isolationHash = NSNotFound;
    });
}

#pragma mark
#pragma mark Private API (level 0)

- (void)_readAccess:(void (^)(id))accessBlock {
    if (_isolationHash == [NSThread currentThread].hash) {
        accessBlock(self);
    } else {
        dispatch_sync(_isolationQueue, ^{
            accessBlock(self);
        });
    }
}

- (void)_readWriteAccess:(void(^)(id))accessBlock {
    if (_isolationHash == [NSThread currentThread].hash) {
        accessBlock(self);
    } else {
        dispatch_barrier_sync(_isolationQueue, ^{
            _isolationHash = [NSThread currentThread].hash;

            accessBlock(self);

            _isolationHash = NSNotFound;
        });
    }
}

- (void)_writeAccess:(void(^)(id))accessBlock {
    if (_isolationHash == [NSThread currentThread].hash) {
        accessBlock(self);
    } else {
        dispatch_barrier_async(_isolationQueue, ^{
            _isolationHash = [NSThread currentThread].hash;

            accessBlock(self);

            _isolationHash = NSNotFound;
        });
    }
}

@end
