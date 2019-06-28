//
//  ViewController.m
//  tinyDemo
//
//  Created by JustinLau on 2019/6/27.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UIImage *image = [UIImage imageNamed:@"img_msg_box"];
    CGFloat width = image.size.width;
    CGFloat height = image.size.height;
    UIEdgeInsets insets = UIEdgeInsetsMake(height*0.5, 20, height*0.5-1, 20);
    image = [image resizableImageWithCapInsets:insets resizingMode:UIImageResizingModeStretch];
    _imageView.image = image;
}

@end
