//
//  AVAssetData.h
//  TZImagePickerController
//
//  Created by JustinLau on 2020/4/2.
//  Copyright © 2020 谭真. All rights reserved.
//

#ifndef AVAssetData_h
#define AVAssetData_h
/*
 显然，CMTime定义是一个C语言的结构体，CMTime是以分数的形式表示时间，value表示分子，timescale表示分母，flags是位掩码，表示时间的指定状态。
 这里value,timescale是分别以64位和32位整数来存储的，我们从上文已经知道，这样可以避免double类型带来的精度丢失。
 另外，通过用64位整数来表示分子，我们可以为每个timescale表示90亿个不同的正值，最多19位唯一的十进制数字。
 那么timescale又是什么？ 它表示每秒分割的“切片”数。CMTime的整体精度就是受到这个限制的。比如：
 如果timescale为1，则不能有对象表示小于1秒的时间戳，并且时间戳以1秒为增量。类似的，如果timescale是1000，则每秒被分割成1000个，并且该value表示我们要显示的毫秒数。
 所以当你试图表示0.5秒的时候，你千万不能这么写：

 CMTime interval = CMTimeMakeWithSeconds(0.5, 1);
 这里interval实际上是0 而不是0.5。
 所以为了能让你选择合理的时间尺度确保不被截断，Apple建议我们使用600。如果你需要对音频文件进行更精确的所以，你可以把timescale设为60,000或更高。这里64位 value的好处就是，你仍然可以用这种方式来明确的表示580万年的增量，即1/60,000秒。
 timescale只是为了保证时间精度而设置的帧率，并不一定是视频最后实际的播放帧率。
 */

#endif /* AVAssetData_h */
