//
//  ViewController.m
//  strokeDemo
//
//  Created by JustinLau on 2019/7/2.
//  Copyright © 2019 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (nonatomic, strong) UILabel *topLabel;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
   
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    NSMutableAttributedString *gottenContentM = [[NSMutableAttributedString alloc] init];
    NSDictionary *normalAttris = @{
                                   NSFontAttributeName: [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold],
                                   NSForegroundColorAttributeName: [UIColor whiteColor],
                                   };
    NSDictionary *numAttris = @{
                                NSFontAttributeName: [UIFont systemFontOfSize:37 weight:UIFontWeightSemibold],
                                NSForegroundColorAttributeName: [UIColor whiteColor],
                                NSStrokeColorAttributeName: [UIColor whiteColor],
                                NSStrokeWidthAttributeName: @(-12),
                                };
    NSString *charName = @"本田东之助呵呵哒";
    if (charName.length >= 6) {
        charName = [NSString stringWithFormat:@"%@..", [charName substringToIndex:6]];
    }
    NSString *former = [NSString stringWithFormat:@"获取%@", charName];
    //    NSAttributedString *formerAttriStr = [[NSAttributedString alloc] initWithString:former attributes:normalAttris];
    //    [gottenContentM appendAttributedString:formerAttriStr];
    NSString *num = [NSString stringWithFormat:@"%@股", @(0.1)];
    NSAttributedString *numAttriStr = [[NSAttributedString alloc] initWithString:num attributes:numAttris];
    [gottenContentM appendAttributedString:numAttriStr];
    _label.attributedText = gottenContentM;
    
    UILabel *topLabel = [[UILabel alloc] init];
    _topLabel = topLabel;
    NSDictionary *topNumAttris = @{
                                   NSFontAttributeName: [UIFont systemFontOfSize:37 weight:UIFontWeightSemibold],
                                   NSForegroundColorAttributeName: [UIColor redColor],
                                   NSStrokeColorAttributeName: [UIColor whiteColor],
                                   NSStrokeWidthAttributeName: @(-3),
                                   };
    NSString *numStr = [NSString stringWithFormat:@"%@股", @(0.1)];
    NSMutableAttributedString *gottenContentTopM = [[NSMutableAttributedString alloc] init];
    NSAttributedString *numAttriStrTop = [[NSAttributedString alloc] initWithString:numStr attributes:topNumAttris];
    [gottenContentTopM appendAttributedString:numAttriStrTop];
    _topLabel.attributedText = gottenContentTopM;
    [_topLabel sizeToFit];
    _topLabel.center = CGPointMake(375/2.0, 667/2.0);
    [self.view addSubview:_topLabel];
}




@end
