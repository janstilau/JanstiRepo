//
//  ViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "ViewController.h"
#import "MediaViewController.h"
#import "MediaItem.h"
#import "MediaCell.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray<MediaItem *> *items;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setupHTTPCache];
    });
    [self setupItems];
}

- (void)setupHTTPCache
{
    [KTVHTTPCache logSetConsoleLogEnable:YES];
    NSError *error = nil;
    [KTVHTTPCache proxyStart:&error];
    if (error) {
        NSLog(@"Proxy Start Failure, %@", error);
    } else {
        NSLog(@"Proxy Start Success");
    }
    [KTVHTTPCache encodeSetURLConverter:^NSURL *(NSURL *URL) {
        NSLog(@"URL Filter reviced URL : %@", URL);
        return URL;
    }];
    [KTVHTTPCache downloadSetUnacceptableContentTypeDisposer:^BOOL(NSURL *URL, NSString *contentType) {
        NSLog(@"Unsupport Content-Type Filter reviced URL : %@, %@", URL, contentType);
        return NO;
    }];
}

- (void)setupItems
{
    MediaItem *item1 = [[MediaItem alloc] initWithTitle:@"萧亚轩 - 冲动"
                                              URLString:@"http://tb-video.bdstatic.com/tieba-smallvideo-transcode/5875812_30cc0de58361ea3812c7f7ad28006908_3.mp4"];
    MediaItem *item2 = [[MediaItem alloc] initWithTitle:@"张惠妹 - 你是爱我的"
                                              URLString:@"http://tb-video.bdstatic.com/tieba-smallvideo-transcode/480447_5f2658dff8c0892e41df29bf2944c5ec_3.mp4"];
    MediaItem *item3 = [[MediaItem alloc] initWithTitle:@"hush! - 都是你害的"
                                              URLString:@"http://tb-video.bdstatic.com/tieba-smallvideo/14_4919b0fc00a457f30eb88580d1da7f1c.mp4"];
    MediaItem *item4 = [[MediaItem alloc] initWithTitle:@"张学友 - 我真的受伤了"
                                              URLString:@"http://tb-video.bdstatic.com/tieba-smallvideo-transcode/4056041_f9f739b334a49e460d89f646075c13cd_0.mp4"];
    
    self.items = @[item1, item2, item3, item4];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaItem *item = [self.items objectAtIndex:indexPath.row];
    MediaCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
    [cell configureWithTitle:item.title];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaItem *item = [self.items objectAtIndex:indexPath.row];
    NSString *URLString = [item.URLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *URL = [KTVHTTPCache proxyURLWithOriginalURL:[NSURL URLWithString:URLString]]; // 直接对于 KTVHttpCache 的利用
    MediaViewController *vc = [[MediaViewController alloc] initWithURLString:URL.absoluteString];
    [self presentViewController:vc animated:YES completion:nil];
    /*
     原始的视频地址.
     http://tb-video.bdstatic.com/tieba-smallvideo-transcode/5875812_30cc0de58361ea3812c7f7ad28006908_3.mp4
     修改后的视频地址.
     http://localhost:80/request.mp4?url=http%3A%2F%2Ftb-video.bdstatic.com%2Ftieba-smallvideo-transcode%2F5875812_30cc0de58361ea3812c7f7ad28006908_3.mp4
     */
}


@end
