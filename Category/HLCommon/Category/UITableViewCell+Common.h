//
//  UITableViewCell+Common.h
//  USEvent
//
//  Created by marujun on 15/9/16.
//  Copyright (c) 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UITableViewCell (Common)

- (id)tableViewDelegate;

- (UITableView *)superTableView;

- (NSString *)loadingImageUrl;

- (NSArray *)loadingImageUrlArray;

@end

@interface UICollectionViewCell (Common)

- (id)collectionViewDelegate;

- (UICollectionView *)superCollectionView;

- (NSString *)loadingImageUrl;

- (NSArray *)loadingImageUrlArray;

@end
