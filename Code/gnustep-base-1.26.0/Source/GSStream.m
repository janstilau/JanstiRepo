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
static RunLoopEventType typeForStream(NSStream *aStream)
{
    NSStreamStatus        status = [aStream streamStatus];
    
    if (NSStreamStatusError == status
        || [aStream _loopID] == (void*)aStream)
    {
        return ET_TRIGGER;
    }
#if	defined(_WIN32)
    return ET_HANDLE;
#else
    if ([aStream isKindOfClass: [NSOutputStream class]] == NO
        && status != NSStreamStatusOpening)
    {
        return ET_RDESC;
    }
    return ET_WDESC;
#endif
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

- (void) close
{
    [self _unschedule]; // remove from runloop.
    [self _setStatus: NSStreamStatusClosed];
    /* We don't want to send any events to the delegate after the
     * stream has been closed.
     */
    _delegateValid = NO;
}

- (void) dealloc
{
    if (_currentStatus != NSStreamStatusNotOpen
        && _currentStatus != NSStreamStatusClosed)
    {
        [self close];
    }
    GSAssignZeroingWeakPointer((void**)&_delegate, (void*)0);
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
    [self _schedule]; // add self to runloop.
    [self _sendEvent: NSStreamEventOpenCompleted];
}

- (id) propertyForKey: (NSString *)key
{
    return [_properties objectForKey: key]; // Key - value container.
}


// @protocol RunLoopEvents
- (void) receivedEvent: (void*)data
                  type: (RunLoopEventType)type
                 extra: (void*)extra
               forMode: (NSString*)mode
{
    [self _dispatch];
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
                [aRunLoop addStream: self mode: mode];
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
        _delegateValid
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
    _signalledEvents &= ~mask;
}

- (void) _schedule
{
    NSMapEnumerator	enumerator;
    NSRunLoop		*ronloop;
    NSMutableArray	*modes;
    
    enumerator = NSEnumerateMapTable(_loops);
    while (NSNextMapEnumeratorPair(&enumerator, (void **)(&ronloop), (void**)&modes))
    {
        unsigned	i = [modes count];
        
        while (i-- > 0)
        {
            [ronloop addStream: self mode: [modes objectAtIndex: i]];
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

/**
 * called in runloop handler dispatch. Translate runloop event to stream event.
 * This is a funnel to stream delegate.
 */
- (void) _sendEvent: (NSStreamEvent)event
{
    if (event == NSStreamEventNone)
    {
        return;
    }
    else if (event == NSStreamEventOpenCompleted)
    {
        if ((_signalledEvents & event) == 0)
        {
            _signalledEvents |= NSStreamEventOpenCompleted;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted];
            }
        }
    }
    else if (event == NSStreamEventHasBytesAvailable)
    { // Here, set previous phase bit also.
        if ((_signalledEvents & NSStreamEventOpenCompleted) == 0)
        {
            _signalledEvents |= NSStreamEventOpenCompleted;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted];
            }
        }
        if ((_signalledEvents & NSStreamEventHasBytesAvailable) == 0)
        {
            _signalledEvents |= NSStreamEventHasBytesAvailable;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventHasBytesAvailable];
            }
        }
    }
    else if (event == NSStreamEventHasSpaceAvailable)
    {
        if ((_signalledEvents & NSStreamEventOpenCompleted) == 0)
        {
            _signalledEvents |= NSStreamEventOpenCompleted;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventOpenCompleted];
            }
        }
        if ((_signalledEvents & NSStreamEventHasSpaceAvailable) == 0)
        {
            _signalledEvents |= NSStreamEventHasSpaceAvailable;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventHasSpaceAvailable];
            }
        }
    }
    else if (event == NSStreamEventErrorOccurred)
    {
        if ((_signalledEvents & NSStreamEventErrorOccurred) == 0)
        {
            _signalledEvents |= NSStreamEventErrorOccurred;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventErrorOccurred];
            }
        }
    }
    else if (event == NSStreamEventEndEncountered)
    {
        if ((_signalledEvents & NSStreamEventEndEncountered) == 0)
        {
            _signalledEvents |= NSStreamEventEndEncountered;
            if (_delegateValid == YES)
            {
                [_delegate stream: self
                      handleEvent: NSStreamEventEndEncountered];
            }
        }
    }
    else
    {
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
    if (_signalledEvents
        & (NSStreamEventHasBytesAvailable | NSStreamEventHasSpaceAvailable))
    {
        return YES;
    }
    return NO;
}

