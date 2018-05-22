//
//  USAlertView.h
//  HTWallet
//
//  Created by ZK on 16/11/2.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface USAlertView : UIView

+ (instancetype)showWithMessage:(NSString *)message;

+ (instancetype)showWithTitle:(NSString *)title message:(NSString *)message;

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle;

+ (instancetype)initWithMessage:(NSString *)message
              cancelButtonTitle:(NSString *)cancelButtonTitle
              otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION;

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle
        otherButtonTitleArray:(NSArray *)otherButtonTitleArray;

- (void)clickedIndex:(NSInteger)index;

- (void)showWithCompletionBlock:(void (^)(NSInteger buttonIndex))completionBlock;

// 定制

/**
 调用方法 like this
 NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
 
 NSMutableAttributedString *string_1 = [[NSMutableAttributedString alloc] initWithString:@"[医美整形医院] 借款10,000元\n"];
 string_1.color = HexColor(0x535353);
 
 NSMutableAttributedString *string_2 = [[NSMutableAttributedString alloc] initWithString:@"第三期还款日: 今天\n"];
 string_2.color = [UIColor redColor];
 
 NSMutableAttributedString *string_3 = [[NSMutableAttributedString alloc] initWithString:@"本期应还 ¥2,000元"];
 [string_3 setColor:[UIColor brownColor] range:string_3.rangeOfAll];
 [string_3 setColor:HexColor(0x535353) range:[string_3.string rangeOfString:@"本期应还"]];
 
 [attributedString appendAttributedString:string_1];
 [attributedString appendAttributedString:string_2];
 [attributedString appendAttributedString:string_3];
 
 attributedString.lineSpacing = 8.f;
 
 USAlertView *alertView = [USAlertView initWithIcon:[UIImage imageNamed:@"account_ali"] title:@"还款提醒" attributedMsg:attributedString doneButtonTitle:@"去还款"];
 alertView.showForkBtn = YES;
 [alertView showWithCompletionBlock:^(NSInteger buttonIndex) {
 
 }];
 */

@property (nonatomic, assign) BOOL showForkBtn; //!< 是否展示右上角X按钮

+ (instancetype)initWithIcon:(UIImage *)icon
                       title:(NSString *)title
               attributedMsg:(NSMutableAttributedString *)attributedMsg
           doneButtonTitle:(NSString *)doneButtonTitle;

@end
