//
//  USUserContactManager.h
//  HTWallet
//
//  Created by jansti on 16/7/20.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface USUserContactManager : NSObject
/**
 *  获取用户通讯录,首先检测用户授权状况,发送Notification_ContactsAuthorized通知.该通知用于处理有关用户授权与否业务逻辑.
 *  同意授权后异步获取所有电话,获取完成发送Notification_ContactsCollectDone通知,之后userContacts获取实际电话数据.
 */
+ (void)acquireUserContacts;
/**
 *  获取用户通讯录,如果为nil调用acquireUserContacts,由于是异步获取,在通知后调用userContacts
 *  再次获取通讯录.
 *
 *  @return 用户通讯录
 */
+ (NSArray *)userContacts;
/**
 *
 *
 *  @return 用户当前的授权状态.
 */
+ (BOOL)userAuthorizationAllowed;

/**
 *
 *
 *  @return 上传通讯录.
 */

+ (void)uploadUserContacts;

/**
 *
 *
 *  @return 检测上传通讯录完成与否,没有重传.
 */

+ (void)checkAlreadyUploaded;


@end
