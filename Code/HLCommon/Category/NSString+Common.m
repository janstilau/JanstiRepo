//  Created by chen ying on 12-11-6.

#import "NSString+Common.h"


@implementation NSString (Common)

- (BOOL)containsString:(NSString *)str
{
    if (str && self.length && str.length) {
        NSRange range = [self rangeOfString:str];
        if (range.location == NSNotFound) {
            return NO;
        }
        return YES;
    }
    return NO;
}

// 验证邮箱格式
-(BOOL)isValidateEmail
{
    BOOL stricterFilter = YES;   //规定是否严格判断格式
    NSString *stricterFilterString = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9-]+[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}";
    NSString *laxString = @".+@.+\\.[A-Za-z]{2}[A-Za-z]*";
    NSString *emailRegex = stricterFilter?stricterFilterString:laxString;
    NSPredicate *emailCheck = [NSPredicate predicateWithFormat:@"SELF MATCHES %@" , emailRegex];
    
    return [emailCheck evaluateWithObject:self];
}

//是否都为整形数字
- (BOOL)isPureInt
{
    NSScanner* scan = [NSScanner scannerWithString:self];
    int val;
    return [scan scanInt:&val] && [scan isAtEnd];
}

// 验证身份证号码
- (BOOL)isValidateIDCard
{
    if (self.length != 18) {
        return  NO;
    }
    NSArray* codeArray = [NSArray arrayWithObjects:@"7" ,@"9" ,@"10" ,@"5" ,@"8" ,@"4" ,@"2" ,@"1" ,@"6" ,@"3" ,@"7" ,@"9" ,@"10" ,@"5" ,@"8" ,@"4" ,@"2" , nil];
    NSDictionary* checkCodeDic = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"1" ,@"0" ,@"X" ,@"9" ,@"8" ,@"7" ,@"6" ,@"5" ,@"4" ,@"3" ,@"2" , nil]  forKeys:[NSArray arrayWithObjects:@"0" ,@"1" ,@"2" ,@"3" ,@"4" ,@"5" ,@"6" ,@"7" ,@"8" ,@"9" ,@"10" , nil]];
    NSScanner* scan = [NSScanner scannerWithString:[self substringToIndex:17]];
    
    int val;
    BOOL isNum = [scan scanInt:&val] && [scan isAtEnd];
    if (!isNum) {
        return NO;
    }
    int sumValue = 0;
    
    for (int i =0; i<17; i++) {
        sumValue+=[[self substringWithRange:NSMakeRange(i , 1) ] intValue]* [[codeArray objectAtIndex:i] intValue];
    }
    
    NSString* strlast = [checkCodeDic objectForKey:[NSString stringWithFormat:@"%d" ,sumValue%11]];
    
    if ([strlast isEqualToString: [[self substringWithRange:NSMakeRange(17, 1)]uppercaseString]]) {
        return YES;
    }
    return  NO;
}

// 验证手机号码
- (BOOL)isValidateMobileNumber
{
    //手机号以13， 15，18开头，八个 \d 数字字符 （新增14、17号段）
    NSString *phoneRegex = @"^((13[0-9])|(14[5,7])|(15[^4,\\D])|(17[0-9])|(18[0-9]))\\d{8}$";
    NSPredicate *phoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@" ,phoneRegex];
    return [phoneTest evaluateWithObject:self];
}

// 验证固定电话 座机
- (BOOL)isValidateLandlineTelephone
{
    NSString *regex = @"^(0[0-9]{2,3})?([2-9][0-9]{6,7})+([0-9]{1,4})?$";
    NSPredicate *phoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [phoneTest evaluateWithObject:self];
}

// 剔除卡号里的非法字符
- (NSString *)getDigitsOnly
{
    NSString *digitsOnly = @"";
    char c;
    for (int i = 0; i < self.length; i++){
        c = [self characterAtIndex:i];
        if (isdigit(c)){
            digitsOnly =[digitsOnly stringByAppendingFormat:@"%c" ,c];
        }
    }
    return digitsOnly;
}

// 验证银行卡 (Luhn算法)
- (BOOL)isValidCardNumber
{
    if (self.length < 16 || self.length > 19) return NO;
    
    NSString *digitsOnly = [self getDigitsOnly];
    int sum = 0, digit = 0, addend = 0;
    BOOL timesTwo = false;
    for (NSInteger i = digitsOnly.length - 1; i >= 0; i--) {
        digit = [digitsOnly characterAtIndex:i] - '0';
        if (timesTwo) {
            addend = digit * 2;
            if (addend > 9) {
                addend -= 9;
            }
        } else {
            addend = digit;
        }
        sum += addend;
        timesTwo = !timesTwo;
    }
    int modulus = sum % 10;
    return modulus == 0;
}

