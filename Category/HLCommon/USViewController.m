//
//  USViewController.m
//  USEvent
//
//  Created by marujun on 15/9/8.
//  Copyright (c) 2015年 MaRuJun. All rights reserved.
//

#import "USViewController.h"
#import "UMMobClick/MobClick.h"

@implementation USNavigationBar

- (UILabel *)bottomLine
{
    if (!_bottomLine) {
        _bottomLine = [[UILabel alloc] init];
        _bottomLine.backgroundColor = VIEW_BG_COLOR;
        [self addSubview:_bottomLine];
        
        _bottomLine.hidden = YES;
    }
    return _bottomLine;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    //在iOS7上使用Autolayout会崩溃，所以直接设置frame
    _bottomLine.frame = CGRectMake(0, self.frame.size.height-0.5, self.frame.size.width, 0.5);
}

@end

@interface USViewController ()
{
    UIWindow *_topTipWindow;
}

@end


@implementation USViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self fInit];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.clipsToBounds = YES;
    
    self.automaticallyAdjustsScrollViewInsets = NO;
    
    self.navigationBar.clipsToBounds = YES;
    self.navigationBar.translucent = NO;
    self.navigationBar.barTintColor = [UIColor whiteColor];
    
    NSShadow *shadow = [NSShadow new];
    NSDictionary *dict = @{NSShadowAttributeName:shadow,
                           NSFontAttributeName:[UIFont fontWithName:FZLTXIHFontName size:15],
                           NSForegroundColorAttributeName:KG_TINT_COLOR};
    self.navigationBar.titleTextAttributes = dict;
    
    if (self.navigationController) {
        self.navigationController.navigationBar.clipsToBounds = YES;
        self.navigationController.navigationBar.translucent = NO;
        self.navigationController.navigationBar.titleTextAttributes = dict;
        self.navigationController.navigationBar.barTintColor = [UIColor whiteColor];
        [self.navigationController.navigationBar setTitleVerticalPositionAdjustment:-2 forBarMetrics:UIBarMetricsDefault];
    }
    
    [self.view addSubview:self.navigationBar];
    [self.navigationBar pushNavigationItem:self.myNavigationItem animated:NO];
    [self.navigationBar autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, -1, 0, 0) excludingEdge:ALEdgeBottom];
}

- (void)setTitle:(NSString *)title
{
    self.myNavigationItem.title = title;
    
    [super setTitle:title];
}

- (void)fInit
{
    _topInset = 64;
    _enableScreenEdgePanGesture = YES;
    self.navigationBar = [[USNavigationBar alloc] initForAutoLayout];
    [self.navigationBar autoSetDimension:ALDimensionHeight toSize:_topInset];
    
    self.myNavigationItem = [[UINavigationItem alloc] initWithTitle:@""];
    [self.navigationBar setTitleVerticalPositionAdjustment:-2 forBarMetrics:UIBarMetricsDefault];
    
    DLOG(@"init 创建类 %@", NSStringFromClass([self class]));
}

- (void)updateDisplay
{
    
}

- (UIViewController *)viewControllerWillPushForLeftDirectionPan
{
    return nil;
}

+ (instancetype)viewController
{
    if([[NSBundle mainBundle] pathForResource:NSStringFromClass([self class]) ofType:@"nib"] != nil) {
        return [[self alloc] initWithNibName:NSStringFromClass([self class]) bundle:nil];
    }
    
    return [[self alloc] init];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self UMStatisticPage]) {
        [MobClick beginLogPageView:[self UMStatisticPage]];
    }
    
    [[ImageCacheManager defaultManager] bringIdentifyToFront:NSStringFromClass([self class])];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self UMStatisticPage]) {
        [MobClick endLogPageView:[self UMStatisticPage]];
    }
    
    if([USLoadingView onlyInstance]){
        [[USLoadingView onlyInstance].requestOperation cancel];
        [USLoadingView removeLoadingView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self bringVisibleImageLoadingForward:scrollView];
}

