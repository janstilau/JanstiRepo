//
//  TorusIndicatorView.h
//  MCFriends
//
//  Created by marujun on 14/10/28.
//  Copyright (c) 2014年 marujun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TorusIndicatorView : UIView

@property(nonatomic) BOOL isAnimating;
@property(nonatomic) BOOL hidesWhenStopped;      // default is YES. calls -setHidden when animating gets set to NO

- (void)startAnimating;
- (void)stopAnimating;

@end
