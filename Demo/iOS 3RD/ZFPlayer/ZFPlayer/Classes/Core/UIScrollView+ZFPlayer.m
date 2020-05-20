#import "UIScrollView+ZFPlayer.h"
#import <objc/runtime.h>
#import "ZFReachabilityManager.h"
#import "ZFPlayer.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored"-Wdeprecated-declarations"

@interface UIScrollView ()

@property (nonatomic) CGFloat zf_lastOffsetY;
@property (nonatomic) CGFloat zf_lastOffsetX;
@property (nonatomic) ZFPlayerScrollDirection zf_scrollDirection;

@end

@implementation UIScrollView (ZFPlayer)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selectors[] = {
            @selector(setContentOffset:)
        };
        
        for (NSInteger index = 0; index < sizeof(selectors) / sizeof(SEL); ++index) {
            SEL originalSelector = selectors[index];
            SEL swizzledSelector = NSSelectorFromString([@"zf_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
            Method originalMethod = class_getInstanceMethod(self, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
            if (class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
                class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            } else {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    });
}

- (void)zf_setContentOffset:(CGPoint)contentOffset {
    if (self.zf_scrollViewDirection == ZFPlayerScrollViewDirectionVertical) {
        [self _findCorrectCellWhenScrollViewDirectionVertical:nil];
    } else {
        [self _findCorrectCellWhenScrollViewDirectionHorizontal:nil];
    }
    [self zf_setContentOffset:contentOffset];
}

#pragma mark - private method

/*
 当 ScrollView 完全停止的时候, 调用 zf_scrollViewDidEndScrollingCallback. 传入停止的位置应该播放的 IndexPath.
 */

- (void)_scrollViewDidStopScroll {
    @weakify(self)
    [self zf_findShouldPlayIndexWhenStopped:^(NSIndexPath * _Nonnull indexPath) {
        @strongify(self)
        if (self.zf_scrollViewDidEndScrollingCallback) self.zf_scrollViewDidEndScrollingCallback(indexPath);
    }];
}

- (void)zf_findShouldPlayIndexWhenStopped:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    if (!self.zf_shouldAutoPlay) return;
    @weakify(self)
    [self zf_findShouldPlayIndexWhenScrolling:^(NSIndexPath *indexPath) {
        @strongify(self)
        /// 如果当前控制器已经消失，直接return
        if (self.zf_hiddenOnWindow) return;
        // 如果,
        if ([ZFReachabilityManager sharedManager].isReachableViaWWAN && !self.zf_WWANAutoPlay) {
            /// 移动网络
            self.zf_shouldPlayIndexPath = indexPath;
            return;
        }
        if (handler) handler(indexPath);
        self.zf_playingIndexPath = indexPath;
    }];
}


// 这个方法, 就是计算出当前应该播放哪个 indexPath
- (void)zf_findShouldPlayIndexWhenScrolling:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    if (self.zf_scrollViewDirection == ZFPlayerScrollViewDirectionVertical) {
        [self _findCorrectCellWhenScrollViewDirectionVertical:handler];
    } else {
        [self _findCorrectCellWhenScrollViewDirectionHorizontal:handler];
    }
}


- (void)_scrollViewBeginDragging {
    if (self.zf_scrollViewDirection == ZFPlayerScrollViewDirectionVertical) {
        self.zf_lastOffsetY = self.contentOffset.y;
    } else {
        self.zf_lastOffsetX = self.contentOffset.x;
    }
}

#pragma mark - ScrollDidScroll

/*
 在 ScrollView 的滑动的过程中, 通过原来记录的 playingIndexPath 的值. 不断地计算, 在不同的时机, 调用回调
 
 zf_playerAppearingInScrollView
 zf_playerDisappearingInScrollView
 
 zf_playerWillAppearInScrollView
 zf_playerDidAppearInScrollView
 
 zf_playerWillDisappearInScrollView
 zf_playerDidDisappearInScrollView
 
 在该函数里面, 没有进行 shouldPlayIndex 的赋值操作. ShouldPlayIndex 的操作, 是放到了 setOffset 里面了.
 这样,
 */

