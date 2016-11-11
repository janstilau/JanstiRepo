//
//  MCRedBadge.h
//  MCFriends
//
//  Created by bob on 14/11/15.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MCRedBadge : UIView

@property (nonatomic, strong) UILabel *badgeNumLabel;

- (void)setBadgeNum:(NSInteger)badgeNum;

@end
