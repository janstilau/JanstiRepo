/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>

// 这个 protocal 只有一个 cancel. 猜测就是设置一个标志位, 等到执行的时候, 放弃执行.
// 实现证明就是这样, 其实, 只要一个类继承了这个接口, 但是定义协议的好处就在于, 用抽象的思想, 去管理复杂的子类. SDWenImageCombinedOperation 的 cancle 里面, 除了设置 cancle 标志位之外, 还调用了自己的 cancleBlock
@protocol SDWebImageOperation <NSObject>

- (void)cancel;

@end
