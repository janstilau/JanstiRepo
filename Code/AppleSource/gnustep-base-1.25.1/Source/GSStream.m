#import "common.h"

#import "Foundation/NSArray.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSValue.h"

#import "GSStream.h"
#import "GSPrivate.h"
#import "GSSocketStream.h"

NSString * const NSStreamDataWrittenToMemoryStreamKey
= @"NSStreamDataWrittenToMemoryStreamKey";
NSString * const NSStreamFileCurrentOffsetKey
= @"NSStreamFileCurrentOffsetKey";

NSString * const NSStreamSocketSecurityLevelKey
= @"NSStreamSocketSecurityLevelKey";
NSString * const NSStreamSocketSecurityLevelNone
= @"NSStreamSocketSecurityLevelNone";
NSString * const NSStreamSocketSecurityLevelSSLv2
= @"NSStreamSocketSecurityLevelSSLv2";
NSString * const NSStreamSocketSecurityLevelSSLv3
= @"NSStreamSocketSecurityLevelSSLv3";
NSString * const NSStreamSocketSecurityLevelTLSv1
= @"NSStreamSocketSecurityLevelTLSv1";
NSString * const NSStreamSocketSecurityLevelNegotiatedSSL
= @"NSStreamSocketSecurityLevelNegotiatedSSL";
NSString * const NSStreamSocketSSLErrorDomain
= @"NSStreamSocketSSLErrorDomain";
NSString * const NSStreamSOCKSErrorDomain
= @"NSStreamSOCKSErrorDomain";
NSString * const NSStreamSOCKSProxyConfigurationKey
= @"NSStreamSOCKSProxyConfigurationKey";
NSString * const NSStreamSOCKSProxyHostKey
= @"NSStreamSOCKSProxyHostKey";
NSString * const NSStreamSOCKSProxyPasswordKey
= @"NSStreamSOCKSProxyPasswordKey";
NSString * const NSStreamSOCKSProxyPortKey
= @"NSStreamSOCKSProxyPortKey";
NSString * const NSStreamSOCKSProxyUserKey
= @"NSStreamSOCKSProxyUserKey";
NSString * const NSStreamSOCKSProxyVersion4
= @"NSStreamSOCKSProxyVersion4";
NSString * const NSStreamSOCKSProxyVersion5
= @"NSStreamSOCKSProxyVersion5";
NSString * const NSStreamSOCKSProxyVersionKey
= @"NSStreamSOCKSProxyVersionKey";


/*
 * Determine the type of event to use when adding a stream to the run loop.
 * By default add as an 'ET_TRIGGER' so that the stream will be notified
 * every time the loop runs (the event id/reference must be the address of
 * the stream itsself to ensure that event/type is unique).
 *
 * Streams which actually expect to wait for I/O events must be added with
 * the appropriate information for the loop to signal them.
 */

/*
 关于 runloop 的东西这里没有看, 不过他的基本思想在于, 将 自己注册给 runloop, 然后 runloop 就会在适当的时机, 进行回调, 调用自己实现的的 runloop 相关的接口, 在这个接口里面, 会进行 dispatch 函数, 这个函数里面, 会根据自身的状态, 进行事件的发送. 这个事件发送函数里面, 会调用最终的 stream handleEvent 方法. 所以, 流这种方式不会造成任务的阻塞, 是通过一点点的读取完成的流的写入和写出操作.
 */

static RunLoopEventType typeForStream(NSStream *aStream)
{
    NSStreamStatus        status = [aStream streamStatus];
    
    if (NSStreamStatusError == status
        || [aStream _loopID] == (void*)aStream)
    {
        return ET_TRIGGER;
    }
    if ([aStream isKindOfClass: [NSOutputStream class]] == NO
        && status != NSStreamStatusOpening)
    {
        return ET_RDESC;
    }
    return ET_WDESC;
}

