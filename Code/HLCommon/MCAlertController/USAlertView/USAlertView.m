//
//  USAlertView.m
//  HTWallet
//
//  Created by ZK on 16/11/2.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import "USAlertView.h"

#define OS_VERSION [[[UIDevice currentDevice] systemVersion] floatValue]
//判断系统版本 大于等于(great or equal to)版本号
#define OS_VERSION_G_E(version) (OS_VERSION >= version)

@interface USAlertViewController : UIViewController

@property (nonatomic, strong) UIView *showingView;

- (void)addShowingView:(UIView *)showingView;
- (void)removeShowingView;

@end

@implementation USAlertViewController

#pragma mark - rotation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    if (_showingView && (!OS_VERSION_G_E(8))) {
        [self moveShowingViewToCenterWithOrientation:toInterfaceOrientation];
    }
}

#pragma mark - Function - Public

- (void)addShowingView:(UIView *)showingView
{
    if (self.showingView) {
        [_showingView removeFromSuperview];
    }
    self.showingView = showingView;
    [self.view addSubview:_showingView];
    if (OS_VERSION_G_E(8)) {
        _showingView.centerX = self.view.width/2;
        _showingView.centerY = self.view.height/2;
    }
    else{
        [self moveShowingViewToCenterWithOrientation:self.interfaceOrientation];
    }
}

- (void)removeShowingView
{
    if (self.showingView) {
        [_showingView removeFromSuperview];
    }
    self.showingView = nil;
}

#pragma mark - Private

- (void)moveShowingViewToCenterWithOrientation:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        _showingView.centerX = self.view.width/2;
        _showingView.centerY = self.view.height/2;
    }
    else if(UIInterfaceOrientationIsLandscape(orientation)){
        _showingView.centerX = self.view.height/2;
        _showingView.centerY = self.view.width/2;
    }
}

@end

/***************************************/

@interface USAlertManager : NSObject

+ (instancetype)shareInstance;

- (void)handleShowAlertView:(USAlertView *)alertView;
- (void)handleAlertViewClick; //!< 处理alertView点击之后的隐藏

@end

@implementation USAlertManager {
    UIWindow *_window;
    USAlertView *_showingView; //!< 正在展示的alertView
    NSMutableArray *_alertViews;
    UIView *_maskView;
    USAlertViewController *_alertVC;
}

+ (instancetype)shareInstance
{
    static USAlertManager *mgr;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [USAlertManager new];
        mgr->_window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        mgr->_window.backgroundColor = [UIColor clearColor];
        mgr->_window.windowLevel = UIWindowLevelAlert;
        mgr->_window.hidden = YES;
        
        mgr->_alertVC = [USAlertViewController new];
        mgr->_window.rootViewController = mgr->_alertVC;
        
        mgr->_alertViews = [NSMutableArray array];
        
        mgr->_maskView = [UIView new];
        mgr->_maskView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:.32];
        [mgr->_alertVC.view addSubview:mgr->_maskView];
        mgr->_maskView.frame = mgr->_alertVC.view.bounds;
        mgr->_maskView.alpha = 0;
    });
    return mgr;
}

- (void)handleAlertViewClick
{
    [self hideShowingAlertView];
    
    if ([_alertViews count] > 0) {
        USAlertView *alertView = _alertViews.lastObject;
        [_alertViews removeLastObject];
        
        [self showAlertView:alertView];
    }
}

/*! 暂存正在显示的alertView */
- (void)fetchShowingView
{
    if (_showingView) {
        [_alertViews addObject:_showingView];
        [self hideShowingAlertView];
    }
}

- (void)handleShowAlertView:(USAlertView *)view
{
    [self fetchShowingView];
    
    [self showAlertView:view];
}

- (void)showAlertView:(USAlertView *)view
{
    USAlertViewController *alertVC = (USAlertViewController *)_window.rootViewController;
    [alertVC addShowingView:view];
    _showingView = view;
    _window.hidden = NO;
    [_window makeKeyAndVisible];
    
    view.transform = CGAffineTransformMakeScale(1.2, 1.2);
    view.alpha = 0;
    
    [UIView animateWithDuration:.25 delay:0 options:KeyboardAnimationCurve animations:^{
        view.transform = CGAffineTransformIdentity;
        view.alpha = 1;
        _maskView.alpha = 1;
    } completion:^(BOOL finished) {
    }];
}

