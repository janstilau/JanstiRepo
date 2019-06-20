#ifndef __NSKeyValueObserving_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyValueObserving_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3,GS_API_LATEST) && GS_API_VERSION( 10200,GS_API_LATEST)

#import	<Foundation/NSObject.h>
#import	<Foundation/NSArray.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSIndexSet;
@class NSSet;
@class NSString;

enum {
  NSKeyValueObservingOptionNew = 1,
  NSKeyValueObservingOptionOld = 2
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST) // 下面的两个, 从这个宏的意思看, 是仅仅用在了 macOS 里面.
,  NSKeyValueObservingOptionInitial = 4,
  NSKeyValueObservingOptionPrior = 8
#endif
};
typedef NSUInteger NSKeyValueObservingOptions;

enum {
  NSKeyValueChangeSetting = 1, //  Indicates that the value of the observed key path was set to a new value. This change can occur when observing an attribute of an object, as well as properties that specify to-one and to-many relationships.
  NSKeyValueChangeInsertion = 2, // Indicates that an object has been inserted into the to-many relationship that is being observed.
  NSKeyValueChangeRemoval = 3, // Indicates that an object has been removed from the to-many relationship that is being observed.
  NSKeyValueChangeReplacement = 4 // Indicates that an object has been replaced in the to-many relationship that is being observed.
};
typedef NSUInteger NSKeyValueChange; // The kinds of changes that can be observed.

enum {
  NSKeyValueUnionSetMutation = 1,
  NSKeyValueMinusSetMutation = 2,
  NSKeyValueIntersectSetMutation = 3,
  NSKeyValueSetSetMutation = 4
};
typedef NSUInteger NSKeyValueSetMutationKind;

GS_EXPORT NSString *const NSKeyValueChangeIndexesKey;
GS_EXPORT NSString *const NSKeyValueChangeKindKey;
GS_EXPORT NSString *const NSKeyValueChangeNewKey;
GS_EXPORT NSString *const NSKeyValueChangeOldKey;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
GS_EXPORT NSString *const NSKeyValueChangeNotificationIsPriorKey;
#endif

/* Given 考虑到 that the receiver has been registered as an observer
 * of the value at a key path relative to an object,
 * be notified that the value has changed.
 
 NSKeyValueChangeKindKey 是固定会有的, 但是含义其实不一定.
 * The change dictionary always contains an NSKeyValueChangeKindKey entry
 * whose value is an NSNumber wrapping an NSKeyValueChange
 * (use [NSNumber-intValue]). The meaning of NSKeyValueChange
 * depends on what sort of property is identified by the key path:
 
 * For any sort of property (attribute, 这里, attribute 应该指的是基本数据类型而不是指针了 to-one relationship,
 * or ordered or unordered to-many relationship) NSKeyValueChangeSetting
 * indicates that the observed object has received a -setValue:forKey:
 * message, or that the key-value coding-compliant set method for the
 * key has been invoked, or that a -willChangeValueForKey: or
 * -didChangeValueForKey: pair has otherwise been invoked.
 NSKeyValueChangeSetting 指的是 setvalueforkey 了, 或者 willChangeValueForKey, didChangeValueForKey 被显示调用了
 *
 
 // 下面这两项有点不理解.
 * For an _ordered_ to-many relationship, NSKeyValueChangeInsertion,
 * NSKeyValueChangeRemoval, and NSKeyValueChangeReplacement indicate
 * that a mutating message has been sent to the array returned by
 * a -mutableArrayValueForKey: message sent to the object, or that
 * one of the key-value coding-compliant array mutation methods for
 * the key has been invoked, or that a -willChange:valuesAtIndexes:forKey:
 * or -didChange:valuesAtIndexes:forKey: pair has otherwise been invoked.
 *
 * For an _unordered_ to-many relationship (introduced in Mac OS 10.4),
 * NSKeyValueChangeInsertion, NSKeyValueChangeRemoval,
 * and NSKeyValueChangeReplacement indicate that a mutating
 * message has been sent to the set returned by a -mutableSetValueForKey:
 * message sent to the object, or that one of the key-value
 * coding-compliant set mutation methods for the key has been invoked,
 * or that a -willChangeValueForKey:withSetMutation:usingObjects:
 * or -didChangeValueForKey:withSetMutation:usingObjects: pair has
 * otherwise been invoked.
 *
 * For any sort of property, the change dictionary always contains
 * an NSKeyValueChangeNewKey entry if NSKeyValueObservingOptionNew
 * was specified at observer-registration time, likewise for
 * NSKeyValueChangeOldKey if NSKeyValueObservingOptionOld was specified.
 
 * See the comments for the NSKeyValueObserverNotification informal
 * protocol methods for what the values of those entries will be.
 * For an _ordered_ to-many relationship, the change dictionary
 * always contains an NSKeyValueChangeIndexesKey entry whose value
 * is an NSIndexSet containing the indexes of the inserted, removed,
 * or replaced objects, unless the change is an NSKeyValueChangeSetting.
 * context is always the same pointer that was passed in at
 * observer-registration time.
 */

