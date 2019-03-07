//
//  SMArticleViewController.h
//  GCDFetchFeed
//
//  Created by DaiMing on 16/2/16.
//  Copyright © 2016年 Starming. All rights reserved.
//

#import <UIKit/UIKit.h>
@class SMFeedItemModel;

// 详情页
@interface SMArticleViewController : UIViewController

- (instancetype)initWithFeedModel:(SMFeedItemModel *)feedItemModel;

@end
