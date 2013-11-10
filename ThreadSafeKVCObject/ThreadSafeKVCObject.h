//
//  ThreadSafeKVCObject.h
//  aaah
//
//  Created by Stanislaw Pankevich on 10/11/13.
//  Copyright (c) 2013 IProjecting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Mantle/Mantle.h>

@interface ThreadSafeKVCObject : MTLModel

- (void)readAccess:(void (^)(id))accessBlock;
- (void)writeAccess:(void(^)(id))accessBlock;
- (void)readWriteAccess:(void(^)(id))accessBlock;

@end
