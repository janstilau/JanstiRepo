#ifndef	INCLUDED_GSSTREAM_H
#define	INCLUDED_GSSTREAM_H

/*
   NSInputStream and NSOutputStream are clusters rather than concrete classes
   The inherance graph is:
   NSStream 
   |-- GSStream
   |   `--GSSocketStream
   |-- NSInputStream
        // 提供了对外输入的抽象, 数据在 InputStream 里面, 通过 read:maxLength 输出到 buffer 中去
        // 提供工厂方法, 针对不同的参数, 返回不同的子类对象.
        1. read:maxLength: 最主要的方法, 将数据拷贝到 read 的参数 buffer 里面去
        2. getBuffer:length: 返回 input 中管理的原始数据, 返回值为 NO 就是得不到原始数据, 比如 FileInput
        3. hasBytesAvailable 返回是否还有数据未读
   |   `--GSInputStream
   |      |-- GSDataInputStream // 内存提前准备好 Data, 然后 InpuStream 管理偏移量.
   |      |-- GSFileInputStream // InputStream 管理文件的读取, 然后输出到 Buffer 中去
   |      |-- GSPipeInputStream (mswindows only)
   |      `-- GSSocketInputStream //
   |          |-- GSInetInputStream
   |          |-- GSLocalInputStream
   |          `-- GSInet6InputStream
   |-- NSOutputStream
   |   `--GSOutputStream
   |      |-- GSBufferOutputStream
   |      |-- GSDataOutputStream
   |      |-- GSFileOutputStream
   |      |-- GSPipeOutputStream (mswindows only)
   |      `-- GSSocketOutputStream
   |          |-- GSInetOutputStream
   |          |-- GSLocalOutputStream
   |          `-- GSInet6InputStream
   `-- GSServerStream
       `-- GSAbstractServerStream
           |-- GSLocalServerStream (mswindows)
           `-- GSSocketServerStream
               |-- GSInetServerStream
               |-- GSInet6ServerStream
               `-- GSLocalServerStream (gnu/linux)
*/

#import "Foundation/NSStream.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSMapTable.h"
#import "GNUstepBase/NSStream+GNUstepBase.h"

/**
 * Convenience methods used to add streams to the run loop.
 */
@interface	NSRunLoop (NSStream)
- (void) addStream: (NSStream*)aStream mode: (NSString*)mode;
- (void) removeStream: (NSStream*)aStream mode: (NSString*)mode;
@end

@class	NSMutableData;

#define	IVARS \
{ \
  id		         _delegate;	/* Delegate controls operation.	*/\
  NSMutableDictionary	*_properties;	/* storage for properties	*/\
  BOOL                  _delegateValid; /* whether the delegate responds*/\
  NSError               *_lastError;    /* last error occured           */\
  NSStreamStatus         _currentStatus;/* current status               */\
  NSMapTable		*_loops;	/* Run loops and their modes.	*/\
  void                  *_loopID;	/* file descriptor etc.		*/\
  int			_events;	/* Signalled events.		*/\
}

/**
 * GSInputStream and GSOutputStream both inherit methods from the
 * GSStream class using 'behaviors', and must therefore share
 * EXACTLY THE SAME initial ivar layout.
 */
@interface GSStream : NSStream
IVARS
/** Return description of current event mask.
 */
- (NSString*) _stringFromEvents;
@end

@interface GSAbstractServerStream : GSServerStream
IVARS
@end

@interface NSStream(Private)

/**
 * Async notification
 */
- (void) _dispatch;

/**
 * Return YES if the stream is opened, NO otherwise.
 */
- (BOOL) _isOpened;

/**
 * Return previously set reference for IO in run loop.
 */
- (void*) _loopID;

/** Reset events in mask to allow them to be sent again.
 */
- (void) _resetEvents: (NSUInteger)mask;

/**
 * Place the stream in all the scheduled runloops.
 */
- (void) _schedule;

/**
 * send an event to delegate
 */
- (void) _sendEvent: (NSStreamEvent)event;

/**
 * send an event to delegate
 */
- (void) _sendEvent: (NSStreamEvent)event delegate: (id)delegate;

/**
 * setter for IO event reference (file descriptor, file handle etc )
 */
- (void) _setLoopID: (void *)ref;

/**
 * set the status to newStatus. an exception is error cannot
 * be overwriten by closed
 */
- (void) _setStatus: (NSStreamStatus)newStatus;

/**
 * record an error based on errno
 */
- (void) _recordError; 
- (void) _recordError: (NSError*)anError; 

/**
 * say whether there is unhandled data for the stream.
 */
- (BOOL) _unhandledData;

/**
 * Remove the stream from all the scheduled runloops.
 */
- (void) _unschedule;

/** Return name of event
 */
- (NSString*) stringFromEvent: (NSStreamEvent)e;

/** Return name of status
 */
- (NSString*) stringFromStatus: (NSStreamStatus)s;

@end

@interface GSInputStream : NSInputStream
IVARS
@end

@interface GSOutputStream : NSOutputStream
IVARS
@end

/**
 * The concrete subclass of NSInputStream that reads from the memory 
 */
@interface GSDataInputStream : GSInputStream
{
@private
  NSData *_data;
  unsigned long _pointer;
}
@end

/**
 * The concrete subclass of NSOutputStream that writes to a buffer
 */
@interface GSBufferOutputStream : GSOutputStream
{
@private
  uint8_t	*_buffer;
  unsigned	_capacity;
  unsigned long _pointer; // 这个应该叫做 offset.
}
@end

/**
 * The concrete subclass of NSOutputStream that writes to a variable sise buffer
 */
@interface GSDataOutputStream : GSOutputStream
{
@private
  NSMutableData *_data;
  unsigned long _pointer;
}
@end

#endif

