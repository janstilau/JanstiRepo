//
//  AFCollectionViewLayoutAttributes.h
//  Dimensions
//
//  Created by Ash Furrow on 2013-01-13.
//  Copyright (c) 2013 Ash Furrow. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum : NSUInteger{
    AFCollectionViewFlowLayoutModeAspectFit,    //Default
    AFCollectionViewFlowLayoutModeAspectFill
}AFCollectionViewFlowLayoutMode;

@interface AFCollectionViewLayoutAttributes : UICollectionViewLayoutAttributes

@property (nonatomic, assign) AFCollectionViewFlowLayoutMode layoutMode;

@end
