#import "Foundation/NSObject.h"

@class NSData;
@class NSError;
@class NSInputStream;
@class NSOutputStream;

enum
{
  NSJSONReadingMutableContainers = (1UL << 0),
  NSJSONReadingMutableLeaves     = (1UL << 1),
  NSJSONReadingAllowFragments    = (1UL << 2)
};
enum
{
  NSJSONWritingPrettyPrinted = (1UL << 0)
};
/**
 * A bitmask containing flags from the NSJSONWriting* set, specifying options
 * to use when writing JSON.
 */
typedef NSUInteger NSJSONWritingOptions;
/**
 * A bitmask containing flags from the NSJSONReading* set, specifying options
 * to use when reading JSON.
 */
typedef NSUInteger NSJSONReadingOptions;


/**
 * NSJSONSerialization implements serializing and deserializing acyclic object
 * graphs in JSON.
 */
@interface NSJSONSerialization : NSObject
 + (NSData *)dataWithJSONObject:(id)obj
                        options:(NSJSONWritingOptions)opt
                          error:(NSError **)error;
+ (BOOL)isValidJSONObject:(id)obj;
+ (id)JSONObjectWithData:(NSData *)data
                 options:(NSJSONReadingOptions)opt
                   error:(NSError **)error;
+ (id)JSONObjectWithStream:(NSInputStream *)stream
                   options:(NSJSONReadingOptions)opt
                     error:(NSError **)error;
+ (NSInteger)writeJSONObject:(id)obj
                    toStream:(NSOutputStream *)stream
                     options:(NSJSONWritingOptions)opt
                       error:(NSError **)error;
@end
