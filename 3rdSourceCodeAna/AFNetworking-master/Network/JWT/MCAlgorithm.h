//
//  MCAlgorithm.h
//  MCMoego
//
//  Created by Zhou Kang on 2018/4/11.
//  Copyright © 2018年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>

typedef NS_ENUM(NSUInteger, AlgorithmType) {
    HS256 = 0,
    HS384,
    HS512,
};

@interface MCAlgorithm : NSObject

+ (NSString *)getValueWithAlgorithmType:(AlgorithmType)algorithmType;
+ (int)getDigestLengthWithAlgorithmType:(AlgorithmType)algorithmType;
+ (AlgorithmType)getNameWithAlgorithmValue:(NSString *)algorithmValue;

@end
