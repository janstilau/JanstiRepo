#import "common.h"
#import "Foundation/NSFormatter.h"

@implementation NSFormatter

- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
                                 withDefaultAttributes: (NSDictionary*)attr
{
    return nil;
}

- (id) copyWithZone: (NSZone*)zone
{
    return [[self class] allocWithZone: zone];
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
    return [self stringForObjectValue: anObject];
}

- (BOOL) getObjectValue: (id*)anObject
              forString: (NSString*)string
       errorDescription: (NSString**)error
{
    [self subclassResponsibility: _cmd];
    return NO;
}

- (BOOL) isPartialStringValid: (NSString*)partialString
             newEditingString: (NSString**)newString
             errorDescription: (NSString**)error
{
    *newString = nil;
    *error = nil;
    return YES;
}

- (BOOL) isPartialStringValid: (NSString**)partialStringPtr
        proposedSelectedRange: (NSRange*)proposedSelRangePtr
               originalString: (NSString*)origString
        originalSelectedRange: (NSRange)originalSelRangePtr
             errorDescription: (NSString**)error
{
    *error = nil;
    return YES;
}

- (NSString*) stringForObjectValue: (id)anObject
{
    [self subclassResponsibility: _cmd];
    return nil;
}
@end

