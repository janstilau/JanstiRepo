//
//  MCPriorityQueue.m
//  MCPriorityQueue
//
//  Created by JustinLau on 2019/6/27.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "MCPriorityQueue.h"

@interface MCPriorityQueue()

@property (nonatomic, strong) NSMutableArray *datas;
@property (nonatomic, assign) MCPriorityQueueCategory category;

@end

@implementation MCPriorityQueue

#pragma mark - init

static const int kDefaultCapacity = 10;

- (instancetype)init {
    return [self initWithCategory:MCPriorityQueueCategoryMax];
}

- (instancetype)initWithCategory:(MCPriorityQueueCategory)aCategory {
    self = [super init];
    if (self) {
        _datas = [NSMutableArray arrayWithCapacity:kDefaultCapacity + 1];
        _datas[0] = [NSNull null];
        _category = aCategory;
    }
    return self;
}

#pragma mark - Public

- (NSUInteger)size {
    return _datas.count - 1;
}
- (BOOL)empty {
    return [self size] == 0;
}

- (void)push:(id)anObject {
    [_datas addObject:anObject];
    [self heapifyFromEnd];
}

- (id)top {
    if (self.empty) { return nil; }
    return _datas[1];
}

- (id)pop {
    if (self.empty) { return nil; }
    id result = _datas[1];
    [_datas exchangeObjectAtIndex:1 withObjectAtIndex:_datas.count-1];
    [_datas removeLastObject];
    [self heapifyFromRoot];
    return result;
}

- (NSArray *)allElements {
    if (self.empty) { return @[]; }
    return [_datas subarrayWithRange:NSMakeRange(1, _datas.count-1)];
}

- (void)clear {
    [_datas removeAllObjects];
    [_datas addObject:[NSNull null]];
}

#pragma mark - Heapify

// Same will be exchanged because normally the lastest item should put on the top.
- (BOOL)needExchange:(NSComparisonResult)comapreResult {
    if (_category == MCPriorityQueueCategoryMax &&
        comapreResult != NSOrderedDescending) {
        return YES;
    } else if (_category == MCPriorityQueueCategoryMin &&
               comapreResult != NSOrderedAscending) {
        return YES;
    }
    return NO;
}

- (void)heapifyFromEnd {
    if (_datas.count <= 1) { return; }
    NSUInteger index = _datas.count - 1;
    while (index > 1) {
        NSUInteger fatherIndex = index / 2;
        NSComparisonResult result = [_datas[fatherIndex] compare:_datas[index]];
        if ([self needExchange:result]) {
            [_datas exchangeObjectAtIndex:index withObjectAtIndex:fatherIndex];
            index = fatherIndex;
        } else {
            return;
        }
    }
}

- (void)heapifyFromRoot {
    if (_datas.count <= 1) { return; }
    NSUInteger index = 1;
    while (index < _datas.count) {
        NSUInteger targetSubIndex = 0;
        NSUInteger leftSubIndex = index*2;
        if (leftSubIndex >= _datas.count) { return; }
        NSUInteger rightSubIndex = index*2+1;
        if (rightSubIndex >= _datas.count) {
            targetSubIndex = leftSubIndex;
        } else {
            NSComparisonResult result = [_datas[leftSubIndex] compare:_datas[rightSubIndex]];
            if (_category == MCPriorityQueueCategoryMax) {
                if (result == NSOrderedAscending) {
                    targetSubIndex = rightSubIndex;
                } else {
                    targetSubIndex = leftSubIndex;
                }
            } else {
                if (result == NSOrderedDescending) {
                    targetSubIndex = rightSubIndex;
                } else {
                    targetSubIndex = leftSubIndex;
                }
            }
        }
        
        NSComparisonResult compareResult = [_datas[index] compare:_datas[targetSubIndex]];
        if ([self needExchange:compareResult]) {
            [_datas exchangeObjectAtIndex:index withObjectAtIndex:targetSubIndex];
            index = targetSubIndex;
        } else {
            return;
        }
    }
}

@end
