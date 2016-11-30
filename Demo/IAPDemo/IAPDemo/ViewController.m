//
//  ViewController.m
//  IAPDemo
//
//  Created by jansti on 16/11/30.
//  Copyright © 2016年 jansti. All rights reserved.
//

#import "ViewController.h"
#import <StoreKit/StoreKit.h>

//-----app store 支付-----
#define ProductID_num_2   @"com.hoolai.moca.flower2"   //$0.99
#define ProductID_num_10  @"com.hoolai.moca.flower10"  //$4.99
#define ProductID_num_37  @"com.hoolai.moca.flower37"  //$14.99
#define ProductID_num_76  @"com.hoolai.moca.flower76"  //$29.99
#define ProductID_num_136 @"com.hoolai.moca.flower136" //$54.99
#define ProductID_num_256 @"com.hoolai.moca.flower256" //$99.99

/** 鲜花膨胀10倍 **/
#define ProductID_num_20   @"com.hoolai.moca.flower20"   //$0.99
#define ProductID_num_100  @"com.hoolai.moca.flower100"  //$4.99
#define ProductID_num_370  @"com.hoolai.moca.flower370"  //$14.99
#define ProductID_num_760  @"com.hoolai.moca.flower760"  //$29.99
#define ProductID_num_1360 @"com.hoolai.moca.flower1360" //$54.99
#define ProductID_num_2560 @"com.hoolai.moca.flower2560" //$99.99


@interface ViewController ()<SKPaymentTransactionObserver,SKProductsRequestDelegate>
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *btns;
@property (nonatomic, strong) NSMutableArray *arrayM;

@end

@implementation ViewController


- (void)viewDidLoad{
    [super viewDidLoad];
    
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // 监听购买的过程
}


- (IBAction)btnClick:(UIButton *)sender {
    
    NSString *text = [sender titleForState:UIControlStateNormal];
    NSInteger number = [text integerValue];
    switch (number) {
        case 1:
            [self firstAction];
            break;
            
        case 2:
            [self secondAction];
            break;
            
        case 3:
            [self thirdAction];
            break;
            
        case 4:
            
            break;
            
        default:
            break;
    }
}



- (void)firstAction{
    
    //2016-11-30 11:11:49.729372 IAPDemo[27018:7119639] [MC] System group container for systemgroup.com.apple.configurationprofiles path is /private/var/containers/Shared/SystemGroup/systemgroup.com.apple.configurationprofiles
    //2016-11-30 11:11:49.736429 IAPDemo[27018:7119639] [MC] Reading from public effective user settings.
    // 在这里,打印了上面的一段话,这里应该读的本机配置,也就是用户设置可不可以内购.
    
    if( [SKPaymentQueue canMakePayments]){
        NSLog(@"应用可以支付");
    }else {
        NSLog(@"失败,用户禁止应用内支付");
    }
    
}


// 获得所有的付费Product ID列表。这个可以用常量存储在本地，也可以由自己的服务器返回。
// 也就是说,product id的列表,不是从apple直接获取的,要记录下来.
// 制作一个界面，展示所有的应用内付费项目。这些应用内付费项目的价格和介绍信息可以是自己的服务器返回。但如果是不带服务器的单机游戏应用或工具类应用，则可以通过向App Store查询获得。我在测试时发现，向App Store查询速度非常慢，通常需要2-3秒钟，所以不建议这么做，最好还是搞个自己的服务器吧。

- (void)secondAction {
    NSLog(@"开始询问商品信息");
    NSSet * set = [NSSet setWithArray:@[ProductID_num_20]];
    SKProductsRequest * request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
}


#pragma mark - 请求信息 <SKRequestDelegate> 请求协议
- (void)requestDidFinish:(SKRequest *)request
{
    NSLog(@"---------所有支付请求已经完成--------------");
}
//弹出错误信息
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"-------请求支付失败----------");
}

static SKProduct *_product = nil;
#pragma mark - <SKProductsRequestDelegate> 请求商品信息的回调
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    
    NSLog(@"接受到了商品信息");
    NSArray *products = response.products;
    
    [products enumerateObjectsUsingBlock:^(SKProduct  *product, NSUInteger idx, BOOL * _Nonnull stop) {
        NSLog(@"-----------product info-----------");
        NSLog(@"SKProduct 描述信息%@", [product description]);
        NSLog(@"产品标题 %@" , product.localizedTitle);
        NSLog(@"产品描述信息: %@" , product.localizedDescription);
        NSLog(@"价格: %@" , product.price);
        NSLog(@"Product id: %@" , product.productIdentifier);
    }];
    
    
    _product = products.firstObject;
    
}
/*
 
 (lldb) po product
 <SKProduct: 0x170015680>
 
 (lldb) po product.localizedDescription
 购买20朵鲜花，共计消费6元，购买完成后可以在"个人中心"进行查看
 
 (lldb) po product.localizedTitle
 20朵鲜花
 
 (lldb) po product.price
 6
 
 (lldb) po product.priceLocale
 <__NSCFLocale: 0x1740db3c0> 'zh_CN@currency=CNY'}
 
 (lldb) po product.productIdentifier
 com.hoolai.moca.flower20
 
 (lldb) po product.downloadable
 NO
 
 (lldb) po product.downloadContentLengths
 nil
 (lldb) po product.downloadContentVersion
 nil
 
 */