- (void)zf_scrollViewDidScroll {
    if (self.zf_scrollViewDirection == ZFPlayerScrollViewDirectionVertical) {
        [self _scrollViewScrollingDirectionVertical];
    } else {
        [self _scrollViewScrollingDirectionHorizontal];
    }
}

/*
 _scrollViewScrollingDirectionVertical
 _scrollViewScrollingDirectionHorizontal
 这两个方法的基本思路就是, 计算出 palyerView 距离 ScrollView 的顶部, 底部的距离, 然后根据这个距离的正负,  判断 PlayerView 的位置的状态, 调用不同的回调.
 */

- (void)_scrollViewScrollingDirectionVertical {
    CGFloat offsetY = self.contentOffset.y;
    // 通过和上一次的比较, 记录滑动的方向.
    self.zf_scrollDirection = (offsetY - self.zf_lastOffsetY > 0) ? ZFPlayerScrollDirectionUp : ZFPlayerScrollDirectionDown;
    self.zf_lastOffsetY = offsetY;
    if (self.zf_stopPlay) return;
    
    // 这里, 根据 type 值的不同, 获取到 playerView 到底是 cell 上的, 还是 containerView 上的.
    UIView *playerView;
    if (self.zf_containerType == ZFPlayerContainerTypeCell) {
        // Avoid being paused the first time you play it.
        if (self.contentOffset.y < 0) return;
        if (!self.zf_playingIndexPath) return;
        
        UIView *cell = [self zf_getCellForIndexPath:self.zf_playingIndexPath];
        if (!cell) {
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            return;
        }
        playerView = [cell viewWithTag:self.zf_containerViewTag];
    } else if (self.zf_containerType == ZFPlayerContainerTypeView) {
        if (!self.zf_containerView) return;
        playerView = self.zf_containerView;
    }
    
    CGRect playFrameInScroll = [playerView convertRect:playerView.frame toView:self];
    CGRect playFrameInScrollSuperView = [self convertRect:playFrameInScroll toView:self.superview];
    /// playerView top to scrollView top space.
    CGFloat topSpacing = CGRectGetMinY(playFrameInScrollSuperView) - CGRectGetMinY(self.frame) - CGRectGetMinY(playerView.frame);
    /// playerView bottom to scrollView bottom space.
    CGFloat bottomSpacing = CGRectGetMaxY(self.frame) - CGRectGetMaxY(playFrameInScrollSuperView) + CGRectGetMinY(playerView.frame);
    /// The height of the content area.
    CGFloat contentInsetHeight = CGRectGetMaxY(self.frame) - CGRectGetMinY(self.frame);
    
    CGFloat playerDisapperaPercent = 0;
    CGFloat playerApperaPercent = 0;
    
    if (self.zf_scrollDirection == ZFPlayerScrollDirectionUp) { /// Scroll up
        /// Player is disappearing.
        if (topSpacing <= 0 && CGRectGetHeight(playFrameInScrollSuperView) != 0) {
            playerDisapperaPercent = -topSpacing/CGRectGetHeight(playFrameInScrollSuperView);
            if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
            if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
        }
        
        /// Top area
        if (topSpacing <= 0 && topSpacing > -CGRectGetHeight(playFrameInScrollSuperView)/2) {
            /// When the player will disappear.
            if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
        } else if (topSpacing <= -CGRectGetHeight(playFrameInScrollSuperView)) {
            /// When the player did disappeared.
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
        } else if (topSpacing > 0 && topSpacing <= contentInsetHeight) {
            /// Player is appearing.
            if (CGRectGetHeight(playFrameInScrollSuperView) != 0) {
                playerApperaPercent = -(topSpacing-contentInsetHeight)/CGRectGetHeight(playFrameInScrollSuperView);
                if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
            }
            /// In visable area
            if (topSpacing <= contentInsetHeight && topSpacing > contentInsetHeight-CGRectGetHeight(playFrameInScrollSuperView)/2) {
                /// When the player will appear.
                if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
            } else {
                /// When the player did appeared.
                if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
            }
        }
        
    } else if (self.zf_scrollDirection == ZFPlayerScrollDirectionDown) { /// Scroll Down
        /// Player is disappearing.
        if (bottomSpacing <= 0 && CGRectGetHeight(playFrameInScrollSuperView) != 0) {
            playerDisapperaPercent = -bottomSpacing/CGRectGetHeight(playFrameInScrollSuperView);
            if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
            if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
        }
        
        /// Bottom area
        if (bottomSpacing <= 0 && bottomSpacing > -CGRectGetHeight(playFrameInScrollSuperView)/2) {
            /// When the player will disappear.
            if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
        } else if (bottomSpacing <= -CGRectGetHeight(playFrameInScrollSuperView)) {
            /// When the player did disappeared.
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
        } else if (bottomSpacing > 0 && bottomSpacing <= contentInsetHeight) {
            /// Player is appearing.
            if (CGRectGetHeight(playFrameInScrollSuperView) != 0) {
                playerApperaPercent = -(bottomSpacing-contentInsetHeight)/CGRectGetHeight(playFrameInScrollSuperView);
                if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
            }
            /// In visable area
            if (bottomSpacing <= contentInsetHeight && bottomSpacing > contentInsetHeight-CGRectGetHeight(playFrameInScrollSuperView)/2) {
                /// When the player will appear.
                if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
            } else {
                /// When the player did appeared.
                if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
            }
        }
    }
}

