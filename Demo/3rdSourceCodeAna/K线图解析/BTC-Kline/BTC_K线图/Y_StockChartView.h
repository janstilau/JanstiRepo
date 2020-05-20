//
//  Y-StockChartView.h
//  BTC-Kline
//
//  Created by yate1996 on 16/4/30.
//  Copyright © 2016年 yate1996. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Y_StockChartConstant.h"

//种类
typedef NS_ENUM(NSInteger, LineType) {
    KLineTypeTimeShare = 1,
    KLineType1Min,
    KLineType3MIn,
    KLineType5Min,
    KLineType10Min,
    KLineType15Min,
    KLineType30Min,
    KLineType1Hour,
    KLineType2Hour,
    KLineType4Hour,
    KLineType6Hour,
    KLineType12Hour,
    KLineType1Day,
    KLineType3Day,
    KLineType1Week
};

/**
 *  Y_StockChartView数据源
 */
@protocol Y_StockChartViewDataSource <NSObject>

-(id) stockDatasWithIndex:(NSInteger)index;

@end


@interface Y_StockChartView : UIView
@property (nonatomic, strong) NSArray *itemModels;
@property (nonatomic, weak) id<Y_StockChartViewDataSource> dataSource;
@property (nonatomic, assign,readonly) LineType currentLineTypeIndex;
-(void) reloadData;
@end

/************************ItemModel类************************/
@interface StockChartItemModel : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) ChartViewType centerViewType;
+ (instancetype)itemModelWithTitle:(NSString *)title type:(ChartViewType)type;

@end
