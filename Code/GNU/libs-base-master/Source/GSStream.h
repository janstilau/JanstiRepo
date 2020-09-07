#ifndef	INCLUDED_GSSTREAM_H
#define	INCLUDED_GSSTREAM_H
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
    unsigned long _pointer;
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