@implementation	NSRunLoop (NSStream)
- (void) addStream: (NSStream*)aStream mode: (NSString*)mode
{
    [self addEvent: [aStream _loopID]
              type: typeForStream(aStream)
           watcher: (id<RunLoopEvents>)aStream
           forMode: mode];
}

- (void) removeStream: (NSStream*)aStream mode: (NSString*)mode
{
    /* We may have added the stream more than once (eg if the stream -open
     * method was called more than once, so we need to remove all event
     * registrations.
     */
    [self removeEvent: [aStream _loopID]
                 type: typeForStream(aStream)
              forMode: mode
                  all: YES];
}
@end

@implementation GSStream

+ (void) initialize
{
    GSMakeWeakPointer(self, "delegate");
}

- (void) close
{
    if (_currentStatus == NSStreamStatusNotOpen)
    {
        NSDebugMLLog(@"NSStream", @"Attempt to close unopened stream %@", self);
    }
    [self _unschedule];
    [self _setStatus: NSStreamStatusClosed];
    /* We don't want to send any events to the delegate after the
     * stream has been closed.
     */
    _delegateValid = NO;
}

- (void) finalize
{
    if (_currentStatus != NSStreamStatusNotOpen
        && _currentStatus != NSStreamStatusClosed)
    {
        [self close];
    }
    GSAssignZeroingWeakPointer((void**)&_delegate, (void*)0);
}

- (void) dealloc
{
    [self finalize];
    if (_loops != 0)
    {
        NSFreeMapTable(_loops);
        _loops = 0;
    }
    DESTROY(_properties);
    DESTROY(_lastError);
    [super dealloc];
}

- (id) delegate
{
    return _delegate;
}

- (id) init
{
    if ((self = [super init]) != nil)
    {
        _delegate = self;
        _properties = nil;
        _lastError = nil;
        _loops = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                  NSObjectMapValueCallBacks, 1);
        _currentStatus = NSStreamStatusNotOpen;
        _loopID = (void*)self;
    }
    return self;
}

- (void) open
{
    if (_currentStatus != NSStreamStatusNotOpen
        && _currentStatus != NSStreamStatusOpening)
    {
        NSDebugMLLog(@"NSStream", @"Attempt to re-open stream %@", self);
    }
    [self _setStatus: NSStreamStatusOpen];
    [self _schedule];
    [self _sendEvent: NSStreamEventOpenCompleted];
}

- (id) propertyForKey: (NSString *)key
{
    return [_properties objectForKey: key];
}

- (void) receivedEvent: (void*)data // runloop 的回调.
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    [self _dispatch]; // 每一次, runloop 告诉我们, 可以执行之后, 我们执行 dispatch 方法, 由各个子类, 进行 dispatch 的编写.
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
    if (aRunLoop != nil && mode != nil)
    {
        NSMutableArray	*modes;
        
        modes = (NSMutableArray*)NSMapGet(_loops, (void*)aRunLoop);
        if ([modes containsObject: mode])
        {
            [aRunLoop removeStream: self mode: mode];
            [modes removeObject: mode];
            if ([modes count] == 0)
            {
                NSMapRemove(_loops, (void*)aRunLoop);
            }
        }
    }
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
    if (aRunLoop != nil && mode != nil)
    {
        NSMutableArray	*modes;
        
        modes = (NSMutableArray*)NSMapGet(_loops, (void*)aRunLoop);
        if (modes == nil)
        {
            modes = [[NSMutableArray alloc] initWithCapacity: 1];
            NSMapInsert(_loops, (void*)aRunLoop, (void*)modes);
            RELEASE(modes);
        }
        if ([modes containsObject: mode] == NO)
        {
            mode = [mode copy];
            [modes addObject: mode];
            RELEASE(mode);
            /* We only add open streams to the runloop .. subclasses may add
             * streams when they are in the process of opening if they need
             * to do so.
             */
            if ([self _isOpened])
            {
                [aRunLoop addStream: self mode: mode]; // 就是把 stream 变成了 runloop 的一个 watcher.
            }
        }
    }
}