- (void) _unschedule
{
    NSMapEnumerator	enumerator;
    NSRunLoop		*runloop;
    NSMutableArray	*modes;
    
    enumerator = NSEnumerateMapTable(_loops);
    while (NSNextMapEnumeratorPair(&enumerator, (void **)(&runloop), (void**)&modes))
    {
        unsigned	i = [modes count];
        
        while (i-- > 0)
        {
            [runloop removeStream: self mode: [modes objectAtIndex: i]];
        }
    }
    NSEndMapTableEnumeration(&enumerator);
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
    if (_signalledEvents
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
        if ((_signalledEvents & NSStreamEventErrorOccurred) == 0)
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
        if ((_signalledEvents & NSStreamEventEndEncountered) == 0)
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

/**
 * GSStream is not a superclass, Just a behaior method container.
 */

@implementation	GSInputStream

+ (void) initialize
{
    if (self == [GSInputStream class])
    {
        GSObjCAddClassBehavior(self, [GSStream class]);
    }
}

- (BOOL) hasBytesAvailable
{
    if (_currentStatus == NSStreamStatusOpen)
    {
        return YES;
    }
    if (_currentStatus == NSStreamStatusAtEnd)
    {
        if ((_signalledEvents & NSStreamEventEndEncountered) == 0)
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

/**
 * InputStream means you have a chunk of data. You need to read data step-by-step
 Data input is the simple one, data is already in memory. The read is just memory cpy and pinter move.
 */
@implementation GSDataInputStream

/**
 * the designated initializer
 */
- (id) initWithData: (NSData *)data
{
    if ((self = [super init]) != nil)
    {
        ASSIGN(_data, data);
        _offsetPointer = 0;
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

// buffer, the data container.
- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
    NSUInteger dataSize;
    if ([self streamStatus] == NSStreamStatusClosed
        || [self streamStatus] == NSStreamStatusAtEnd)
    {
        return 0;
    }
    
    /* Mark the data availability event as handled, so we can generate more.
     */
    _signalledEvents &= ~NSStreamEventHasBytesAvailable;
    
    dataSize = [_data length];
    // mark end if overflow.
    if (len + _offsetPointer >= dataSize)
    {
        len = dataSize - _offsetPointer;
        [self _setStatus: NSStreamStatusAtEnd];
    }
    if (len > 0)
    {
        memcpy(buffer, [_data bytes] + _offsetPointer, len);
        _offsetPointer = _offsetPointer + len;
    }
    return len;
}

// get the reamin datas.
// there is no copy here.
- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
    unsigned long dataSize = [_data length];
    *buffer = (uint8_t*)[_data bytes] + _offsetPointer;
    *len = dataSize - _offsetPointer;
    return YES;
}

- (BOOL) hasBytesAvailable
{
    unsigned long dataSize = [_data length];
    
    return (dataSize > _offsetPointer);
}

- (id) propertyForKey: (NSString *)key
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
        return [NSNumber numberWithLong: _offsetPointer];
    return [super propertyForKey: key];
}

/**
 * Each time runloop run, _dispatch handle.
   dispatch make some check, and sendEvent is called, which will call stream delegate method.
   in delegate method, data copy operation is runed, and make stream internal data changed. Each time just a tiny data is coied in one runloop, so there is no hold in thread.
   An then, a new runloop, stream will check its own status, and call stream delegate.
   This is how stream is working with runloop.
 */
- (void) _dispatch
{
    BOOL av = [self hasBytesAvailable];
    NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable : NSStreamEventEndEncountered;
    NSStreamStatus myStatus = av ? NSStreamStatusOpen : NSStreamStatusAtEnd;
    
    [self _setStatus: myStatus];
    [self _sendEvent: myEvent];
}

@end


/**
 * Has a buffer inside. Write data to buffer every time. If buffer is full, Stream status is set to enterEnd.
 */

@implementation GSBufferOutputStream

- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
    if ((self = [super init]) != nil)
    {
        _buffer = buffer;
        _capacity = capacity;
        _writeOffsetPointer = 0;
    }
    return self;
}

- (NSInteger) write: (const uint8_t *)dataSource maxLength: (NSUInteger)len
{
    if ([self streamStatus] == NSStreamStatusClosed
        || [self streamStatus] == NSStreamStatusAtEnd)
    {
        return 0;
    }
    
    /* We have consumed the 'writable' event ... mark that so another can
     * be generated.
     */
    _signalledEvents &= ~NSStreamEventHasSpaceAvailable;
    if ((_writeOffsetPointer + len) > _capacity)
    {
        // overflow
        len = _capacity - _writeOffsetPointer;
        [self _setStatus: NSStreamStatusAtEnd];
    }
    
    if (len > 0)
    {
        // copy data from dataSource to _buffer.
        memcpy((_buffer + _writeOffsetPointer), dataSource, len);
        _writeOffsetPointer += len;
    }
    return len;
}

- (id) propertyForKey: (NSString *)key
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
        return [NSNumber numberWithLong: _writeOffsetPointer];
    }
    return [super propertyForKey: key];
}