- (void)thirdAction {
    
    NSLog(@"开始向Apple开始支付流程");
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:_product];
/*
    NSString *uid = [[AuthData loginUser] uid];
    NSString *identifier = [[uid stringByAppendingString:@"^&*14HGtj89kuYRThgbn+-"] md5];
    identifier = [identifier stringByAppendingString:[[NSString stringWithFormat:@"{23UjrYMB12[]}"] sha1]];
    identifier = [[identifier stringByAppendingString:[uid crc32]] sha512];
    payment.applicationUsername = [[[identifier md5] sha512] sha1];
 
 */
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

/*
 applicationUsername
 An opaque identifier for the user’s account on your system.
 Use this property to help the store detect irregular activity. For example, in a game, it would be unusual for dozens of different iTunes Store accounts to make purchases on behalf of the same in-game character.
 The recommended implementation is to use a one-way hash of the user’s account name to calculate the value for this property.
 */

/*
 (lldb) po payment
 <SKPayment: 0x170007780>
 
 (lldb) po payment.productIdentifier
 com.hoolai.moca.flower20
 
 (lldb) po payment.requestData
 0x0000000000000000
 
 (lldb) po payment.quantity
 1
 
 (lldb) po payment.applicationUsername
 0x0000000000000000
 
 (lldb) po payment.simulatesAskToBuyInSandbox
 NO

 */


#pragma mark - <SKPaymentTransactionObserver> 监听购买结果,千万不要忘记绑定
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions //交易结果
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
                //交易完成
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
                
                //交易失败
            case SKPaymentTransactionStateFailed: {
                [self failedTransaction:transaction];
                break;
                
                //已经购买过该商品
            }
            case SKPaymentTransactionStateRestored:
                NSLog(@"-----已经购买过该商品 --------");
                [self restoreTransaction:transaction];
                
                //商品添加进列表
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"-----商品添加进列表 --------");
                break;
            default:
                break;
        }
    }
}

//交易完成的后续自定义操作
- (void)completeTransaction: (SKPaymentTransaction *)transaction{
    // verifyPruchase
    // 验证凭据，获取到苹果返回的交易凭据
    // appStoreReceiptURL iOS7.0增加的，购买交易完成后，会将凭据存放在该地址
    NSData *receipt = nil;
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    // 从沙盒中获取到购买凭据
    receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) {
        /* No local receipt -- handle the error. */
        
        NSLog(@"没有获取到收据信息");
        return;
    }
    
    if (![receipt respondsToSelector:@selector(base64EncodedStringWithOptions:)]) {
        NSLog(@"购买反馈信息异常");
        // why
        return;
    }

    BOOL checkInYourServer = NO;
    if (checkInYourServer) {
        [self checkWithYourServer: receipt];
    }else {
        [self checkWithAppleServer: receipt];
    }
    
    
    // Remove the transaction from the payment queue.
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}


// The unique server-provided identifier.  Only valid if state is SKPaymentTransactionStatePurchased or SKPaymentTransactionStateRestored.
//@property(nonatomic, readonly, nullable) NSString *transactionIdentifier

- (void)checkWithYourServer: (NSData *)receipt{
    /*
     NSMutableDictionary *params = [NSMutableDictionary dictionary];
     params[@"uid"] = _loginUser.uid;
     params[@"receipt"] = [receipt base64EncodedString];
     params[@"order_id"] = transaction.transactionIdentifier;
     
     //缓存得到的购买收据 -- 防止网络问题上传失败
     NSMutableArray *cacheArray = [[AuthData objectForKey:UserDefaultKey_receiptCache] mutableCopy];
     if (!cacheArray) {
     cacheArray = [[NSMutableArray alloc] init];
     }
     [cacheArray  addObject:params];
     [AuthData  setObject:cacheArray forKey:UserDefaultKey_receiptCache];
     
     [MobClick event:EventId_BuySuccess];
     [loadingView setLoadingText:@"正在验证购买凭证"];
     
     [NetManager postRequestToUrl:url_appstore_receipt params:params complete:^(BOOL successed, HttpResponse *response) {
     NSDictionary *result = response.payload;
     if (successed) {
     FLOG(@"-----交易完成 --------");
     [MCAlertView showWithMessage:@"验证购买凭证成功，鲜花已到账"];
      购买完成,就把这一项混存的数据去掉
     NSMutableArray *cacheArray = [[AuthData objectForKey:UserDefaultKey_receiptCache] mutableCopy];
     if (cacheArray) {
     [cacheArray removeObject:params];
     [AuthData  setObject:cacheArray forKey:UserDefaultKey_receiptCache];
     }
     
     //更新鲜花数量和VIP等级
     _loginUser.level = @([result[@"level"] intValue]);
     _loginUser.flower_count = @([result[@"rmb"] intValue] / 3);
     [_loginUser saveWithComplete:nil];
     
     }else{
     [MCAlertView showWithMessage:@"验证购买凭证失败，请尝试在网络畅通环境下重新进入该页面"];
     }
     [TCLoadingView removeLoadingView];
     }];

     
     
     */
}