- (void)hideShowingAlertView;
{
    USAlertViewController *alertVC = (USAlertViewController *)_window.rootViewController;
    
    if (_alertViews.count>=1) {
        [alertVC removeShowingView];
        _showingView = nil;
        _window.hidden = YES;
    }
    else {
        [UIView animateWithDuration:.22 animations:^{
            _showingView.transform = CGAffineTransformMakeScale(.01, .01);
            _showingView.alpha = 0;
            _maskView.alpha = 0;
        } completion:^(BOOL finished) {
            [alertVC removeShowingView];
            _showingView = nil;
            _window.hidden = YES;
            [_window resignKeyWindow];
        }];
    }
}

@end

/************************************/

#define kContentWidth   (235.f*WindowZoomScale)
#define kLabelMaxWidth  (210.f*WindowZoomScale)
#define kTitleFont      [UIFont fontWithName:FZLTXIHFontName size:AutoFitFontSize(15.f)]
#define kMsgFont        [UIFont fontWithName:FZLTXIHFontName size:AutoFitFontSize(13.f)]

@interface USAlertView ()

@property (nonatomic, copy) void (^completeBlock)(NSInteger buttonIndex);

@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *topContainer;
@property (nonatomic, strong) UIView *labelContainer;
@property (nonatomic, strong) UIView *bottomContainer;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *msgLabel;
@property (nonatomic, assign) NSUInteger btnCount;
@property (nonatomic, strong) UIButton *forkBtn; //!< 右上角X按钮

@end

static const CGFloat kTopContainerMinHeight = 180.f;
static const CGFloat kMargin = 5.f;
static const CGFloat kBottomContainerHeight = 42.f;

@implementation USAlertView

#pragma mark - Init

- (instancetype)init
{
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (void)setup
{
    self.frame = [UIScreen mainScreen].bounds;
    _showForkBtn = NO;
    
    _containerView = [UIView new];
    [self addSubview:_containerView];
    _containerView.size = (CGSize){kContentWidth, 200.f};
    
    _topContainer = [UIView new];
    [_containerView addSubview:_topContainer];
    _topContainer.size = (CGSize){kContentWidth, 130.f};
    _topContainer.backgroundColor = [UIColor whiteColor];
    _topContainer.layer.masksToBounds = YES;
    _topContainer.layer.cornerRadius = 7.f;
    
    _iconImageView = [UIImageView new];
    [_topContainer addSubview:_iconImageView];
    _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
    _iconImageView.size = (CGSize){52.f, 42.f};
    _iconImageView.centerX = _iconImageView.superview.centerX;
    _iconImageView.top = 20.f;
    
    _labelContainer = [UIView new];
    [_containerView addSubview:_labelContainer];
    _labelContainer.size = (CGSize){kLabelMaxWidth, 100.f};
    _labelContainer.top = CGRectGetMaxY(_iconImageView.frame)+7.f;
    _labelContainer.centerX = _labelContainer.superview.centerX;
    
    _titleLabel = [UILabel new];
    [_labelContainer addSubview:_titleLabel];
    _titleLabel.font = kTitleFont;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = HexColor(0x535353);
    _titleLabel.size = (CGSize){_labelContainer.width, 20.f};
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = .6;
    
    _msgLabel = [UILabel new];
    [_labelContainer addSubview:_msgLabel];
    _msgLabel.font = kMsgFont;
    _msgLabel.numberOfLines = 0;
    _msgLabel.textAlignment = NSTextAlignmentCenter;
    _msgLabel.textColor = _titleLabel.textColor;
    _msgLabel.top = CGRectGetMaxY(_titleLabel.frame)+kMargin*3;
    _msgLabel.width = _labelContainer.width;
    
    _forkBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [_topContainer addSubview:_forkBtn];
    _forkBtn.size = (CGSize){50.f, 50.f};
    _forkBtn.right = _topContainer.width;
    _forkBtn.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
    _forkBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    _forkBtn.contentEdgeInsets = UIEdgeInsetsMake(8.f, 0, 0, 8.f);
    
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[USAlertView class]] pathForResource:@"USAlertView" ofType:@"bundle"]];
    UIImage *image = [UIImage imageWithContentsOfFile:[bundle pathForResource:@"icon_fork@2x" ofType:@"png"]];
    UIImage *btnImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    
    [_forkBtn setImage:btnImage forState:UIControlStateNormal];
    [_forkBtn addTarget:self action:@selector(hideAlertView) forControlEvents:UIControlEventTouchUpInside];
    
    _bottomContainer = [UIView new];
    [_containerView addSubview:_bottomContainer];
    _bottomContainer.size = (CGSize){kContentWidth, kBottomContainerHeight};
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_titleLabel.text.length) {
        _labelContainer.height = CGRectGetMaxY(_msgLabel.frame);
    }
    else {
        _labelContainer.height = _msgLabel.height+6*kMargin;
        _msgLabel.top = _msgLabel.superview.height*0.5-_msgLabel.height*0.5+3.f;
    }
    if (_iconImageView.hidden) { //如果不显示icon 居中labelContainer
        _topContainer.height = MAX(_labelContainer.height+kMargin*6, kTopContainerMinHeight-kMargin-kBottomContainerHeight);
        _labelContainer.centerY = _topContainer.centerY;
    }
    else {
        _topContainer.height = CGRectGetMaxY(_labelContainer.frame)+kMargin*4;
    }
    
    _bottomContainer.top = CGRectGetMaxY(_topContainer.frame)+kMargin;
    _containerView.height = _topContainer.height + kMargin + _bottomContainer.height;
    
    _containerView.center = self.center;
}

