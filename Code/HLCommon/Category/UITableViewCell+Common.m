//
//  UITableViewCell+Common.m
//  USEvent
//
//  Created by marujun on 15/9/16.
//  Copyright (c) 2015年 MaRuJun. All rights reserved.
//

#import "UITableViewCell+Common.h"

@implementation UITableViewCell (Common)

- (UIEdgeInsets)layoutMargins
{
    return UIEdgeInsetsZero;
}

- (id)tableViewDelegate
{
    UITableView *tableView = [self superTableView];
    
    if (tableView) {
        return tableView.delegate;
    }
    
    return nil;
}

- (UITableView *)superTableView
{
    id view = [self superview];
    
    while (view && ![view isKindOfClass:[UITableView class]]) {
        view = [view superview];
    }
    
    return (UITableView *)view;
}

- (NSString *)loadingImageUrl
{
    return nil;
}

- (NSArray *)loadingImageUrlArray
{
    return nil;
}

@end

@implementation UICollectionViewCell (Common)

- (id)collectionViewDelegate
{
    UICollectionView *collectionView = [self superCollectionView];
    
    if (collectionView) {
        return collectionView.delegate;
    }
    
    return nil;
}

- (UICollectionView *)superCollectionView
{
    id view = [self superview];
    
    while (view && ![view isKindOfClass:[UICollectionView class]]) {
        view = [view superview];
    }
    
    return (UICollectionView *)view;
}

- (NSString *)loadingImageUrl
{
    return nil;
}

- (NSArray *)loadingImageUrlArray
{
    return nil;
}

@end

