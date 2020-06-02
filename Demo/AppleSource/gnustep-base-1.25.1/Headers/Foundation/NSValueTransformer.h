#ifndef __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE
#define __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3,GS_API_LATEST) && GS_API_VERSION( 10200,GS_API_LATEST)

#import	<Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSArray;
@class NSString;

/** This transformer converts a YES to a NO and a NO to a YES.
 */
GS_EXPORT NSString* const NSNegateBooleanTransformerName;

/** This transformer converts a nil value to a YES.<br />
 * Not reversible.
 */
GS_EXPORT NSString* const NSIsNilTransformerName;

/** This transformer converts a non-nil value to a YES.<br />
 * Not reversible.
 */
GS_EXPORT NSString* const NSIsNotNilTransformerName; 

/** This transformer converts an [NSData] instance to the object
 * archived in it, or archives an object inot an [NSData].
 */
GS_EXPORT NSString* const NSUnarchiveFromDataTransformerName;

/** Instances of the NSValueTransformer class are used to convert
 * values from one representation to another.  The base class is
 * abstract and its methods must be overridden by subclasses to do
 * the actual work.
 */
@interface NSValueTransformer : NSObject

/** <override-subclass />
 * Returns a flag indicating whether the transformer permits reverse
 * transformations.
 */
+ (BOOL) allowsReverseTransformation;

/**
 * Registers transformer to handle transformations with the specified
 * name.
 */
+ (void) setValueTransformer: (NSValueTransformer *)transformer
		     forName: (NSString *)name;

/** <override-subclass />
 * Returns the class of the value produced by this transformer.
 */
+ (Class) transformedValueClass;

/**
 * Returns the transformer registered for the specified name, or nil
 * if no transformer is registered for name.
 *
 * If no transformer is found, but the name corresponds to a valid 
 * NSValueTransformer subclass name, the receiver instantiates this subclass 
 * using -init and registers it automatically for name.
 */
+ (NSValueTransformer *) valueTransformerForName: (NSString *)name;

/**
 * Returns an array listing the names of all registered value transformers.
 */
+ (NSArray *) valueTransformerNames;

/**
 * Performs a reverse transformation on the specified value and returns the
 * resulting object.<br />
 * The default implementation raises an exception if
 * +allowsReverseTransformation returns NO, otherwise it calls
 * -transformedValue: and returns the result.
 */
- (id) reverseTransformedValue: (id)value;

/** <override-subclass/>
 * Subclasses should override this method to perform the actual transformation
 * (and reverse transformation if applicable) and return the result.
 */
- (id) transformedValue: (id)value;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* OS_API_VERSION */

#endif /* __NSValueTransformer_h_GNUSTEP_BASE_INCLUDE */