- (void) setDelegate: (id)delegate
{
    if ([self streamStatus] == NSStreamStatusClosed
        || [self streamStatus] == NSStreamStatusError)
    {
        _delegateValid = NO;
        GSAssignZeroingWeakPointer((void**)&_delegate, (void*)0);
    }
    else
    {
        if (delegate == nil)
        {
            _delegate = self;
        }
        if (delegate == self)
        {
            if (_delegate != nil && _delegate != self)
            {
                GSAssignZeroingWeakPointer((void**)&_delegate, (void*)0);
            }
            _delegate = delegate;
        }
        else
        {
            GSAssignZeroingWeakPointer((void**)&_delegate, (void*)delegate);
        }
        /* We don't want to send any events the the delegate after the
         * stream has been closed.
         */
        _delegateValid // 这里还专门有这么一个判断.
        = [_delegate respondsToSelector: @selector(stream:handleEvent:)];
    }
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
    if (_properties == nil)
    {
        _properties = [NSMutableDictionary new];
    }
    [_properties setObject: property forKey: key];
    return YES;
}

- (NSError *) streamError
{
    return _lastError;
}

- (NSStreamStatus) streamStatus
{
    return _currentStatus;
}

@end


@implementation	NSStream (Private)

- (void) _dispatch
{
}

- (BOOL) _isOpened
{
    return NO;
}

- (void*) _loopID
{
    return (void*)self;	// By default a stream is a TRIGGER event.
}

- (void) _recordError
{
}

- (void) _recordError: (NSError*)anError
{
    return;
}

- (void) _resetEvents: (NSUInteger)mask
{
    return;
}

- (void) _schedule
{
}

- (void) _sendEvent: (NSStreamEvent)event
{
}

- (void) _setLoopID: (void *)ref
{
}

- (void) _setStatus: (NSStreamStatus)newStatus
{
}

- (BOOL) _unhandledData
{
    return NO;
}

- (void) _unschedule
{
}

@end

@implementation	GSStream (Private)

- (BOOL) _isOpened
{
    return !(_currentStatus == NSStreamStatusNotOpen
             || _currentStatus == NSStreamStatusOpening
             || _currentStatus == NSStreamStatusClosed);
}

- (void*) _loopID
{
    return _loopID;
}

- (void) _recordError
{
    NSError *theError;
    
    theError = [NSError _last];
    [self _recordError: theError];
}

- (void) _recordError: (NSError*)anError
{
    NSDebugMLLog(@"NSStream", @"record error: %@ - %@", self, anError);
    ASSIGN(_lastError, anError);
    [self _setStatus: NSStreamStatusError];
}

- (void) _resetEvents: (NSUInteger)mask
{
    _events &= ~mask;
}

