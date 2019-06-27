//
//  MCPriorityQueue.h
//  MCPriorityQueue
//
//  Created by JustinLau on 2019/6/27.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MCPriorityQueueCategory) {
    MCPriorityQueueCategoryMax = 0,
    MCPriorityQueueCategoryMin = 1,
};

@interface MCPriorityQueue: NSObject

@property (nonatomic, assign, readonly) BOOL empty;
@property (nonatomic, assign, readonly) NSUInteger size;

- (instancetype)initWithCategory:(MCPriorityQueueCategory)aCategory NS_DESIGNATED_INITIALIZER;
- (void)push:(id)anObject;
- (id)pop;
- (id)top;
- (void)clear;
- (NSArray *)allElements;

@end

NS_ASSUME_NONNULL_END
