//
//  TZAlbumPickerController.m
//
//  Created by JustinLau on 2020/3/30.
//  Copyright © 2020 谭真. All rights reserved.
//

#import "TZAlbumPickerController.h"
#import "TZImagePickerController.h"
#import "TZPhotoPickerController.h"
#import "TZPhotoPreviewController.h"
#import "TZAssetModel.h"
#import "TZAssetCell.h"
#import "UIView+Layout.h"
#import "TZImageManager.h"
#import "TZAlbumPickerController.h"


@interface TZAlbumPickerController ()<UITableViewDataSource,UITableViewDelegate> {
    UITableView *_tableView;
}

@property (nonatomic, strong) NSMutableArray *albumArr;

@end

@implementation TZAlbumPickerController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initData];
    [self setupViews];
    [self configureNavBar];
}

- (void)initData {
    _isFirstAppear = YES;
}

- (void)setupViews {
    self.view.backgroundColor = [UIColor whiteColor];
    
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.rowHeight = 70;
    _tableView.backgroundColor = [UIColor whiteColor];
    _tableView.tableFooterView = [[UIView alloc] init];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    [_tableView registerClass:[TZAlbumCell class] forCellReuseIdentifier:@"TZAlbumCell"];
    [self.view addSubview:self->_tableView];
}

- (void)configureNavBar {
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithTitle:imagePickerVc.cancelBtnTitleStr style:UIBarButtonItemStylePlain target:imagePickerVc action:@selector(cancelButtonClick)];
    [TZCommonTools configBarButtonItem:cancelItem tzImagePickerVc:imagePickerVc];
    self.navigationItem.rightBarButtonItem = cancelItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 所有的配置, 都要到 TZImagePickerController 中去读取.
    // TZImagePickerController 更多的是, 一个配置类, 而不简单的是 NavigationController 类.
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    [imagePickerVc hideProgressHUD];
    if (imagePickerVc.allowPickingImage) {
        self.navigationItem.title = [NSBundle tz_localizedStringForKey:@"Photos"];
    } else if (imagePickerVc.allowPickingVideo) {
        self.navigationItem.title = [NSBundle tz_localizedStringForKey:@"Videos"];
    }
    
    if (self.isFirstAppear && !imagePickerVc.navLeftBarButtonSettingBlock) {
        self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[NSBundle tz_localizedStringForKey:@"Back"] style:UIBarButtonItemStylePlain target:nil action:nil];
    }
    
    [self configTableView];
}

- (void)configTableView {
    if (![[TZImageManager manager] authorizationStatusAuthorized]) { return; }
    if (self.isFirstAppear) {
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        [imagePickerVc showProgressHUD];
    }

    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [[TZImageManager manager] getAllAlbums:imagePickerVc.allowPickingVideo allowPickingImage:imagePickerVc.allowPickingImage needFetchAssets:!self.isFirstAppear completion:^(NSArray<TZAlbumModel *> *models) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self->_albumArr = [NSMutableArray arrayWithArray:models];
                for (TZAlbumModel *albumModel in self->_albumArr) {
                    albumModel.selectedModels = imagePickerVc.selectedModels;
                }
                [imagePickerVc hideProgressHUD];
                
                if (self.isFirstAppear) {
                    self.isFirstAppear = NO;
                    [self configTableView];
                }
                
                [self->_tableView reloadData];
            });
        }];
    });
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    TZImagePickerController *tzImagePicker = (TZImagePickerController *)self.navigationController;
    if (tzImagePicker && [tzImagePicker isKindOfClass:[TZImagePickerController class]]) {
        return tzImagePicker.statusBarStyle;
    }
    return [super preferredStatusBarStyle];
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGFloat top = 0;
    CGFloat tableViewHeight = 0;
    CGFloat naviBarHeight = self.navigationController.navigationBar.tz_height;
    BOOL isStatusBarHidden = [UIApplication sharedApplication].isStatusBarHidden;
    BOOL isFullScreen = self.view.tz_height == [UIScreen mainScreen].bounds.size.height;
    if (self.navigationController.navigationBar.isTranslucent) {
        top = naviBarHeight;
        if (!isStatusBarHidden && isFullScreen) top += [TZCommonTools tz_statusBarHeight];
        tableViewHeight = self.view.tz_height - top;
    } else {
        tableViewHeight = self.view.tz_height;
    }
    _tableView.frame = CGRectMake(0, top, self.view.tz_width, tableViewHeight);
}

#pragma mark - UITableViewDataSource && Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _albumArr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TZAlbumCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TZAlbumCell"];
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    cell.albumCellDidLayoutSubviewsBlock = imagePickerVc.albumCellDidLayoutSubviewsBlock;
    cell.albumCellDidSetModelBlock = imagePickerVc.albumCellDidSetModelBlock;
    cell.selectedCountButton.backgroundColor = imagePickerVc.iconThemeColor;
    cell.model = _albumArr[indexPath.row];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    TZPhotoPickerController *photoPickerVc = [[TZPhotoPickerController alloc] init];
    photoPickerVc.columnNumber = self.columnNumber;
    TZAlbumModel *model = _albumArr[indexPath.row];
    photoPickerVc.model = model;
    [self.navigationController pushViewController:photoPickerVc animated:YES];
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
}

@end