/**
 The percentage of scrolling processed in horizontal scrolling.
 */
- (void)_scrollViewScrollingDirectionHorizontal {
    CGFloat offsetX = self.contentOffset.x;
    self.zf_scrollDirection = (offsetX - self.zf_lastOffsetX > 0) ? ZFPlayerScrollDirectionLeft : ZFPlayerScrollDirectionRight;
    self.zf_lastOffsetX = offsetX;
    if (self.zf_stopPlay) return;
    
    UIView *playerView;
    if (self.zf_containerType == ZFPlayerContainerTypeCell) {
        // Avoid being paused the first time you play it.
        if (self.contentOffset.x < 0) return;
        if (!self.zf_playingIndexPath) return;
        
        UIView *cell = [self zf_getCellForIndexPath:self.zf_playingIndexPath];
        if (!cell) {
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
            return;
        }
        playerView = [cell viewWithTag:self.zf_containerViewTag];
    } else if (self.zf_containerType == ZFPlayerContainerTypeView) {
        if (!self.zf_containerView) return;
        playerView = self.zf_containerView;
    }
    
    CGRect rect1 = [playerView convertRect:playerView.frame toView:self];
    CGRect rect = [self convertRect:rect1 toView:self.superview];
    /// playerView left to scrollView left space.
    CGFloat leftSpacing = CGRectGetMinX(rect) - CGRectGetMinX(self.frame) - CGRectGetMinX(playerView.frame);
    /// playerView bottom to scrollView right space.
    CGFloat rightSpacing = CGRectGetMaxX(self.frame) - CGRectGetMaxX(rect) + CGRectGetMinX(playerView.frame);
    /// The height of the content area.
    CGFloat contentInsetWidth = CGRectGetMaxX(self.frame) - CGRectGetMinX(self.frame);
    
    CGFloat playerDisapperaPercent = 0;
    CGFloat playerApperaPercent = 0;
    
    if (self.zf_scrollDirection == ZFPlayerScrollDirectionLeft) { /// Scroll left
        /// Player is disappearing.
        if (leftSpacing <= 0 && CGRectGetWidth(rect) != 0) {
            playerDisapperaPercent = -leftSpacing/CGRectGetWidth(rect);
            if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
            if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
        }
        
        /// Top area
        if (leftSpacing <= 0 && leftSpacing > -CGRectGetWidth(rect)/2) {
            /// When the player will disappear.
            if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
        } else if (leftSpacing <= -CGRectGetWidth(rect)) {
            /// When the player did disappeared.
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
        } else if (leftSpacing > 0 && leftSpacing <= contentInsetWidth) {
            /// Player is appearing.
            if (CGRectGetWidth(rect) != 0) {
                playerApperaPercent = -(leftSpacing-contentInsetWidth)/CGRectGetWidth(rect);
                if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
            }
            /// In visable area
            if (leftSpacing <= contentInsetWidth && leftSpacing > contentInsetWidth-CGRectGetWidth(rect)/2) {
                /// When the player will appear.
                if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
            } else {
                /// When the player did appeared.
                if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
            }
        }
        
    } else if (self.zf_scrollDirection == ZFPlayerScrollDirectionRight) { /// Scroll right
        /// Player is disappearing.
        if (rightSpacing <= 0 && CGRectGetWidth(rect) != 0) {
            playerDisapperaPercent = -rightSpacing/CGRectGetWidth(rect);
            if (playerDisapperaPercent > 1.0) playerDisapperaPercent = 1.0;
            if (self.zf_playerDisappearingInScrollView) self.zf_playerDisappearingInScrollView(self.zf_playingIndexPath, playerDisapperaPercent);
        }
        
        /// Bottom area
        if (rightSpacing <= 0 && rightSpacing > -CGRectGetWidth(rect)/2) {
            /// When the player will disappear.
            if (self.zf_playerWillDisappearInScrollView) self.zf_playerWillDisappearInScrollView(self.zf_playingIndexPath);
        } else if (rightSpacing <= -CGRectGetWidth(rect)) {
            /// When the player did disappeared.
            if (self.zf_playerDidDisappearInScrollView) self.zf_playerDidDisappearInScrollView(self.zf_playingIndexPath);
        } else if (rightSpacing > 0 && rightSpacing <= contentInsetWidth) {
            /// Player is appearing.
            if (CGRectGetWidth(rect) != 0) {
                playerApperaPercent = -(rightSpacing-contentInsetWidth)/CGRectGetWidth(rect);
                if (playerApperaPercent > 1.0) playerApperaPercent = 1.0;
                if (self.zf_playerAppearingInScrollView) self.zf_playerAppearingInScrollView(self.zf_playingIndexPath, playerApperaPercent);
            }
            /// In visable area
            if (rightSpacing <= contentInsetWidth && rightSpacing > contentInsetWidth-CGRectGetWidth(rect)/2) {
                /// When the player will appear.
                if (self.zf_playerWillAppearInScrollView) self.zf_playerWillAppearInScrollView(self.zf_playingIndexPath);
            } else {
                /// When the player did appeared.
                if (self.zf_playerDidAppearInScrollView) self.zf_playerDidAppearInScrollView(self.zf_playingIndexPath);
            }
        }
    }
}