- (void) _schedule
{
    NSMapEnumerator	enumerator;
    NSRunLoop		*k;
    NSMutableArray	*v;
    
    enumerator = NSEnumerateMapTable(_loops);
    while (NSNextMapEnumeratorPair(&enumerator, (void **)(&k), (void**)&v))
    {
        unsigned	i = [v count];
        
        while (i-- > 0)
        {
            [k addStream: self mode: [v objectAtIndex: i]];
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

- (void) _sendEvent: (NSStreamEvent)event // 这个主要就是为了通知代理.
{
    if (event == NSStreamEventNone)
    {
        return;
    }
    else if (event == NSStreamEventOpenCompleted)
    {
        if ((_events & event) == 0) // 如果之前的没有完成.
        {
            _events |= NSStreamEventOpenCompleted;
            if (_delegateValid == YES) // 通知代理.
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted];
            }
        }
    }
    else if (event == NSStreamEventHasBytesAvailable)
    {
        if ((_events & NSStreamEventOpenCompleted) == 0)
        {
            _events |= NSStreamEventOpenCompleted; // 更新事件
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted]; // 通知代理.
            }
        }
        if ((_events & NSStreamEventHasBytesAvailable) == 0)
        {
            _events |= NSStreamEventHasBytesAvailable;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventHasBytesAvailable]; // 通知代理.
            }
        }
    }
    else if (event == NSStreamEventHasSpaceAvailable)
    {
        if ((_events & NSStreamEventOpenCompleted) == 0)
        {
            _events |= NSStreamEventOpenCompleted;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted];
            }
        }
        if ((_events & NSStreamEventHasSpaceAvailable) == 0)
        {
            _events |= NSStreamEventHasSpaceAvailable;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventHasSpaceAvailable];
            }
        }
    }
    else if (event == NSStreamEventErrorOccurred)
    {
        if ((_events & NSStreamEventErrorOccurred) == 0)
        {
            _events |= NSStreamEventErrorOccurred;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventErrorOccurred];
            }
        }
    }
    else if (event == NSStreamEventEndEncountered)
    {
        if ((_events & NSStreamEventEndEncountered) == 0)
        {
            _events |= NSStreamEventEndEncountered;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventEndEncountered];
            }
        }
    }
    else
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"Unknown event (%"PRIuPTR") passed to _sendEvent:",
         event];
    }
}

- (void) _setLoopID: (void *)ref
{
    _loopID = ref;
}

- (void) _setStatus: (NSStreamStatus)newStatus
{
    if (_currentStatus != newStatus)
    {
        if (NSStreamStatusError == newStatus && NSCountMapTable(_loops) > 0)
        {
            /* After an error, we are in the run loops only to trigger
             * errors, not for I/O, sop we must re-schedule in the right mode.
             */
            [self _unschedule];
            _currentStatus = newStatus;
            [self _schedule];
        }
        else
        {
            _currentStatus = newStatus;
        }
    }
}

- (BOOL) _unhandledData
{
    if (_events
        & (NSStreamEventHasBytesAvailable | NSStreamEventHasSpaceAvailable))
    {
        return YES;
    }
    return NO;
}