// 与苹果的验证接口文档在这里。简单来说就是将该购买凭证用Base64编码，然后POST给苹果的验证服务器，苹果将验证结果以JSON形式返回。

- (void)checkWithAppleServer: (NSData *)receipt{
    // 发送网络POST请求，对购买凭据进行验证
    // 下面的应该就是对票据进行检验的实际操作,也就是放在服务器的操作.mc把用户的id,交易id,还有票据给了服务器端.向apple验证的话,需要票据就可以.
    //测试验证地址:https://sandbox.itunes.apple.com/verifyReceipt
    //正式验证地址:https://buy.itunes.apple.com/verifyReceipt
    
    NSURL *url = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
    NSMutableURLRequest *urlRequest =
    [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0f];
    urlRequest.HTTPMethod = @"POST";
    NSString *encodeStr = [receipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    NSString *payload = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", encodeStr];
    NSData *payloadData = [payload dataUsingEncoding:NSUTF8StringEncoding];
    urlRequest.HTTPBody = payloadData;
    // 提交验证请求，并获得官方的验证JSON结果 iOS9后更改了另外的一个方法
    NSData *result = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:nil error:nil];
    // 官方验证结果为空
    if (result == nil) {
        NSLog(@"验证失败");
        return;
    }
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:result options:NSJSONReadingAllowFragments error:nil];
    if (dict != nil) {
        // 比对字典中以下信息基本上可以保证数据安全
        // bundle_id , application_version , product_id , transaction_id
        NSLog(@"验证成功！购买的商品是：%@", @"_productName");
    }
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished: (SKPaymentTransaction *)transaction
{
    NSLog(@"the payment queue has finished sending restored transactions.");
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
-(void) paymentQueue:(SKPaymentQueue *) paymentQueue restoreCompletedTransactionsFailedWithError:(NSError *)error{
    NSLog(@"an error occurred while restoring transactions.");
}


- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:animated];
    [self checkReceiptCache];
    // 这个页面每次进入的时候,就验证一下有没有缓存的票据.避免网络原因导致没有加上花.
    // 里面缓存的信息,是上次的网络请求的时候,缓存的需要的网络参数,包括票据.
}

//检测是否有没有上传到服务器端的证书

- (void)checkReceiptCache
{
    /*
    NSMutableArray *cacheArray = [[AuthData objectForKey:UserDefaultKey_receiptCache] mutableCopy];
    if (!cacheArray || !cacheArray.count) {
        return;
    }
    
    for (NSDictionary *params in cacheArray) {
        [TCLoadingView showWithRequestClass:self text:@"正在验证购买凭证"];
        [NetManager postRequestToUrl:url_appstore_receipt params:params complete:^(BOOL successed, HttpResponse *response) {
            NSDictionary *result = response.payload;
            if (successed) {
                [MCAlertView showWithMessage:@"验证购买凭证成功，鲜花已到账"];
                // 购买完成,就把这一项混存的数据去掉
                NSMutableArray *cacheArray = [[AuthData objectForKey:UserDefaultKey_receiptCache] mutableCopy];
                if (cacheArray) {
                    [cacheArray removeObject:params];
                    [AuthData  setObject:cacheArray forKey:UserDefaultKey_receiptCache];
                }
                //更新鲜花数量和VIP等级
                _loginUser.level = @([result[@"level"] intValue]);
                _loginUser.flower_count = @((int)(result[@"rmb"]) / 3);
                [_loginUser saveWithComplete:nil];
            }else{
                [MCAlertView showWithMessage:@"验证购买凭证失败，请尝试在网络畅通环境下重新进入该页面"];
            }
            [TCLoadingView removeLoadingView];
        }];
    }
     */
}



#pragma mark -交易失败后续自定义处理
- (void)failedTransaction: (SKPaymentTransaction *)transaction
{
    NSLog(@"-----交易失败: %@ -------- ",transaction.error.localizedDescription);
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    
    NSString *errorInfo = [NSString stringWithFormat:@"%@，请重新尝试购买～",transaction.error.localizedDescription];
    NSLog(@"%@",errorInfo);
}

#pragma mark -已经购买过该商品后续自定义处理
- (void) restoreTransaction: (SKPaymentTransaction *)transaction
{
    NSLog(@"交易恢复处理");
}



-(void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];//解除监听
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}




@end
