#ifndef __NSDistantObject_h_GNUSTEP_BASE_INCLUDE
#define __NSDistantObject_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#import	<Foundation/NSProxy.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSConnection;

@interface NSDistantObject : NSProxy <NSCoding>
{
#if	GS_EXPOSE(NSDistantObject)
@public
  NSConnection	*_connection;
  id		_object;
  unsigned	_handle;
  Protocol	*_protocol;
  unsigned	_counter;
  void		*_sigs;
#endif
}

+ (NSDistantObject*) proxyWithLocal: (id)anObject
			 connection: (NSConnection*)aConnection;
/*
 *	NB. Departure from the OpenStep/MacOS spec - the type of a target
 *	is an integer, not an id, since we can't safely pass id's
 *	between address spaces on machines with different pointer sizes.
 */
+ (NSDistantObject*) proxyWithTarget: (unsigned)anObject
			  connection: (NSConnection*)aConnection;

- (NSConnection*) connectionForProxy;
- (id) initWithLocal: (id)anObject
	  connection: (NSConnection*)aConnection;
- (id) initWithTarget: (unsigned)target
	   connection: (NSConnection*)aConnection;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;
- (void) setProtocolForProxy: (Protocol*)aProtocol;

@end

#if	defined(__cplusplus)
}
#endif

#endif /* __NSDistantObject_h_GNUSTEP_BASE_INCLUDE */