- (void) _dispatch
{
    BOOL av = [self hasSpaceAvailable];
    NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable : NSStreamEventEndEncountered;
    [self _sendEvent: myEvent];
}

@end

/**
 * A unlimited size buffer in inside.
   To get the buffer, using the propertyForKey with NSStreamDataWrittenToMemoryStreamKey.
 */

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
    if ([self streamStatus] == NSStreamStatusClosed)
    {
        return 0;
    }
    _signalledEvents &= ~NSStreamEventHasSpaceAvailable;
    [_data appendBytes: buffer length: len];
    _pointer += len;
    return len;
}

- (BOOL) hasSpaceAvailable
{
    return YES;
}

- (id) propertyForKey: (NSString *)key
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

- (void) _dispatch
{
    BOOL av = [self hasSpaceAvailable];
    NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable :
    NSStreamEventEndEncountered;
    
    [self _sendEvent: myEvent];
}

@end

@interface	GSLocalServerStream : GSServerStream
@end

@implementation GSServerStream


/**
 * Port is for internet. Just address is local.
 */
+ (void) initialize
{
    // self is the class variable.
    GSMakeWeakPointer(self, "delegate");
}

+ (id) serverStreamToAddr: (NSString*)addr port: (NSInteger)port
{
    GSServerStream *s;
    
    // try inet first, then inet6
    s = [[GSInetServerStream alloc] initToAddr: addr port: port];
    if (!s)
        s = [[GSInet6ServerStream alloc] initToAddr: addr port: port];
    return AUTORELEASE(s);
}

+ (id) serverStreamToAddr: (NSString*)addr
{
    return AUTORELEASE([[GSLocalServerStream alloc] initToAddr: addr]);
}

- (id) initToAddr: (NSString*)addr port: (NSInteger)port
{
    DESTROY(self);
    // try inet first, then inet6
    self = [[GSInetServerStream alloc] initToAddr: addr port: port];
    if (!self)
        self = [[GSInet6ServerStream alloc] initToAddr: addr port: port];
    return self;
}

- (id) initToAddr: (NSString*)addr
{
    DESTROY(self);
    return [[GSLocalServerStream alloc] initToAddr: addr];
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream 
                  outputStream: (NSOutputStream **)outputStream
{
    [self subclassResponsibility: _cmd];
}

@end

@implementation GSAbstractServerStream

+ (void) initialize
{
    if (self == [GSAbstractServerStream class])
    {
        GSObjCAddClassBehavior(self, [GSStream class]);
    }
}

@end

