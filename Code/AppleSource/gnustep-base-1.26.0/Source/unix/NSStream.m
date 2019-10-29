#include "common.h"

#include <sys/stat.h>
#include <sys/types.h>
#import "Foundation/NSData.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSException.h"
#import "Foundation/NSError.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSURL.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

#import "../GSPrivate.h"
#import "../GSStream.h"
#import "../GSSocketStream.h"

/** 
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
    NSString *_path;
}
@end

@interface GSLocalInputStream : GSSocketInputStream
/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

/**
 * The concrete subclass of NSOutputStream that writes to a file
 */
@interface GSFileOutputStream : GSOutputStream
{
@private
    NSString *_path;
    BOOL _shouldAppend;
}
@end

@interface GSLocalOutputStream : GSSocketOutputStream
/**
 * the designated initializer
 */
- (id) initToAddr: (NSString*)addr;

@end

@interface GSLocalServerStream : GSSocketServerStream
@end

@implementation GSFileInputStream

- (id) initWithFileAtPath: (NSString *)path
{
    if ((self = [super init]) != nil)
    {
        ASSIGN(_path, path);
    }
    return self;
}

- (void) dealloc
{
    if ([self _isOpened])
    {
        [self close];
    }
    DESTROY(_path);
    [super dealloc];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
    int readLen;
    
    _events &= ~NSStreamEventHasBytesAvailable;
    
    if ([self streamStatus] == NSStreamStatusClosed)
    {
        return 0;
    }
    
    readLen = read((intptr_t)_loopID, buffer, len);
    if (readLen < 0 && errno != EAGAIN && errno != EINTR)
    {
        [self _recordError];
        readLen = -1;
    }
    else if (readLen == 0)
    {
        [self _setStatus: NSStreamStatusAtEnd];
    }
    return readLen;
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
    return NO;
}

- (BOOL) hasBytesAvailable
{
    if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
        return YES;
    return NO;
}

- (id) propertyForKey: (NSString *)key
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
        off_t offset = 0;
        
        if ([self _isOpened])
            offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
        return [NSNumber numberWithLong: offset];
    }
    return [super propertyForKey: key];
}

- (void) open
{
    int fd;
    
    fd = open([_path fileSystemRepresentation], O_RDONLY|O_NONBLOCK);
    if (fd < 0)
    {
        [self _recordError];
        return;
    }
    _loopID = (void*)(intptr_t)fd;
    [super open];
}

- (void) close
{
    int closeReturn = close((intptr_t)_loopID);
    
    if (closeReturn < 0)
        [self _recordError];
    [super close];
}

- (void) _dispatch
{
    if ([self streamStatus] == NSStreamStatusOpen)
    {
        [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
    else
    {
        NSLog(@"_dispatch with unexpected status %"PRIuPTR, [self streamStatus]);
    }
}
@end


@implementation GSLocalInputStream 

- (id) initToAddr: (NSString*)addr
{
    if ((self = [super init]) != nil)
    {
        if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
        {
            DESTROY(self);
        }
    }
    return self;
}

@end

@implementation GSFileOutputStream

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
    if ((self = [super init]) != nil)
    {
        ASSIGN(_path, path);
        // so that unopened access will fail
        _shouldAppend = shouldAppend;
    }
    return self;
}

- (void) dealloc
{
    if ([self _isOpened])
    {
        [self close];
    }
    RELEASE(_path);
    [super dealloc];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
    int writeLen;
    
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
    
    _events &= ~NSStreamEventHasSpaceAvailable;
    
    if ([self streamStatus] == NSStreamStatusClosed)
    {
        return 0;
    }
    
    writeLen = write((intptr_t)_loopID, buffer, len);
    if (writeLen < 0 && errno != EAGAIN && errno != EINTR)
        [self _recordError];
    return writeLen;
}

- (BOOL) hasSpaceAvailable
{
    if ([self _isOpened])
        return YES;
    return NO;
}

- (void) open
{
    int fd;
    fd = open([_path fileSystemRepresentation], flag, mode);
    if (fd < 0)
    {  // make an error
        [self _recordError];
        return;
    }
    _loopID = (void*)(intptr_t)fd;
    [super open];
}

- (void) close
{
    int closeReturn = close((intptr_t)_loopID);
    if (closeReturn < 0)
        [self _recordError];
    [super close];
}

- (id) propertyForKey: (NSString *)key
{
    if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
        off_t offset = 0;
        
        if ([self _isOpened])
            offset = lseek((intptr_t)_loopID, 0, SEEK_CUR);
        return [NSNumber numberWithLong: offset];
    }
    return [super propertyForKey: key];
}