#pragma mark - Setter

- (void)setShowForkBtn:(BOOL)showForkBtn
{
    _showForkBtn = showForkBtn;
    _forkBtn.hidden = !showForkBtn;
}

#pragma mark - Public

+ (instancetype)showWithMessage:(NSString *)message
{
    USAlertView *alertView = [self initWithTitle:nil message:message cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alertView showWithCompletionBlock:nil];
    
    return alertView;
}

+ (instancetype)showWithTitle:(NSString *)title message:(NSString *)message
{
    USAlertView *alertView = [self initWithTitle:title message:message cancelButtonTitle:@"确定" otherButtonTitles:nil];
    [alertView showWithCompletionBlock:nil];
    
    return alertView;
}


+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle
{
    return [self initWithTitle:title message:message cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
}

+ (instancetype)initWithMessage:(NSString *)message
              cancelButtonTitle:(NSString *)cancelButtonTitle
              otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION
{
    NSMutableArray *otherTitleArray = [NSMutableArray array];
    va_list _arguments;
    va_start(_arguments, otherButtonTitles);
    for (NSString *key = otherButtonTitles; key != nil; key = (__bridge NSString *)va_arg(_arguments, void *)) {
        [otherTitleArray addObject:key];
    }
    va_end(_arguments);
    
    return [self initWithTitle:nil message:message cancelButtonTitle:cancelButtonTitle otherButtonTitleArray:otherTitleArray];
}

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle
            otherButtonTitles:(NSString *)otherButtonTitles, ... NS_REQUIRES_NIL_TERMINATION
{
    NSMutableArray *otherTitleArray = [NSMutableArray array];
    va_list _arguments;
    va_start(_arguments, otherButtonTitles);
    for (NSString *key = otherButtonTitles; key != nil; key = (__bridge NSString *)va_arg(_arguments, void *)) {
        [otherTitleArray addObject:key];
    }
    va_end(_arguments);
    
    return [self initWithTitle:title message:message cancelButtonTitle:cancelButtonTitle otherButtonTitleArray:otherTitleArray];
}

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
            cancelButtonTitle:(NSString *)cancelButtonTitle
        otherButtonTitleArray:(NSArray *)otherButtonTitleArray
{
    return [self initWithTitle:title message:message attributedMsg:nil icon:nil cancelButtonTitle:cancelButtonTitle otherButtonTitleArray:otherButtonTitleArray];
}

+ (instancetype)initWithTitle:(NSString *)title
                      message:(NSString *)message
                attributedMsg:(NSMutableAttributedString *)attributedMsg
                         icon:(UIImage *)icon
            cancelButtonTitle:(NSString *)cancelButtonTitle
        otherButtonTitleArray:(NSArray *)otherButtonTitleArray;
{
    USAlertView *alertView = [USAlertView new];
    
    alertView.iconImageView.image = icon;
    
    if (title.length) {
        alertView.titleLabel.text = title;
    }
    else {
        alertView.titleLabel.hidden = YES;
    }
    
    if (attributedMsg.length) {
        CGFloat msgTextHeight = [attributedMsg.string stringHeightWithFont:attributedMsg.font width:kLabelMaxWidth lineSpacing:attributedMsg.lineSpacing];
        alertView.msgLabel.height = msgTextHeight;
        attributedMsg.alignment = NSTextAlignmentCenter;
        alertView.msgLabel.attributedText = attributedMsg;
    }
    if (message.length) {
        // 隐藏icon
        alertView.iconImageView.hidden = YES;
        
        NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:message];
        attributedString.lineSpacing = 5.f;
        attributedString.color = HexColor(0x535353);
        attributedString.alignment = NSTextAlignmentCenter;
        
        CGFloat msgTextHeight = [attributedString.string stringHeightWithFont:kMsgFont width:kLabelMaxWidth lineSpacing:attributedString.lineSpacing];
        alertView.msgLabel.height = msgTextHeight+3.f;
        alertView.msgLabel.attributedText = attributedString;
    }
    
    NSMutableArray *dataSource = [otherButtonTitleArray mutableCopy];
    if (!cancelButtonTitle||!cancelButtonTitle.length) {
        cancelButtonTitle = @"取消";
    }
    [dataSource insertObject:cancelButtonTitle atIndex:0];
    
    [alertView createBtnWithTitles:dataSource];
    return alertView;
}