- (void) _unschedule
{
    NSMapEnumerator	enumerator;
    NSRunLoop		*k;
    NSMutableArray	*v;
    
    enumerator = NSEnumerateMapTable(_loops);
    while (NSNextMapEnumeratorPair(&enumerator, (void **)(&k), (void**)&v))
    {
        unsigned	i = [v count];
        
        while (i-- > 0)
        {
            [k removeStream: self mode: [v objectAtIndex: i]];
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
    if (_events
        & (NSStreamEventHasBytesAvailable | NSStreamEventHasSpaceAvailable))
    {
        /* If we have an unhandled data event, we should not watch for more
         * or trigger until the appropriate read or write has been done.
         */
        *trigger = NO;
        return NO;
    }
    if (_currentStatus == NSStreamStatusError)
    {
        if ((_events & NSStreamEventErrorOccurred) == 0)
        {
            /* An error has occurred but not been handled,
             * so we should trigger an error event at once.
             */
            *trigger = YES;
            return NO;
        }
        else
        {
            /* An error has occurred (and been handled),
             * so we should not watch for any events at all.
             */
            *trigger = NO;
            return NO;
        }
    }
    if (_currentStatus == NSStreamStatusAtEnd)
    {
        if ((_events & NSStreamEventEndEncountered) == 0)
        {
            /* An end of stream has occurred but not been handled,
             * so we should trigger an end of stream event at once.
             */
            *trigger = YES;
            return NO;
        }
        else
        {
            /* An end of stream has occurred (and been handled),
             * so we should not watch for any events at all.
             */
            *trigger = NO;
            return NO;
        }
    }
    
    if (_loopID == (void*)self)
    {
        /* If _loopID is the receiver, the stream is not receiving external
         * input, so it must trigger an event when the loop runs and must not
         * block the loop from running.
         */
        *trigger = YES;
        return NO;
    }
    else
    {
        *trigger = YES;
        return YES;
    }
}
@end

@implementation	GSInputStream

+ (void) initialize
{
    if (self == [GSInputStream class])
    {
        GSObjCAddClassBehavior(self, [GSStream class]); // 因为, 两者没有显示的层级关系. 但是完成的方法是完全一致的.
        GSMakeWeakPointer(self, "delegate");
    }
}

- (BOOL) hasBytesAvailable // A Boolean value that indicates whether the receiver has bytes available to read. Input stream 是读数据的 stream.
{
    if (_currentStatus == NSStreamStatusOpen) // The stream is open, but no reading or writing is occurring.
    {
        return YES;
    }
    if (_currentStatus == NSStreamStatusAtEnd)
    {
        if ((_events & NSStreamEventEndEncountered) == 0)
        {
            /* We have not sent the appropriate event yet, so the
             * client must not have issued a read:maxLength:
             * (which is the point at which we should send).
             */
            return YES;
        }
    }
    return NO;
}

@end

@implementation	GSOutputStream

+ (void) initialize
{
    if (self == [GSOutputStream class])
    {
        GSObjCAddClassBehavior(self, [GSStream class]);
        GSMakeWeakPointer(self, "delegate");
    }
}

- (BOOL) hasSpaceAvailable
{
    if (_currentStatus == NSStreamStatusOpen)
    {
        return YES;
    }
    return NO;
}

@end


@implementation GSDataInputStream // reading stream from a given NSData Object.

/**
 * the designated initializer
 */
- (id) initWithData: (NSData *)data
{
    if ((self = [super init]) != nil)
    {
        ASSIGN(_data, data); // 保存原来的值.
        _pointer = 0; // 记录偏移量
    }
    return self;
}

- (void) dealloc
{
    if (_currentStatus != NSStreamStatusNotOpen
        && _currentStatus != NSStreamStatusClosed)
    {
        [self close];
    }
    RELEASE(_data);
    [super dealloc];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
    NSUInteger dataSize;
    
    if ([self streamStatus] == NSStreamStatusClosed
        || [self streamStatus] == NSStreamStatusAtEnd) // 防卫式编程.
    {
        return 0;
    }
    
    /* Mark the data availability event as handled, so we can generate more.
     */
    _events &= ~NSStreamEventHasBytesAvailable; // ~ 是按位取反. 0xFFF11111101, _EVENT 在这样的操作之后, 就是 bytesUnAvailable.
    
    dataSize = [_data length];
    NSAssert(dataSize >= _pointer, @"Buffer overflow!");
    if (len + _pointer >= dataSize)
    {
        len = dataSize - _pointer;
        [self _setStatus: NSStreamStatusAtEnd]; // 如果, 读取到头了. 就设置为 end 了
    }
    if (len > 0)
    {
        memcpy(buffer, [_data bytes] + _pointer, len); // 进行 buffer 的读取操作, 更新存储的偏移量的值.
        _pointer = _pointer + len;
    }
    return len;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len // 返回, 数据流的地址, 以及还有多少数据可以读取.
{
    unsigned long dataSize = [_data length];
    
    NSAssert(dataSize >= _pointer, @"Buffer overflow!");
    *buffer = (uint8_t*)[_data bytes] + _pointer;
    *len = dataSize - _pointer;
    return YES;
}

- (BOOL) hasBytesAvailable
{
    unsigned long dataSize = [_data length];
    
    return (dataSize > _pointer); // 查看偏移量是否到了最后.
}

- (id) propertyForKey: (NSString *)key // KeyValue Coding 的实现.
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
        return [NSNumber numberWithLong: _pointer];
    return [super propertyForKey: key];
}

- (void) _dispatch // 在 DataInput 的dispatch 里面, 是发送 event 消息, sendEvent 主要是通知代理. 而在代理里面, 通过上面的 read 方法, 每次进行取值操作. 最终结果就是, 每个 runloop 执行一点点的 read 操作. 这其实和 设置 timer interval 为0 达到的效果是一样一样的.
{
    BOOL av = [self hasBytesAvailable];
    NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable :
    NSStreamEventEndEncountered;
    NSStreamStatus myStatus = av ? NSStreamStatusOpen : NSStreamStatusAtEnd;
    
    [self _setStatus: myStatus];
    [self _sendEvent: myEvent];
}

@end


@implementation GSBufferOutputStream

- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
    if ((self = [super init]) != nil)
    {
        _buffer = buffer;
        _capacity = capacity;
        _pointer = 0;
    }
    return self;
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
    // 在这个函数里面, 会记录 _pointer 的位置, 也就是写入缓存区的偏移量.
    if ([self streamStatus] == NSStreamStatusClosed
        || [self streamStatus] == NSStreamStatusAtEnd)
    {
        return 0;
    }
    
    /* We have consumed the 'writable' event ... mark that so another can
     * be generated.
     */
    _events &= ~NSStreamEventHasSpaceAvailable;
    if ((_pointer + len) > _capacity)
    {
        len = _capacity - _pointer;
        [self _setStatus: NSStreamStatusAtEnd];
    }
    
    if (len > 0)
    {
        memcpy((_buffer + _pointer), buffer, len);
        _pointer += len;
    }
    return len;
}

- (id) propertyForKey: (NSString *)key
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
        return [NSNumber numberWithLong: _pointer];
    }
    return [super propertyForKey: key];
}