/**
 Find the playing cell while the scrollDirection is vertical.
 先找显示的第一个,  后找显示的最后一个, 如果都不行, 就从显示的中进行查询. 所有的这些操作, 都会设置 shouldPlayerIndex. 然后会把这个 indexPath 传递出去.
 */
- (void)_findCorrectCellWhenScrollViewDirectionVertical:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    // 如果不是自动播放, 直接 return
    if (!self.zf_shouldAutoPlay) return;
    if (self.zf_containerType == ZFPlayerContainerTypeView) return;
    
    NSArray *visiableCells = nil;
    NSIndexPath *indexPath = nil;
    if ([self _isTableView]) {
        UITableView *tableView = (UITableView *)self;
        visiableCells = [tableView visibleCells];
        // First visible cell indexPath
        indexPath = tableView.indexPathsForVisibleRows.firstObject;
        if (self.contentOffset.y <= 0 && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
        
        // Last visible cell indexPath
        indexPath = tableView.indexPathsForVisibleRows.lastObject;
        if (self.contentOffset.y + self.frame.size.height >= self.contentSize.height && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
    } else if ([self _isCollectionView]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        visiableCells = [collectionView visibleCells];
        NSArray *sortedIndexPaths = [collectionView.indexPathsForVisibleItems sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        
        visiableCells = [visiableCells sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSIndexPath *path1 = (NSIndexPath *)[collectionView indexPathForCell:obj1];
            NSIndexPath *path2 = (NSIndexPath *)[collectionView indexPathForCell:obj2];
            return [path1 compare:path2];
        }];
        
        // First visible cell indexPath
        indexPath = sortedIndexPaths.firstObject;
        if (self.contentOffset.y <= 0 && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
        
        // Last visible cell indexPath
        indexPath = sortedIndexPaths.lastObject;
        if (self.contentOffset.y + self.frame.size.height >= self.contentSize.height && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
    }
    
    NSArray *cells = nil;
    if (self.zf_scrollDirection == ZFPlayerScrollDirectionUp) {
        cells = visiableCells;
    } else {
        cells = [visiableCells reverseObjectEnumerator].allObjects;
    }
    
    /// Mid line.
    CGFloat scrollViewMidY = CGRectGetHeight(self.frame)/2;
    /// The final playing indexPath.
    __block NSIndexPath *finalIndexPath = nil;
    /// The final distance from the center line.
    __block CGFloat finalSpace = 0;
    @weakify(self)
    [cells enumerateObjectsUsingBlock:^(UIView *cell, NSUInteger idx, BOOL * _Nonnull stop) {
        @strongify(self)
        UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
        if (!playerView) return;
        CGRect rect1 = [playerView convertRect:playerView.frame toView:self];
        CGRect rect = [self convertRect:rect1 toView:self.superview];
        /// playerView top to scrollView top space.
        CGFloat topSpacing = CGRectGetMinY(rect) - CGRectGetMinY(self.frame) - CGRectGetMinY(playerView.frame);
        /// playerView bottom to scrollView bottom space.
        CGFloat bottomSpacing = CGRectGetMaxY(self.frame) - CGRectGetMaxY(rect) + CGRectGetMinY(playerView.frame);
        CGFloat centerSpacing = ABS(scrollViewMidY - CGRectGetMidY(rect));
        NSIndexPath *indexPath = [self zf_getIndexPathForCell:cell];
        
        /// Play when the video playback section is visible.
        if ((topSpacing >= -(1 - self.zf_playerApperaPercent) * CGRectGetHeight(rect)) && (bottomSpacing >= -(1 - self.zf_playerApperaPercent) * CGRectGetHeight(rect))) {
            /// If you have a cell that is playing, stop the traversal.
            if (self.zf_playingIndexPath) {
                indexPath = self.zf_playingIndexPath;
                finalIndexPath = indexPath;
                *stop = YES;
                return;
            }
            if (!finalIndexPath || centerSpacing < finalSpace) {
                finalIndexPath = indexPath;
                finalSpace = centerSpacing;
            }
        }
    }];
    /// if find the playing indexPath.
    if (finalIndexPath) {
        if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
        if (handler) handler(finalIndexPath);
    }
    self.zf_shouldPlayIndexPath = finalIndexPath;
}

/**
 Find the playing cell while the scrollDirection is horizontal.
 */
- (void)_findCorrectCellWhenScrollViewDirectionHorizontal:(void (^ __nullable)(NSIndexPath *indexPath))handler {
    if (!self.zf_shouldAutoPlay) return;
    if (self.zf_containerType == ZFPlayerContainerTypeView) return;
    
    NSArray *visiableCells = nil;
    NSIndexPath *indexPath = nil;
    if ([self _isTableView]) {
        UITableView *tableView = (UITableView *)self;
        visiableCells = [tableView visibleCells];
        // First visible cell indexPath
        indexPath = tableView.indexPathsForVisibleRows.firstObject;
        if (self.contentOffset.x <= 0 && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
        
        // Last visible cell indexPath
        indexPath = tableView.indexPathsForVisibleRows.lastObject;
        if (self.contentOffset.x + self.frame.size.width >= self.contentSize.width && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
    } else if ([self _isCollectionView]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        visiableCells = [collectionView visibleCells];
        NSArray *sortedIndexPaths = [collectionView.indexPathsForVisibleItems sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            return [obj1 compare:obj2];
        }];
        
        visiableCells = [visiableCells sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSIndexPath *path1 = (NSIndexPath *)[collectionView indexPathForCell:obj1];
            NSIndexPath *path2 = (NSIndexPath *)[collectionView indexPathForCell:obj2];
            return [path1 compare:path2];
        }];
        
        // First visible cell indexPath
        indexPath = sortedIndexPaths.firstObject;
        if (self.contentOffset.x <= 0 && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
        
        // Last visible cell indexPath
        indexPath = sortedIndexPaths.lastObject;
        if (self.contentOffset.x + self.frame.size.width >= self.contentSize.width && (!self.zf_playingIndexPath || [indexPath compare:self.zf_playingIndexPath] == NSOrderedSame)) {
            UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
            UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
            if (playerView) {
                if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
                if (handler) handler(indexPath);
                self.zf_shouldPlayIndexPath = indexPath;
                return;
            }
        }
    }
    
    NSArray *cells = nil;
    if (self.zf_scrollDirection == ZFPlayerScrollDirectionUp) {
        cells = visiableCells;
    } else {
        cells = [visiableCells reverseObjectEnumerator].allObjects;
    }
    
    /// Mid line.
    CGFloat scrollViewMidX = CGRectGetWidth(self.frame)/2;
    /// The final playing indexPath.
    __block NSIndexPath *finalIndexPath = nil;
    /// The final distance from the center line.
    __block CGFloat finalSpace = 0;
    @weakify(self)
    [cells enumerateObjectsUsingBlock:^(UIView *cell, NSUInteger idx, BOOL * _Nonnull stop) {
        @strongify(self)
        UIView *playerView = [cell viewWithTag:self.zf_containerViewTag];
        if (!playerView) return;
        CGRect rect1 = [playerView convertRect:playerView.frame toView:self];
        CGRect rect = [self convertRect:rect1 toView:self.superview];
        /// playerView left to scrollView top space.
        CGFloat leftSpacing = CGRectGetMinX(rect) - CGRectGetMinX(self.frame) - CGRectGetMinX(playerView.frame);
        /// playerView right to scrollView top space.
        CGFloat rightSpacing = CGRectGetMaxX(self.frame) - CGRectGetMaxX(rect) + CGRectGetMinX(playerView.frame);
        CGFloat centerSpacing = ABS(scrollViewMidX - CGRectGetMidX(rect));
        NSIndexPath *indexPath = [self zf_getIndexPathForCell:cell];
        
        /// Play when the video playback section is visible.
        if ((leftSpacing >= -(1 - self.zf_playerApperaPercent) * CGRectGetWidth(rect)) && (rightSpacing >= -(1 - self.zf_playerApperaPercent) * CGRectGetWidth(rect))) {
            /// If you have a cell that is playing, stop the traversal.
            if (self.zf_playingIndexPath) {
                indexPath = self.zf_playingIndexPath;
                finalIndexPath = indexPath;
                *stop = YES;
                return;
            }
            if (!finalIndexPath || centerSpacing < finalSpace) {
                finalIndexPath = indexPath;
                finalSpace = centerSpacing;
            }
        }
    }];
    /// if find the playing indexPath.
    if (finalIndexPath) {
        if (self.zf_scrollViewDidScrollCallback) self.zf_scrollViewDidScrollCallback(indexPath);
        if (handler) handler(finalIndexPath);
        self.zf_shouldPlayIndexPath = finalIndexPath;
    }
}

- (BOOL)_isTableView {
    return [self isKindOfClass:[UITableView class]];
}

- (BOOL)_isCollectionView {
    return [self isKindOfClass:[UICollectionView class]];
}

#pragma mark - Swizzled method

- (UIView *)zf_getCellForIndexPath:(NSIndexPath *)indexPath {
    if ([self _isTableView]) {
        UITableView *tableView = (UITableView *)self;
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        return cell;
    } else if ([self _isCollectionView]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
        return cell;
    }
    return nil;
}

- (NSIndexPath *)zf_getIndexPathForCell:(UIView *)cell {
    if ([self _isTableView]) {
        UITableView *tableView = (UITableView *)self;
        NSIndexPath *indexPath = [tableView indexPathForCell:(UITableViewCell *)cell];
        return indexPath;
    } else if ([self _isCollectionView]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        NSIndexPath *indexPath = [collectionView indexPathForCell:(UICollectionViewCell *)cell];
        return indexPath;
    }
    return nil;
}

- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath completionHandler:(void (^ __nullable)(void))completionHandler {
    [self zf_scrollToRowAtIndexPath:indexPath animated:YES completionHandler:completionHandler];
}

- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated completionHandler:(void (^ __nullable)(void))completionHandler {
    [self zf_scrollToRowAtIndexPath:indexPath animateWithDuration:animated ? 0.4 : 0.0 completionHandler:completionHandler];
}

- (void)zf_scrollToRowAtIndexPath:(NSIndexPath *)indexPath animateWithDuration:(NSTimeInterval)duration completionHandler:(void (^ __nullable)(void))completionHandler {
    BOOL animated = duration > 0.0;
    if ([self _isTableView]) {
        UITableView *tableView = (UITableView *)self;
        [tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:animated];
    } else if ([self _isCollectionView]) {
        UICollectionView *collectionView = (UICollectionView *)self;
        [collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionTop animated:animated];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (completionHandler) completionHandler();
    });
}

- (void)zf_scrollViewDidEndDecelerating {
    BOOL scrollToScrollStop = !self.tracking && !self.dragging && !self.decelerating;
    if (scrollToScrollStop) {
        [self _scrollViewDidStopScroll];
    }
}

- (void)zf_scrollViewDidEndDraggingWillDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        BOOL dragToDragStop = self.tracking && !self.dragging && !self.decelerating;
        if (dragToDragStop) {
            [self _scrollViewDidStopScroll];
        }
    }
}

- (void)zf_scrollViewDidScrollToTop {
    [self _scrollViewDidStopScroll];
}

- (void)zf_scrollViewWillBeginDragging {
    [self _scrollViewBeginDragging];
}

#pragma mark - getter

- (ZFPlayerScrollDirection)zf_scrollDirection {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (ZFPlayerScrollViewDirection)zf_scrollViewDirection {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (CGFloat)zf_lastOffsetY {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (CGFloat)zf_lastOffsetX {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

#pragma mark - setter

- (void)setZf_scrollDirection:(ZFPlayerScrollDirection)zf_scrollDirection {
    objc_setAssociatedObject(self, @selector(zf_scrollDirection), @(zf_scrollDirection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_scrollViewDirection:(ZFPlayerScrollViewDirection)zf_scrollViewDirection {
    objc_setAssociatedObject(self, @selector(zf_scrollViewDirection), @(zf_scrollViewDirection), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_lastOffsetY:(CGFloat)zf_lastOffsetY {
    objc_setAssociatedObject(self, @selector(zf_lastOffsetY), @(zf_lastOffsetY), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_lastOffsetX:(CGFloat)zf_lastOffsetX {
    objc_setAssociatedObject(self, @selector(zf_lastOffsetX), @(zf_lastOffsetX), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIScrollView (ZFPlayerCannotCalled)

















#pragma mark - getter

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidEndScrollingCallback {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidScrollCallback {
    return objc_getAssociatedObject(self, _cmd);
}

- (void (^)(NSIndexPath * _Nonnull))zf_playerShouldPlayInScrollView {
    return objc_getAssociatedObject(self, _cmd);
}

- (CGFloat)zf_playerApperaPercent {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (CGFloat)zf_playerDisapperaPercent {
    return [objc_getAssociatedObject(self, _cmd) floatValue];
}

- (BOOL)zf_hiddenOnWindow {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)zf_stopPlay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)zf_stopWhileNotVisible {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (NSIndexPath *)zf_playingIndexPath {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSIndexPath *)zf_shouldPlayIndexPath {
    return objc_getAssociatedObject(self, _cmd);
}

- (NSInteger)zf_containerViewTag {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (BOOL)zf_isWWANAutoPlay {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (BOOL)zf_shouldAutoPlay {
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) return number.boolValue;
    self.zf_shouldAutoPlay = YES;
    return YES;
}

- (ZFPlayerContainerType)zf_containerType {
    return [objc_getAssociatedObject(self, _cmd) integerValue];
}

- (UIView *)zf_containerView {
    return objc_getAssociatedObject(self, _cmd);
}

#pragma mark - setter

- (void)setZf_playerDisappearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerDisappearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDisappearingInScrollView), zf_playerDisappearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerAppearingInScrollView:(void (^)(NSIndexPath * _Nonnull, CGFloat))zf_playerAppearingInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerAppearingInScrollView), zf_playerAppearingInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidAppearInScrollView), zf_playerDidAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillDisappearInScrollView), zf_playerWillDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerWillAppearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerWillAppearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerWillAppearInScrollView), zf_playerWillAppearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDidDisappearInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerDidDisappearInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerDidDisappearInScrollView), zf_playerDidDisappearInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_scrollViewDidEndScrollingCallback:(void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidEndScrollingCallback {
    objc_setAssociatedObject(self, @selector(zf_scrollViewDidEndScrollingCallback), zf_scrollViewDidEndScrollingCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_scrollViewDidScrollCallback:(void (^)(NSIndexPath * _Nonnull))zf_scrollViewDidScrollCallback {
    objc_setAssociatedObject(self, @selector(zf_scrollViewDidScrollCallback), zf_scrollViewDidScrollCallback, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerShouldPlayInScrollView:(void (^)(NSIndexPath * _Nonnull))zf_playerShouldPlayInScrollView {
    objc_setAssociatedObject(self, @selector(zf_playerShouldPlayInScrollView), zf_playerShouldPlayInScrollView, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerApperaPercent:(CGFloat)zf_playerApperaPercent {
    objc_setAssociatedObject(self, @selector(zf_playerApperaPercent), @(zf_playerApperaPercent), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_playerDisapperaPercent:(CGFloat)zf_playerDisapperaPercent {
    objc_setAssociatedObject(self, @selector(zf_playerDisapperaPercent), @(zf_playerDisapperaPercent), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_hiddenOnWindow:(BOOL)zf_viewControllerDisappear {
    objc_setAssociatedObject(self, @selector(zf_hiddenOnWindow), @(zf_viewControllerDisappear), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)setZf_stopPlay:(BOOL)zf_stopPlay {
    objc_setAssociatedObject(self, @selector(zf_stopPlay), @(zf_stopPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_stopWhileNotVisible:(BOOL)zf_stopWhileNotVisible {
    objc_setAssociatedObject(self, @selector(zf_stopWhileNotVisible), @(zf_stopWhileNotVisible), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_playingIndexPath:(NSIndexPath *)zf_playingIndexPath {
    objc_setAssociatedObject(self, @selector(zf_playingIndexPath), zf_playingIndexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (zf_playingIndexPath && [zf_playingIndexPath compare:self.zf_shouldPlayIndexPath] != NSOrderedSame) {
        self.zf_shouldPlayIndexPath = zf_playingIndexPath;
    }
}

- (void)setZf_shouldPlayIndexPath:(NSIndexPath *)zf_shouldPlayIndexPath {
    if (self.zf_playerShouldPlayInScrollView) self.zf_playerShouldPlayInScrollView(zf_shouldPlayIndexPath);
    objc_setAssociatedObject(self, @selector(zf_shouldPlayIndexPath), zf_shouldPlayIndexPath, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_containerViewTag:(NSInteger)zf_containerViewTag {
    objc_setAssociatedObject(self, @selector(zf_containerViewTag), @(zf_containerViewTag), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_containerType:(ZFPlayerContainerType)zf_containerType {
    objc_setAssociatedObject(self, @selector(zf_containerType), @(zf_containerType), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_containerView:(UIView *)zf_containerView {
    objc_setAssociatedObject(self, @selector(zf_containerView), zf_containerView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_shouldAutoPlay:(BOOL)zf_shouldAutoPlay {
    objc_setAssociatedObject(self, @selector(zf_shouldAutoPlay), @(zf_shouldAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setZf_WWANAutoPlay:(BOOL)zf_WWANAutoPlay {
    objc_setAssociatedObject(self, @selector(zf_isWWANAutoPlay), @(zf_WWANAutoPlay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end


#pragma clang diagnostic pop