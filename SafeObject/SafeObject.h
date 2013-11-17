// SafeObject
//
// SafeObject/SafeObject.h
//
// Copyright (c) 2013 Stanislaw Pankevich
// Released under the MIT license

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

@interface SafeObject : MTLModel

- (void)readAccess:(void (^)(id))accessBlock;
- (void)writeAccess:(void(^)(id))accessBlock;
- (void)readWriteAccess:(void(^)(id))accessBlock;

@end
