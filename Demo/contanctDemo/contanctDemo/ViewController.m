//
//  ViewController.m
//  contanctDemo
//
//  Created by jansti on 16/7/14.
//  Copyright © 2016年 jansti. All rights reserved.
//

#import "ViewController.h"
#import <Contacts/Contacts.h>
#import <ContactsUI/ContactsUI.h>

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) CNContactStore *stroe;
@property (nonatomic, strong) NSMutableArray *persons;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    _stroe = [[CNContactStore alloc] init];
    _persons = [NSMutableArray array];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    
    
    CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:@[CNContactNamePrefixKey,CNContactGivenNameKey,CNContactMiddleNameKey,CNContactFamilyNameKey,CNContactImageDataKey,CNContactPhoneNumbersKey,CNContactEmailAddressesKey,CNContactThumbnailImageDataKey,CNContactImageDataAvailableKey]];
    
    [_stroe enumerateContactsWithFetchRequest:fetchRequest error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        [_persons addObject:contact];
    }];
    
    [_tableView reloadData];
    
    
}




- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    
    return _persons.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellIdentifier = @"tableviewCell";
    
    CNContact *contact = _persons[indexPath.row];
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }
    
    
    cell.textLabel.text = contact.familyName;
    if (contact.imageDataAvailable) {
        cell.imageView.image = [UIImage imageWithData:contact.imageData];
    }
    CNLabeledValue *labeledValue = [contact.phoneNumbers firstObject];
    CNPhoneNumber *phoneNumber = labeledValue.value;
    cell.detailTextLabel.text = phoneNumber.stringValue;
//    cell.detailTextLabel.text = contact.phoneNumbers
    
    return cell;
}






- (NSArray *)contacts{
    
    return nil;
}

@end
