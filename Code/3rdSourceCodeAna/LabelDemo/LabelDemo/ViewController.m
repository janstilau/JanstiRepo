//
//  ViewController.m
//  LabelDemo
//
//  Created by JustinLau on 2019/1/28.
//  Copyright © 2019年 JustinLau. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString * htmlString = @"<html><body> <p><a class=\"member_mention\" href=\"https://www.zhihu.com/people/1489f98f6d8929029842000b0a69b5dd\" data-hash=\"1489f98f6d8929029842000b0a69b5dd\">@腾讯科技</a> @123456 呵呵哒</p>Some html string \n <font size=\"13\" color=\"red\">This is some text!</font> </body></html>";
    NSAttributedString * attrStr = [[NSAttributedString alloc] initWithData:[htmlString dataUsingEncoding:NSUnicodeStringEncoding] options:@{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType } documentAttributes:nil error:nil];
    _label.attributedText = attrStr;
}


@end
