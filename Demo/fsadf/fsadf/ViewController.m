//
//  ViewController.m
//  fsadf
//
//  Created by JustinLau on 2019/6/25.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIView *whiteVewi;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UIImage *image = [UIImage imageNamed:@"rect"];
    CGFloat imageWH = image.size.width * 0.5;
    image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(imageWH-1, 3, imageWH -1, imageWH -1) resizingMode:UIImageResizingModeStretch];
    _imageView.image = image;

    _whiteVewi.layer.backgroundColor = [UIColor colorWithRed:255/255.0 green:255/255.0 blue:255/255.0 alpha:1.0].CGColor;
    _whiteVewi.layer.shadowColor = [UIColor yellowColor].CGColor;
    _whiteVewi.layer.shadowOffset = CGSizeMake(0, -3);
    _whiteVewi.layer.shadowOpacity = 1;
    _whiteVewi.layer.shadowRadius = 3.0;
}


@end
