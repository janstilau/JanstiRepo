//
//  TZAlbumPickerController.h
//  TZImagePickerController
//
//  Created by JustinLau on 2020/3/30.
//  Copyright © 2020 谭真. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface TZAlbumPickerController : UIViewController

@property (nonatomic, assign) NSInteger columnNumber;
@property (assign, nonatomic) BOOL isFirstAppear;

- (void)configTableView;

@end
NS_ASSUME_NONNULL_END