- (void)bringVisibleImageLoadingForward:(UIScrollView *)scrollView
{
    NSMutableArray *urlArray = [NSMutableArray array];
    
    if ([scrollView isKindOfClass:[UICollectionView class]]) {
        NSMutableArray *visibleCells = [[(UICollectionView *)scrollView visibleCells] mutableCopy];
        [visibleCells sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"layer.position.y" ascending:YES], [[NSSortDescriptor alloc] initWithKey:@"layer.position.x" ascending:YES]]];
        for (UICollectionViewCell *cell in visibleCells) {
            if (cell.loadingImageUrlArray) [urlArray addObjectsFromArray:cell.loadingImageUrlArray];
            else if (cell.loadingImageUrl) [urlArray addObject:cell.loadingImageUrl];
        }
    }
    else if ([scrollView isKindOfClass:[UITableView class]]) {
        NSArray *visibleCells = [(UITableView *)scrollView visibleCells];
        for (UITableViewCell *cell in visibleCells) {
            if (cell.loadingImageUrlArray) [urlArray addObjectsFromArray:cell.loadingImageUrlArray];
            else if (cell.loadingImageUrl) [urlArray addObject:cell.loadingImageUrl];
        }
    }
    
    [[ImageCacheManager defaultManager] bringURLArrayToFront:urlArray];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_topTipWindow && (scrollView.contentOffset.y+_topInset-scrollView.top)==0) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startTipDisappearFlipAnimation) object:nil];
        [self performSelector:@selector(startTipDisappearFlipAnimation) withObject:nil afterDelay:0.5];
        
        return;
    }
    
    if(!_enableStatusBarTip) return;
    
    NSString *tipKey = @"StatusBarTip";
    
    CGFloat offsetY = scrollView.contentOffset.y + _topInset;
    NSInteger tipNum = [[AuthData objectForKey:tipKey] integerValue];
    if (tipNum < 2) {
        if (offsetY > 2 * SCREEN_HEIGHT && offsetY < scrollView.accessibilityActivationPoint.y) {
            [self startTipAppearFlipAnimation];
            [self setEnableStatusBarTip:NO];
            
            [AuthData setObject:@(tipNum+1) forKey:tipKey];
        }
    }
    scrollView.accessibilityActivationPoint = CGPointMake(0, offsetY);
}

//状态栏点击此处返回提示
- (void)startTipAppearFlipAnimation
{
    _topTipWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, -20, SCREEN_WIDTH, 20)];
    _topTipWindow.windowLevel = UIWindowLevelStatusBar;
    _topTipWindow.backgroundColor = KY_TINT_COLOR;
    _topTipWindow.userInteractionEnabled = NO;
    _topTipWindow.hidden = YES;
    
    //创建Label
    UILabel *label = [[UILabel alloc] initWithFrame:_topTipWindow.bounds];
    label.text = @"点击此处返回顶部";
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:11.0];
    label.textColor = [UIColor blackColor];
    label.userInteractionEnabled = NO;
    [_topTipWindow addSubview:label];
    
    [UIView transitionWithView:_topTipWindow duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
        _topTipWindow.frame = CGRectMake(0, 0, SCREEN_WIDTH, 20);
        _topTipWindow.hidden = NO;
    } completion:nil];
    
    [self performSelector:@selector(startTipDisappearFlipAnimation) withObject:nil afterDelay:4];
}

- (void)startTipDisappearFlipAnimation
{
    if (!_topTipWindow) return;
    
    [UIView transitionWithView:_topTipWindow duration:0.5 options:UIViewAnimationOptionTransitionFlipFromTop animations:^{
        _topTipWindow.frame = CGRectMake(0, -20, SCREEN_WIDTH, 20);
    } completion:^(BOOL finished) {
        _topTipWindow = nil;
    }];
}

//友盟页面统计
- (NSString *)UMStatisticPage
{
#ifdef DEBUG
    return nil;
#else
    if (self.hint) return self.hint;
    else return self.title;
#endif
}


- (void)dealloc
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    DLOG(@"dealloc 释放类 %@",  NSStringFromClass([self class]));
}

@end