@interface NSObject (NSKeyValueObserving)
- (void) observeValueForKeyPath: (NSString*)aPath
		       ofObject: (id)anObject
			 change: (NSDictionary*)aChange
		        context: (void*)aContext;

@end

@interface NSObject (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext;

- (void) removeObserver: (NSObject*)anObserver
	     forKeyPath: (NSString*)aPath;

@end

@interface NSArray (NSKeyValueObserverRegistration)

- (void) addObserver: (NSObject*)anObserver
  toObjectsAtIndexes: (NSIndexSet*)indexes
	  forKeyPath: (NSString*)aPath
	     options: (NSKeyValueObservingOptions)options
	     context: (void*)aContext;

- (void) removeObserver: (NSObject*)anObserver
   fromObjectsAtIndexes: (NSIndexSet*)indexes
	     forKeyPath: (NSString*)aPath;

@end

/**
 * These methods are sent to the receiver when observing it active
 * for a key and the key is about to be (or has just been) changed.
 */
@interface NSObject (NSKeyValueObserverNotification)

/** <override-dummy />
 */
- (void) didChangeValueForKey: (NSString*)aKey;

/** <override-dummy />
 */
- (void) didChange: (NSKeyValueChange)changeKind
   valuesAtIndexes: (NSIndexSet*)indexes
	    forKey: (NSString*)aKey;

/** <override-dummy />
 */
- (void) willChangeValueForKey: (NSString*)aKey;

/** <override-dummy />
 */
- (void) willChange: (NSKeyValueChange)changeKind
    valuesAtIndexes: (NSIndexSet*)indexes
	     forKey: (NSString*)aKey;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4,GS_API_LATEST)

/** <override-dummy />
 */
- (void) didChangeValueForKey: (NSString*)aKey
	      withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		 usingObjects: (NSSet*)objects;

/** <override-dummy />
 */
- (void) willChangeValueForKey: (NSString*)aKey
	       withSetMutation: (NSKeyValueSetMutationKind)mutationKind
		  usingObjects: (NSSet*)objects;

#endif

@end

/**
 * These methods permit modifications to the observing system.
 */
@interface NSObject(NSKeyValueObservingCustomization)
/**
 * Specifies whether the class should send the notification methods of
 * the NSKeyValueObserverNotification protocol when instances of the
 * class receive messages to change the value for the key.<br />
 * The default implementation returns YES.
 */
+ (BOOL) automaticallyNotifiesObserversForKey: (NSString*)aKey;

/**
 * Tells the observing system that when NSKeyValueObserverNotification
 * protocol messages are sent for any key in the triggerKeys array,
 * they should also be sent for dependentKey.
 */
+ (void) setKeys: (NSArray*)triggerKeys
triggerChangeNotificationsForDependentKey: (NSString*)dependentKey;


#if OS_API_VERSION(MAC_OS_X_VERSION_10_5,GS_API_LATEST)
/**
 * Returns a set of key paths for properties whose values affect the value
 * of the specified dependentKey.
 */
+ (NSSet*) keyPathsForValuesAffectingValueForKey: (NSString*)dependentKey;
#endif

/**
 * Returns a reference to the observation information for the receiver
 * as stored using the -setObservationInfo: method.<br />
 * The default implementation returns information from a global table.
 */
- (void*) observationInfo;

/**
 * Stores observation information for the receiver.  By default this is
 * done in a global table, but classes may implement storage in an instance
 * variable or some other scheme (for improved performance).
 */
- (void) setObservationInfo: (void*)observationInfo;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* 100300 */

#endif	/* __NSKeyValueObserving_h_GNUSTEP_BASE_INCLUDE */

