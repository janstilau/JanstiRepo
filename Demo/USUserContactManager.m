
//
//  USUserContactManager.m
//  HTWallet
//
//  Created by jansti on 16/7/20.
//  Copyright © 2016年 MaRuJun. All rights reserved.
//

#import "USUserContactManager.h"
#import <Contacts/Contacts.h>
#import <AddressBook/AddressBook.h>

#define kUserContactsFilePath ([NSDocumentPath() stringByAppendingPathComponent:@"Contacts"])

@interface USUserContactManager()

@property (nonatomic, strong) NSMutableArray *userContactsM; // 只包含联系人名字电话数组

@property (nonatomic, strong) CNContactStore *contactStore;
@property (nonatomic, strong) NSMutableArray *contectsM;  // 联系人数组

@property (nonatomic, assign) ABAddressBookRef addBookRef;

@property (nonatomic, assign) BOOL isCommittingContacts;

@end

@implementation USUserContactManager


+ (instancetype)defaultManager
{
    static dispatch_once_t pred = 0;
    __strong static id defaultContactManager = nil;
    dispatch_once( &pred, ^{
        defaultContactManager = [[self alloc] init];
    });
    return defaultContactManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _contectsM = [NSMutableArray array];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:kUserContactsFilePath]) {
            [fileManager createDirectoryAtPath:kUserContactsFilePath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    return self;
}

+ (NSArray *)userContacts
{
    NSFileManager *fileMagager = [NSFileManager defaultManager];
    NSString *contactsPlistPath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    
    if ([fileMagager fileExistsAtPath:contactsPlistPath]) {
        
        NSArray *contacts = [NSArray arrayWithContentsOfFile:contactsPlistPath];
        if (!contacts || !contacts.count) {
            return nil;
        }
        return contacts;
    }
    return nil;
}

+ (void)acquireUserContacts{
    [[self defaultManager] acquireUserContacts];
}

+ (BOOL)userAuthorizationAllowed
{
    BOOL hasGetAuth = NO;
    
    if (NSClassFromString(@"CNContactStore") && SystemVersionGreaterThanOrEqualTo(@"9.0")) {
        CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
        if (status == CNAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
    }
    else{
        ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
        if (status == kABAuthorizationStatusAuthorized) {
            hasGetAuth = YES;
        }
    }
    
    return hasGetAuth;
}


- (void )acquireUserContacts
{
    if (NSClassFromString(@"CNContactStore") && SystemVersionGreaterThanOrEqualTo(@"9.0")) {
        [self getContactsUsingContact];
    }
    else {
        [self getContactsUsingABAddressBook];
    }
}


#pragma mark - CNContact

- (void)getContactsUsingContact
{
    CNAuthorizationStatus status = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    _contactStore = [[CNContactStore alloc] init];
    
    switch (status) {
        case CNAuthorizationStatusNotDetermined:{
            [_contactStore requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError * _Nullable error) {
                
                if (granted && !error) {
                    [self accessUerContact];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self contactDidAuthorized];
                    });
                    
                }else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self contactDidNotAuthorized];
                    });
                }
            }];
        }
            break;
        case CNAuthorizationStatusRestricted:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self contactDidNotAuthorized];
            });
        }
            break;
        case CNAuthorizationStatusDenied:{
            dispatch_async(dispatch_get_main_queue(), ^{
                [self contactDidNotAuthorized];
            });
        }
            break;
        case CNAuthorizationStatusAuthorized:{
            [self accessUerContact];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self contactDidAuthorized];
            });
        }
            break;
            
        default:
            break;
    }
}

- (void)accessUerContact
{
    NSArray *keysToFetch = @[[CNContactFormatter descriptorForRequiredKeysForStyle:CNContactFormatterStyleFullName],
                             CNContactPhoneNumbersKey];
    CNContactFetchRequest *fetchRequest = [[CNContactFetchRequest alloc] initWithKeysToFetch:keysToFetch];
    
    
    BOOL success =  [_contactStore enumerateContactsWithFetchRequest:fetchRequest error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        [_contectsM addObject:contact];
    }];
    
    if (success) {
        [self setupContactsArrayUsingCN];
    }
    else{
        ELOG(@"获取用户通讯录数据异常");
    }
}

- (void)setupContactsArrayUsingCN
{
    _userContactsM = [NSMutableArray array];
    
    [_contectsM enumerateObjectsUsingBlock:^(CNContact *contact, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *name = [CNContactFormatter stringFromContact:contact style:CNContactFormatterStyleFullName];
        NSArray *phoneLabelArray = contact.phoneNumbers;
        
        if (!name || !phoneLabelArray.count) {
           return;
        }
        
        [phoneLabelArray enumerateObjectsUsingBlock:^(CNLabeledValue* phoneLabel, NSUInteger idx, BOOL * _Nonnull stop) {
            CNPhoneNumber *phoneNumber = phoneLabel.value;
            NSString *phone = phoneNumber.stringValue;
            if (phone && phone.length) {
                [_userContactsM addObject:@{ @"name" : name,  @"num" : phone }];
            }
        }];
    }];
    
    NSString *filePath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    [_userContactsM writeToFile:filePath atomically:YES];
    
    _userContactsM = nil;
    _contectsM = nil;
    _contactStore = nil;
    
    [self uploadUserContacts];
}