- (void) _dispatch
{
    BOOL av = [self hasSpaceAvailable]; // 其实, 这个和 NSTimer 然后设置为 0 是一个意思, 就是每一次 runloop 都进行一次短小的操作.
    NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable :
    NSStreamEventEndEncountered;
    
    [self _sendEvent: myEvent];
}

@end

@implementation GSDataOutputStream

- (id) init
{
    if ((self = [super init]) != nil)
    {
        _data = [NSMutableData new];
        _pointer = 0;
    }
    return self;
}

- (void) dealloc
{
    RELEASE(_data);
    [super dealloc];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
    if (buffer == 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"null pointer for buffer"];
    }
    if (len == 0)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"zero byte length write requested"];
    }
    
    if ([self streamStatus] == NSStreamStatusClosed)
    {
        return 0;
    }
    
    /* We have consumed the 'writable' event ... mark that so another can
     * be generated.
     */
    _events &= ~NSStreamEventHasSpaceAvailable; // 这里, _event 在这里设置为 UnAvaiable, 在 _sendEvent 的方法内部, 会进行状态的恢复处理.
    [_data appendBytes: buffer length: len];
    _pointer += len;
    return len;
}

- (BOOL) hasSpaceAvailable
{
    return YES;
}

- (id) propertyForKey: (NSString *)key // [NSOutputStream outputStreamToMemory], 这样的方法有什么用的? 这里它的方法有问题, 就是需要通过 propertyForKey 这个方法, 去获取特定的 NSStreamDataWrittenToMemoryStreamKey 来获得写入的 data. 不过, keyValue Coding 的好处在于, 有了很多的灵活性
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
        return [NSNumber numberWithLong: _pointer];
    }
    else if ([key isEqualToString: NSStreamDataWrittenToMemoryStreamKey])
    {
        return _data;
    }
    return [super propertyForKey: key];
}

- (void) _dispatch // 对于 Data相关的 Stream 比较简单. 就是根据 hasSpaceAvailable 来进行event 的发送, 而 hasSpaceAvailable 这个方法里面, 仅仅是进行偏移量的计算而已.
{
    BOOL av = [self hasSpaceAvailable];
    NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable :
    NSStreamEventEndEncountered;
    [self _sendEvent: myEvent];
}

@end

