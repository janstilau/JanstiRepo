//
//  USBottomView.h
//  HTWallet
//
//  Created by ZK on 16/10/11.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@class USBottomView;

@protocol USBottomViewDelegate <NSObject>

@optional
- (void)bottomViewDidClickButton:(USBottomView *)bottomView;

@end

@interface USBottomView : UIView

@property (nonatomic, copy) NSString *title; //!< 底部按钮标题 Default:@"完成"
@property (nonatomic, weak) id <USBottomViewDelegate> delegate;

@end

extern const CGFloat USBottomViewHeight;
