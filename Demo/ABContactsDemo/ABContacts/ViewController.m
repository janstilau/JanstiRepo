//
//  ViewController.m
//  ABContacts
//
//  Created by jansti on 16/7/14.
//  Copyright © 2016年 jansti. All rights reserved.
//

#import "ViewController.h"
#import <AddressBook/AddressBook.h>

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, assign) ABAddressBookRef addressBook;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *persons;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _addressBook =  ABAddressBookCreateWithOptions(NULL, NULL);
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _persons = [NSMutableArray array];
    
    [self checkAddressBookAccess];
}

-(void)checkAddressBookAccess
{
    switch (ABAddressBookGetAuthorizationStatus())
    {
            // Update our UI if the user has granted access to their Contacts
        case  kABAuthorizationStatusAuthorized:
            [self accessGrantedForAddressBook];
            break;
            // Prompt the user for access to Contacts if there is no definitive answer
        case  kABAuthorizationStatusNotDetermined :
            [self requestAddressBookAccess];
            break;
            // Display a message if the user has denied or restricted access to Contacts
        case  kABAuthorizationStatusDenied:
        case  kABAuthorizationStatusRestricted:
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Privacy Warning"
                                                            message:@"Permission was not granted for Contacts."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        }
            break;
        default:
            break;
    }
}


// Prompt the user for access to their Address Book data
-(void)requestAddressBookAccess
{
    ViewController * __weak weakSelf = self;
    
    ABAddressBookRequestAccessWithCompletion(self.addressBook, ^(bool granted, CFErrorRef error)
                                             {
                                                 if (granted)
                                                 {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         [weakSelf accessGrantedForAddressBook];
                                                         
                                                     });
                                                 }
                                             });
}

-(void)accessGrantedForAddressBook
{
    // Load data from the plist file
    
    
    
    CFArrayRef allLinkPeople = ABAddressBookCopyArrayOfAllPeople(_addressBook);
    //获取联系人总数
    CFIndex number = ABAddressBookGetPersonCount(_addressBook);
    //进行遍历
    for (NSInteger i=0; i<number; i++) {
        //获取联系人对象的引用
        ABRecordRef  people = CFArrayGetValueAtIndex(allLinkPeople, i);
        //获取当前联系人名字
        NSString*firstName=(__bridge NSString *)(ABRecordCopyValue(people, kABPersonFirstNameProperty));
        //获取当前联系人姓氏
        NSString*lastName=(__bridge NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
        //获取当前联系人中间名
        NSString*middleName=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonMiddleNameProperty));
        //获取当前联系人的名字前缀
        NSString*prefix=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonPrefixProperty));
        //获取当前联系人的名字后缀
        NSString*suffix=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonSuffixProperty));
        //获取当前联系人的昵称
        NSString*nickName=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonNicknameProperty));
        //获取当前联系人的名字拼音
        NSString*firstNamePhoneic=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonFirstNamePhoneticProperty));
        //获取当前联系人的姓氏拼音
        NSString*lastNamePhoneic=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonLastNamePhoneticProperty));
        //获取当前联系人的中间名拼音
        NSString*middleNamePhoneic=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonMiddleNamePhoneticProperty));
        //获取当前联系人的公司
        NSString*organization=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonOrganizationProperty));
        //获取当前联系人的职位
        NSString*job=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonJobTitleProperty));
        //获取当前联系人的部门
        NSString*department=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonDepartmentProperty));
        //获取当前联系人的生日
        NSString*birthday=(__bridge NSDate*)(ABRecordCopyValue(people, kABPersonBirthdayProperty));
        NSMutableArray * emailArr = [[NSMutableArray alloc]init];
        //获取当前联系人的邮箱 注意是数组
        ABMultiValueRef emails= ABRecordCopyValue(people, kABPersonEmailProperty);
        for (NSInteger j=0; j<ABMultiValueGetCount(emails); j++) {
            [emailArr addObject:(__bridge NSString *)(ABMultiValueCopyValueAtIndex(emails, j))];
        }
        //获取当前联系人的备注
        NSString*notes=(__bridge NSString*)(ABRecordCopyValue(people, kABPersonNoteProperty));
        //获取当前联系人的电话 数组
        NSMutableArray * phoneArr = [[NSMutableArray alloc]init];
        ABMultiValueRef phones= ABRecordCopyValue(people, kABPersonPhoneProperty);
        for (NSInteger j=0; j<ABMultiValueGetCount(phones); j++) {
            [phoneArr addObject:(__bridge NSString *)(ABMultiValueCopyValueAtIndex(phones, j))];
        }
        //获取创建当前联系人的时间 注意是NSDate
        NSDate*creatTime=(__bridge NSDate*)(ABRecordCopyValue(people, kABPersonCreationDateProperty));
        //获取最近修改当前联系人的时间
        NSDate*alterTime=(__bridge NSDate*)(ABRecordCopyValue(people, kABPersonModificationDateProperty));
        //获取地址
        ABMultiValueRef address = ABRecordCopyValue(people, kABPersonAddressProperty);
        for (int j=0; j<ABMultiValueGetCount(address); j++) {
            //地址类型
            NSString * type = (__bridge NSString *)(ABMultiValueCopyLabelAtIndex(address, j));
            NSDictionary * temDic = (__bridge NSDictionary *)(ABMultiValueCopyValueAtIndex(address, j));
            //地址字符串，可以按需求格式化
            NSString * adress = [NSString stringWithFormat:@"国家:%@\n省:%@\n市:%@\n街道:%@\n邮编:%@",[temDic valueForKey:(NSString*)kABPersonAddressCountryKey],[temDic valueForKey:(NSString*)kABPersonAddressStateKey],[temDic valueForKey:(NSString*)kABPersonAddressCityKey],[temDic valueForKey:(NSString*)kABPersonAddressStreetKey],[temDic valueForKey:(NSString*)kABPersonAddressZIPKey]];
        }
        //获取当前联系人头像图片
        NSData*userImage=(__bridge NSData*)(ABPersonCopyImageData(people));
        //获取当前联系人纪念日
        NSMutableArray * dateArr = [[NSMutableArray alloc]init];
        ABMultiValueRef dates= ABRecordCopyValue(people, kABPersonDateProperty);
        for (NSInteger j=0; j<ABMultiValueGetCount(dates); j++) {
            //获取纪念日日期
            NSDate * data =(__bridge NSDate*)(ABMultiValueCopyValueAtIndex(dates, j));
            //获取纪念日名称
            NSString * str =(__bridge NSString*)(ABMultiValueCopyLabelAtIndex(dates, j));
            NSDictionary * temDic = [NSDictionary dictionaryWithObject:data forKey:str];
            [dateArr addObject:temDic];
        }
    
        [_persons addObject:(__bridge_transfer id)(people)];
}
    
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return _persons.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    static NSString *cellIdentifier = @"tableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    id obj = _persons[indexPath.row];
    ABRecordRef people = (__bridge ABRecordRef )obj;
    NSMutableArray * phoneArr = [[NSMutableArray alloc]init];
    ABMultiValueRef phones= ABRecordCopyValue(people, kABPersonPhoneProperty);
    for (NSInteger j=0; j<ABMultiValueGetCount(phones); j++) {
        [phoneArr addObject:(__bridge NSString *)(ABMultiValueCopyValueAtIndex(phones, j))];
    }
    
    NSString *str = [phoneArr firstObject];
    cell.detailTextLabel.text = str;
    NSString*lastName=(__bridge NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
    
    cell.textLabel.text = lastName;

    
    return cell;
}




@end
