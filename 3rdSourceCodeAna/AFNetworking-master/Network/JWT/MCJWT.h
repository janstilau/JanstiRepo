//
//  MCJWT.h
//  MCMoego
//
//  Created by Zhou Kang on 2018/4/11.
//  Copyright © 2018年 Moca Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCAlgorithm.h"

@interface MCJWT : NSObject

+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                          error:(NSError **)error;

+ (NSString *)encodeWithPayload:(NSDictionary *)payload
                            key:(NSString *)key
                      algorithm:(AlgorithmType)algorithm
                       error:(NSError **) error;

+ (NSDictionary *)decodeWithToken:(NSString *)token
                              key:(NSString *)key
                     shouldVerify:(BOOL)verify
                            error:(NSError **)error;

@end
