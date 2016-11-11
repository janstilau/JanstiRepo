//  Created by chen ying on 12-11-6.
//  Copyright (c) 2012年 hoolai. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Common)

/** 验证邮箱 */
-(BOOL)isValidateEmail;

/** 是否都为整形数字 */
- (BOOL)isPureInt;

/** 验证身份证号码 */
- (BOOL)isValidateIDCard;

/** 验证手机号码 */
- (BOOL)isValidateMobileNumber;

/** 验证座机号码 */
- (BOOL)isValidateLandlineTelephone;

/** 验证银行卡 (Luhn算法) */
- (BOOL)isValidCardNumber;

/** 银行卡号对应的 发卡行.卡种名称 */
- (NSString *)correspondingBankName;

/** 是否包含中文 */
- (BOOL)containsChineseCharacter;

- (float)stringWidthWithFont:(UIFont *)font height:(float)height;
- (float)stringHeightWithFont:(UIFont *)font width:(float)width lineSpacing:(float)lineSpacing;
- (float)stringHeightWithFont:(UIFont *)font width:(float)width;

@end

@interface NSNumber (Common)

/** 格式化金额数据，数字千分位 */
- (NSString *)stringWithAmountFormat;

@end