- (void) _dispatch
{
    if ([self streamStatus] == NSStreamStatusOpen)
    {
        [self _sendEvent: NSStreamEventHasSpaceAvailable];
    }
}
@end


@implementation GSLocalOutputStream 

- (id) initToAddr: (NSString*)addr
{
    if ((self = [super init]) != nil)
    {
        if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
        {
            DESTROY(self);
        }
    }
    return self;
}

@end

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (NSInteger)port
              inputStream: (NSInputStream **)inputStream
             outputStream: (NSOutputStream **)outputStream
{
    NSString *address = host ? (id)[host address] : (id)@"127.0.0.1";
    id ins = nil;
    id outs = nil;
    
    // 直接生成具体的对象出来.
    ins = AUTORELEASE([[GSInetInputStream alloc]
                       initToAddr: address port: port]);
    outs = AUTORELEASE([[GSInetOutputStream alloc]
                        initToAddr: address port: port]);
    if (inputStream)
    {
        [ins _setSibling: outs];
        *inputStream = (NSInputStream*)ins;
    }
    if (outputStream)
    {
        [outs _setSibling: ins];
        *outputStream = (NSOutputStream*)outs;
    }
}

+ (void) getLocalStreamsToPath: (NSString *)path 
                   inputStream: (NSInputStream **)inputStream
                  outputStream: (NSOutputStream **)outputStream
{
    id ins = nil;
    id outs = nil;
    // 直接生成具体的对象出来.
    ins = AUTORELEASE([[GSLocalInputStream alloc] initToAddr: path]);
    outs = AUTORELEASE([[GSLocalOutputStream alloc] initToAddr: path]);
    if (inputStream)
    {
        [ins _setSibling: outs];
        *inputStream = (NSInputStream*)ins;
    }
    if (outputStream)
    {
        [outs _setSibling: ins];
        *outputStream = (NSOutputStream*)outs;
    }
    return;
}

@end

@implementation NSInputStream

// 生成具体的类的对象.
+ (id) inputStreamWithData: (NSData *)data
{
    return AUTORELEASE([[GSDataInputStream alloc] initWithData: data]);
}

// 生成具体的类的对象.
+ (id) inputStreamWithFileAtPath: (NSString *)path
{
    return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
}

// 生成具体的类的对象.
+ (id) inputStreamWithURL: (NSURL *)url
{
    if ([url isFileURL])
    {
        return [self inputStreamWithFileAtPath: [url path]];
    }
    return [self inputStreamWithData: [url resourceDataUsingCache: YES]];
}

// 生成具体的类的对象.
- (id) initWithData: (NSData *)data
{
    DESTROY(self);
    return [[GSDataInputStream alloc] initWithData: data];
}

// 生成具体的类的对象.
- (id) initWithFileAtPath: (NSString *)path
{
    DESTROY(self);
    return [[GSFileInputStream alloc] initWithFileAtPath: path];
}

// 生成具体的类的对象.
- (id) initWithURL: (NSURL *)url
{
    DESTROY(self);
    if ([url isFileURL])
    {
        return [[GSFileInputStream alloc] initWithFileAtPath: [url path]];
    }
    return [[GSDataInputStream alloc]
            initWithData: [url resourceDataUsingCache: YES]];
}

@end

@implementation NSOutputStream

// 生成具体的类的对象.
+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
    return AUTORELEASE([[GSBufferOutputStream alloc]
                        initToBuffer: buffer capacity: capacity]);
}

// 生成具体的类的对象.
+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
    return AUTORELEASE([[GSFileOutputStream alloc]
                        initToFileAtPath: path append: shouldAppend]);
}

// 生成具体的类的对象.
+ (id) outputStreamToMemory
{
    return AUTORELEASE([[GSDataOutputStream alloc] init]);
}

// 生成具体的类的对象.
- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
    DESTROY(self);
    return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

// 生成具体的类的对象.
- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
    DESTROY(self);
    return [[GSFileOutputStream alloc] initToFileAtPath: path
                                                 append: shouldAppend];
}

// 生成具体的类的对象.
- (id) initToMemory
{
    DESTROY(self);
    return [[GSDataOutputStream alloc] init];
}

@end

@implementation GSLocalServerStream 

- (Class) _inputStreamClass
{
    return [GSLocalInputStream class];
}

- (Class) _outputStreamClass
{
    return [GSLocalOutputStream class];
}

- (id) initToAddr: (NSString*)addr
{
    if ((self = [super init]) != nil)
    {
        if ([self _setSocketAddress: addr port: 0 family: AF_UNIX] == NO)
        {
            DESTROY(self);
        }
    }
    return self;
}

@end

