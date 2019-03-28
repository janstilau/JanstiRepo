
#include "common.h"

#include <sys/stat.h>
#include <sys/types.h>

#if	defined(HAVE_FCNTL_H)
#  include	<fcntl.h>
#elif defined(HAVE_SYS_FCNTL_H)
#  include	<sys/fcntl.h>
#endif

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

/*
 NSStream objects provide an easy way to read and write data to and from a variety of media in a device-independent way. You can create stream objects for data located in memory, in a file, or on a network (using sockets), and you can use stream objects without loading all of the data into memory at once. //
 
 顺序逐步的 loading, 除了文件 stream 可以进行 seekLocation, 其他的集中 stream 都只能顺序加载.
 
 */

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

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"zero byte read write requested"];
    }

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
  int flag = O_WRONLY | O_NONBLOCK | O_CREAT;
  mode_t mode = 0666;

  if (_shouldAppend)
    flag = flag | O_APPEND;
  else
    flag = flag | O_TRUNC;
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
  else
    {
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

// 这几个方法, 都是生成了对应的实际的子类对象做 stream.

+ (void) getStreamsToHost: (NSHost *)host 
                     port: (NSInteger)port 
              inputStream: (NSInputStream **)inputStream 
             outputStream: (NSOutputStream **)outputStream
{
  NSString *address = host ? (id)[host address] : (id)@"127.0.0.1";
  id ins = nil;
  id outs = nil;

  // try ipv4 first
  ins = AUTORELEASE([[GSInetInputStream alloc]
    initToAddr: address port: port]);
  outs = AUTORELEASE([[GSInetOutputStream alloc]
    initToAddr: address port: port]); // 在这个类里面, 就直接返回的就是子类的对象.
  if (!ins)
    {
#if	defined(PF_INET6)
      ins = AUTORELEASE([[GSInet6InputStream alloc]
	initToAddr: address port: port]);
      outs = AUTORELEASE([[GSInet6OutputStream alloc]
	initToAddr: address port: port]);
#endif
    }  

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

+ (void) pipeWithInputStream: (NSInputStream **)inputStream 
                outputStream: (NSOutputStream **)outputStream
{
  id ins = nil;
  id outs = nil;
  int fds[2];
  int pipeReturn;

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSLocalInputStream new]);
  outs = AUTORELEASE([GSLocalOutputStream new]);
  pipeReturn = pipe(fds);

  NSAssert(pipeReturn >= 0, @"Cannot open pipe");
  [ins _setLoopID: (void*)(intptr_t)fds[0]];
  [outs _setLoopID: (void*)(intptr_t)fds[1]];
  // no need to connect
  [ins _setPassive: YES];
  [outs _setPassive: YES];
  if (inputStream)
    *inputStream = (NSInputStream*)ins;
  if (outputStream)
    *outputStream = (NSOutputStream*)outs;
  return;
}

- (void) close
{
  [self subclassResponsibility: _cmd];
}

- (void) open
{
  [self subclassResponsibility: _cmd];
}

- (void) setDelegate: (id)delegate
{
  [self subclassResponsibility: _cmd];
}

- (id) delegate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) propertyForKey: (NSString *)key 
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  [self subclassResponsibility: _cmd];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;
{
  [self subclassResponsibility: _cmd];
}

- (NSError *) streamError
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSStreamStatus) streamStatus
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

@implementation NSInputStream

// 直接用的 DATAINPUTStream.
+ (id) inputStreamWithData: (NSData *)data
{
  return AUTORELEASE([[GSDataInputStream alloc] initWithData: data]);
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
}

+ (id) inputStreamWithURL: (NSURL *)url
{
  if ([url isFileURL]) // 如果是文件, 就是本地的.
    {
      return [self inputStreamWithFileAtPath: [url path]];
    }
  return [self inputStreamWithData: [url resourceDataUsingCache: YES]];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) hasBytesAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initWithData: (NSData *)data
{
  DESTROY(self);
  return [[GSDataInputStream alloc] initWithData: data];
}

- (id) initWithFileAtPath: (NSString *)path
{
  DESTROY(self);
  return [[GSFileInputStream alloc] initWithFileAtPath: path];
}

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

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end

@implementation NSOutputStream

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  return AUTORELEASE([[GSBufferOutputStream alloc] 
    initToBuffer: buffer capacity: capacity]);  
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  return AUTORELEASE([[GSFileOutputStream alloc]
    initToFileAtPath: path append: shouldAppend]);
}

+ (id) outputStreamToMemory
{
  return AUTORELEASE([[GSDataOutputStream alloc] init]);  
}

- (BOOL) hasSpaceAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  DESTROY(self);
  return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  DESTROY(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
					       append: shouldAppend];  
}

- (id) initToMemory
{
  DESTROY(self);
  return [[GSDataOutputStream alloc] init];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;  
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

