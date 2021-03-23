//
//  ViewController.m
//  BundleSummary
//
//  Created by JustinLau on 2021/3/23.
//

#import "ViewController.h"
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
    [self staticLib];
}

- (void)staticLib {
    [StaticLib log];
    _imageView.image = [StaticLib getImage];
    NSLog(@"imageView image is %@", _imageView.image);
    _imageView.image = [StaticLib getImageFromAsset];
    NSLog(@"imageView image is %@", _imageView.image);
}

- (void)staticFramework {
    
}

- (void)dynamicFrameWork {
    
}



@end
