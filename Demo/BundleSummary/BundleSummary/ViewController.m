//
//  ViewController.m
//  BundleSummary
//
//  Created by JustinLau on 2021/3/23.
//

#import "ViewController.h"
#import <StaticFramework/StaticFramework.h>
#import <DynamicFramework/DynamicFramework.h>
#import "StaticLib.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)btnDidClicked:(id)sender {
    [self dynamicFrameWork];
}

- (void)staticLib {
    [StaticLib log];
    _imageView.image = [StaticLib getImage];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [StaticLib getImageFromAsset];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [StaticLib getImageFromBundle];
    NSLog(@"imageView image is %@", _imageView.image);
}

- (void)staticFramework {
    [StaticFrameworkEntry log];
    _imageView.image = [StaticFrameworkEntry getImage];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [StaticFrameworkEntry getImageFromAsset];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [StaticFrameworkEntry getImageFromBundle];
    NSLog(@"imageView image is %@", _imageView.image);
}

- (void)dynamicFrameWork {
    [DynamicFrameworkEntry log];
    _imageView.image = [DynamicFrameworkEntry getImage];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [DynamicFrameworkEntry getImageFromAsset];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [DynamicFrameworkEntry getImageFromBundle];
    NSLog(@"imageView image is %@", _imageView.image);
}



@end