// 银行卡号对应的 发卡行.卡种名称
- (NSString *)correspondingBankName
{
    NSString* idCard = self;
    
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"bank_list" ofType:@"json"];
    NSDictionary *bankMapper = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:jsonPath] options:kNilOptions error:NULL];
    
    if(![self isValidCardNumber]) return nil;
    
    NSString *bankName = nil;
    
    //8位Bin号
    NSString *cardbin_8 = [idCard substringWithRange:NSMakeRange(0, 8)];
    bankName = [bankMapper objectForKey:cardbin_8];
    if (bankName) return bankName;
    
    //6位Bin号
    NSString *cardbin_6 = [idCard substringWithRange:NSMakeRange(0, 6)];
    bankName = [bankMapper objectForKey:cardbin_6];
    if (bankName) return bankName;
    
    //5位Bin号
    NSString *cardbin_5 = [idCard substringWithRange:NSMakeRange(0, 5)];
    bankName = [bankMapper objectForKey:cardbin_5];
    if (bankName) return bankName;
    
    //4位Bin号
    NSString *cardbin_4 = [idCard substringWithRange:NSMakeRange(0, 4)];
    bankName = [bankMapper objectForKey:cardbin_4];
    if (bankName) return bankName;
    
    return nil;
}


- (float)stringWidthWithFont:(UIFont *)font height:(float)height
{
    if (self == nil || self.length == 0) {
        return 0;
    }
    
    NSString *copyString = [NSString stringWithFormat:@"%@" , self];
    
    CGSize size = CGSizeZero;
    CGSize constrainedSize = CGSizeMake(CGFLOAT_MAX, height);
    
    if ([copyString respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.lineBreakMode = NSLineBreakByWordWrapping; //e.g.
        
        size = [copyString boundingRectWithSize: constrainedSize
                                        options:NSStringDrawingUsesLineFragmentOrigin
                                     attributes:@{ NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraph }
                                        context: nil].size;
    } else {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        size = [copyString sizeWithFont:font constrainedToSize:constrainedSize lineBreakMode:NSLineBreakByWordWrapping];
#pragma GCC diagnostic pop
    }
    
    return ceilf(size.width+0.5);
}

- (float)stringHeightWithFont:(UIFont *)font width:(float)width
{
    return [self stringHeightWithFont:font width:width lineSpacing:0];
}


- (float)stringHeightWithFont:(UIFont *)font width:(float)width lineSpacing:(float)lineSpacing
{
    if (self == nil || self.length == 0) {
        return 0;
    }
    
    NSString *copyString = [NSString stringWithFormat:@"%@", self];
    
    CGSize size = CGSizeZero;
    CGSize constrainedSize = CGSizeMake(width, CGFLOAT_MAX);
    
    if ([copyString respondsToSelector:@selector(boundingRectWithSize:options:attributes:context:)]) {
        
        NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
        paragraph.lineBreakMode = NSLineBreakByWordWrapping; //e.g.
        if (lineSpacing) {
            paragraph.lineSpacing = lineSpacing;
        }
        
        size = [copyString boundingRectWithSize:constrainedSize
                                        options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                                     attributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraph }
                                        context:nil].size;
    }else{
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        size = [copyString sizeWithFont:font constrainedToSize:constrainedSize lineBreakMode:NSLineBreakByWordWrapping];
#pragma GCC diagnostic pop
    }
    
    return ceilf(size.height+0.5);
}

- (BOOL)containsChineseCharacter
{
    BOOL isContan = NO;
    
    for(int i=0; i< [self length];i++) {
        NSRange range = NSMakeRange(i, 1);
        NSString *subString = [self substringWithRange:range];
        const char *cString = [subString UTF8String];
        
        if (cString && strlen(cString) == 3) {
            isContan = YES;
        }
    }
    
    return isContan;
}

@end


@implementation NSNumber (Common)

/** 格式化金额数据，数字千分位 */
- (NSString *)stringWithAmountFormat
{
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setMaximumFractionDigits:2];
    
    return [formatter stringFromNumber:self];
}

@end