#pragma mark - ABAddressBoo

- (void)getContactsUsingABAddressBook
{
    _addBookRef = ABAddressBookCreateWithOptions(NULL, NULL); // need to be release
    
    ABAuthorizationStatus status = ABAddressBookGetAuthorizationStatus();
    switch (status) {
        case kABAuthorizationStatusNotDetermined:{
            ABAddressBookRequestAccessWithCompletion(_addBookRef, ^(bool granted, CFErrorRef error) {
                if (granted) {
                    [self accessUerABAddress];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self contactDidAuthorized];
                    });
                }else{
                    dispatch_async(dispatch_get_main_queue(), ^{
                         ELOG(@"用户没有允许通讯录权限");
                        [self contactDidNotAuthorized];
                    });
                }
            });
        }
            break;
        case kABAuthorizationStatusRestricted:
             ELOG(@"用户没有通讯录权限被限制");
            [self contactDidNotAuthorized];
            break;
        case kABAuthorizationStatusDenied:
             ELOG(@"用户没有允许通讯录权限");
            [self contactDidNotAuthorized];
            break;
        case kABAuthorizationStatusAuthorized:{
            [self accessUerABAddress];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self contactDidAuthorized];
            });
        }
            break;
            
        default:
            break;
    }
}

- (void)accessUerABAddress
{
    CFArrayRef allLinkPeople = ABAddressBookCopyArrayOfAllPeople(_addBookRef); // need to release
    CFIndex number = ABAddressBookGetPersonCount(_addBookRef);
    
    _userContactsM = [NSMutableArray array];
    for (int i = 0; i < number; i++) {
        
        ABRecordRef  people = CFArrayGetValueAtIndex(allLinkPeople, i);
        
        NSString*firstName=(__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonFirstNameProperty));
        NSString*lastName=(__bridge_transfer NSString *)(ABRecordCopyValue(people, kABPersonLastNameProperty));
        NSString*middleName=(__bridge_transfer NSString*)(ABRecordCopyValue(people, kABPersonMiddleNameProperty));
        
        NSMutableString *name = [NSMutableString string];
        if (lastName) {
            [name appendString:lastName];
        }
        if (middleName) {
            [name appendString:middleName];
        }
        if (firstName) {
            [name appendString:firstName];
        }
        
        
        ABMultiValueRef phones= ABRecordCopyValue(people, kABPersonPhoneProperty);
        
        if (!name.length || ABMultiValueGetCount(phones) == 0) {
            continue;
        }
        
        for (NSInteger j=0; j < ABMultiValueGetCount(phones); j++) {
            NSString *phone = (__bridge_transfer NSString *)(ABMultiValueCopyValueAtIndex(phones, j));
            if (phone && phone.length) {
                [_userContactsM addObject:@{ @"name": name, @"num" : phone }];
            }
        }
        
        CFRelease(phones);
    }
    CFRelease(allLinkPeople);
    CFRelease(_addBookRef);
    
    _addBookRef = NULL;
    
    NSString *filePath = [kUserContactsFilePath stringByAppendingPathComponent:@"contacts.plist"];
    [_userContactsM writeToFile:filePath atomically:YES];
    
    _userContactsM = nil;
    _contectsM = nil;
    _addBookRef = NULL;
    
    [self uploadUserContacts];
}

#pragma mark - Function

- (void)contactDidNotAuthorized{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(NO)];
}

- (void)contactDidAuthorized{
    
    [[NSNotificationCenter defaultCenter] postNotificationName:Notification_ContactsAuthorized object:@(YES)];
}

+ (void)uploadUserContacts{
    
    [[self defaultManager] uploadUserContacts];
}

- (void)uploadUserContacts
{
    if ([[AuthData objectForKey:UserDefaultKey_ContactsUploaded] boolValue]) {
        return;
    }
    
    if (_isCommittingContacts) {
        return;
    }
    
    NSArray *userContacts = [USUserContactManager userContacts];
    if (!userContacts.count) {
        return;
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"contacts"] = [@{@"userPhoneBook": userContacts } json];
    
    _isCommittingContacts = YES;
    
    [NetManager getCacheToUrl:url_submit_phonebooks params:params request:nil complete:^(BOOL successed, HttpResponse *response) {
        _isCommittingContacts = NO;
        
        if (successed) {
            [AuthData setObject:@(YES) forKey:UserDefaultKey_ContactsUploaded];
        }
    }];
}


+ (void)checkAlreadyUploaded{
    
    if ([[AuthData objectForKey:UserDefaultKey_ContactsUploaded] boolValue]) {
        return;
    }

    NSArray *contacts = [self userContacts];
    if (contacts) {
        [self uploadUserContacts];
    }
}



@end
