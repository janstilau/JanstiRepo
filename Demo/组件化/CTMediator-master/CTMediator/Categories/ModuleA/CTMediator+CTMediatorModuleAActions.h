//
//  CTMediator+CTMediatorModuleAActions.h
//  CTMediator
//
//  Created by casa on 16/3/13.
//  Copyright © 2016年 casa. All rights reserved.
//

#import "CTMediator.h"
#import <UIKit/UIKit.h>

/*
 这个类, 应该由 Target_A 的维护着提供, 里面是对于调用  Target_A 的各个方法的包装.
 
 实际上, B 模块要调用 A 模块, 必要要知道 A 模块提供的一些信息, 才能调用到 A 模块的服务.
 A 模块的 Target_A 类, 应该是和 A 模块的其他功能类, 是放在一个 repo 里面的. 但是 B 模块应该引用的, 是这个 CTMediator 的分类.
 CTMediator 的 A 分类, 是一个单独的 Repo, 由 A 模块的开发者维护. 这样, B 模块可以不知道引用 A 模块里面的业务, 达到模块之间解耦的目的.
 */

@interface CTMediator (CTMediatorModuleAActions)

- (UIViewController *)CTMediator_viewControllerForDetail;

- (void)CTMediator_showAlertWithMessage:(NSString *)message cancelAction:(void(^)(NSDictionary *info))cancelAction confirmAction:(void(^)(NSDictionary *info))confirmAction;

- (void)CTMediator_presentImage:(UIImage *)image;

- (UITableViewCell *)CTMediator_tableViewCellWithIdentifier:(NSString *)identifier tableView:(UITableView *)tableView;

- (void)CTMediator_configTableViewCell:(UITableViewCell *)cell withTitle:(NSString *)title atIndexPath:(NSIndexPath *)indexPath;

- (void)CTMediator_cleanTableViewCellTarget;

@end