+ (instancetype)initWithIcon:(UIImage *)icon
                       title:(NSString *)title
               attributedMsg:(NSMutableAttributedString *)attributedMsg
             doneButtonTitle:(NSString *)doneButtonTitle
{
    NSArray *otherButtonTitleArray = [NSArray array];
    return [self initWithTitle:title message:nil attributedMsg:attributedMsg icon:icon cancelButtonTitle:doneButtonTitle otherButtonTitleArray:otherButtonTitleArray];
}

- (void)showWithCompletionBlock:(void (^)(NSInteger buttonIndex))completionBlock
{
    _completeBlock = completionBlock;
    
    _forkBtn.hidden = !_showForkBtn;
    
    [[USAlertManager shareInstance] handleShowAlertView:self];
}

#pragma mark - Private

- (void)createBtnWithTitles:(NSArray *)dataSource
{
    _btnCount = dataSource.count;
    NSMutableArray <UIView *> *viewArray = [[NSMutableArray alloc] init];
    for (int i = 0; i<MIN(2, dataSource.count); i++) {
        UIView *view = [UIView new];
        [_bottomContainer addSubview:view];
        
        NSString *btnStr = dataSource[dataSource.count-i-1];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = dataSource.count-i;
        [button addTarget:self action:@selector(clickbtn:) forControlEvents:UIControlEventTouchUpInside];
        [button setTitleColor:HexColor(0x535353) forState:UIControlStateNormal];
        button.titleLabel.font = kTitleFont;
        [button setTitle:btnStr forState:UIControlStateNormal];
        [button addTarget:self action:@selector(removeColor:) forControlEvents:UIControlEventTouchUpOutside];
        [button addTarget:self action:@selector(exchangeColor:) forControlEvents:UIControlEventTouchDown];
        [view addSubview:button];
        
        if (dataSource.count == 1) {
            button.backgroundColor = KY_TINT_COLOR;
        }
        else{
            if (i) {
                button.backgroundColor = HexColor(0xd7d7d7);
            }
            else {
                button.backgroundColor = KY_TINT_COLOR;
            }
        }
        
        button.layer.masksToBounds = YES;
        button.layer.cornerRadius = 7.f;
        [button autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
        
        [viewArray addObject:view];
    }
    
    for (int i = 0; i<viewArray.count; i++) {
        
        [viewArray[i] autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:0];
        [viewArray[i] autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:0];
        
        if (i<viewArray.count-1) {
            [viewArray[i] autoPinEdge:ALEdgeLeft toEdge:ALEdgeRight ofView:viewArray[i+1] withOffset:5*WindowZoomScale];
        }
    }
    
    [viewArray[0] autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    [viewArray[viewArray.count-1] autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    
    if (viewArray.count>1) {
        [viewArray autoMatchViewsDimension:ALDimensionWidth];
    }
}

- (void)removeColor:(UIButton *)button{
    if (button.tag == 2) {
        button.backgroundColor = KY_TINT_COLOR;
    }else {
        if (_btnCount == 2) {
            button.backgroundColor = HexColor(0xd7d7d7);
        } else {
            button.backgroundColor = KY_TINT_COLOR;
        }
    }
}

- (void)exchangeColor:(UIButton *)button{
    if (button.highlighted) {
        
        if (button.tag == 2) {
            button.backgroundColor = KY_TINT_HIGHLIGHT_COLOR;
        } else {
            if (_btnCount == 2) {
                button.backgroundColor = HexColor(0xb3b3b3);
            } else {
                button.backgroundColor = KY_TINT_HIGHLIGHT_COLOR;
                
            }
        }
    }
}

- (void)clickbtn:(UIButton *)button
{
    [self clickedIndex:button.tag-1];
}

- (void)clickedIndex:(NSInteger)index{
    _completeBlock?_completeBlock(index):nil;
    [self hideAlertView];
}

- (void)hideAlertView
{
    [[USAlertManager shareInstance] handleAlertViewClick];
}

@end
