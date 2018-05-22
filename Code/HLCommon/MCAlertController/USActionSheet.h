//
//  USActionSheet.h
//  USEvent
//
//  Created by marujun on 15/10/19.
//  Copyright © 2015年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface USActionSheet : UIView

+ (instancetype)initWithOtherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithCancelButtonTitle:(NSString *)cancelButtonTitle
                        otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithTitle:(NSString *)title
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithTitle:(NSString *)title
            cancelButtonTitle:(NSString *)cancelButtonTitle
       destructiveButtonTitle:(NSString *)destructiveButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithTitle:(NSString *)title
            cancelButtonTitle:(NSString *)cancelButtonTitle
       destructiveButtonTitle:(NSString *)destructiveButtonTitle
        otherButtonTitleArray:(NSArray *)otherButtonTitleArray;

- (void)clickedIndex:(NSInteger)index;

- (void)showWithCompletionBlock:(void (^)(NSInteger buttonIndex))completionBlock;

/**
 USActionSheet *sheet = [USActionSheet initWithCancelButtonTitle:@"关闭" otherButtonTitles:@"拨打 10010 修改", @"拨打 10011 修改", @"登录网上营业厅修改", nil];
 
 UIView *headerView = [UIView new];
 sheet.header = headerView;
 
 headerView.size = (CGSize){SCREEN_WIDTH, 300.f};
 [headerView addSubview:...];
 
 [sheet showWithCompletionBlock:^(NSInteger buttonIndex) {
 
 }];
 */

@property (nonatomic, strong) UIView *header; //!< 自定义header(高度、内容自定制)

@end
