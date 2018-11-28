//
//  ALinLiveCollectionViewController.h
//  MiaowShow
//
//  Created by ALin on 16/6/23.
//  Copyright © 2016年 ALin. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ALinLive;
@interface ALinLiveCollectionViewController : UICollectionViewController
/** 直播 */
@property (nonatomic, strong) NSArray *lives; // 这里是所有的数据.
/** 当前的index */
@property (nonatomic, assign) NSUInteger currentIndex;
@end
