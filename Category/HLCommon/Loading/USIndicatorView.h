//
//  USIndicatorView.h
//  USEvent
//
//  Created by marujun on 15/10/19.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface USIndicatorView : UIImageView

@property(nonatomic) BOOL isAnimating;
@property(nonatomic) BOOL hidesWhenStopped;      // default is YES. calls -setHidden when animating gets set to NO

- (void)startAnimating;
- (void)stopAnimating;

@end
