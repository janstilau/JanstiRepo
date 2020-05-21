#import "common.h"

#if defined(HAVE_LIBXML)

#define GSInternal	NSXMLDTDNodeInternal

#import	"NSXMLPrivate.h"
#import "GSInternal.h"
GS_PRIVATE_INTERNAL(NSXMLDTDNode)

@implementation NSXMLDTDNode

- (void) dealloc
{
    if (GS_EXISTS_INTERNAL)
    {
    }
    [super dealloc];
}

- (NSXMLDTDNodeKind) DTDKind
{
    return internal->DTDKind;
}

- (void) _createInternal
{
    GS_CREATE_INTERNAL(NSXMLDTDNode);
}

- (id) initWithKind: (NSXMLNodeKind)theKind options: (NSUInteger)theOptions
{
    if (NSXMLEntityDeclarationKind == theKind
        || NSXMLElementDeclarationKind == theKind
        || NSXMLNotationDeclarationKind == theKind)
    {
        return [super initWithKind: theKind options: theOptions];
    }
    else
    {
        [self release];
        // This cast is here to keep clang quite that expects an init* method to
        // return an object of the same class, which is not true here.
        return (NSXMLDTDNode*)[[NSXMLNode alloc] initWithKind: theKind
                                                      options: theOptions];
    }
}

- (id) initWithXMLString: (NSString*)string
{
    NSXMLDTDNode *result = nil;
    NSError *error;
    NSXMLDocument *tempDoc =
    [[NSXMLDocument alloc] initWithXMLString: string
                                     options: 0
                                       error: &error];
    if (tempDoc != nil)
    {
        result = (NSXMLDTDNode*)RETAIN([tempDoc childAtIndex: 0]);
        [result detach]; // detach from document.
    }
    [tempDoc release];
    [self release];
    
    return result;
}

- (BOOL) isExternal
{
    if ([self systemID])
    {
        return YES;
    }
    return NO;
}

- (NSString*) notationName
{
    return StringFromXMLStringPtr(internal->node.entity->name);
}

- (NSString*) publicID
{
    return StringFromXMLStringPtr(internal->node.entity->ExternalID);
}

- (void) setDTDKind: (NSXMLDTDNodeKind)nodeKind
{
    internal->DTDKind = nodeKind;
}

- (void) setNotationName: (NSString*)notationName
{
    internal->node.entity->name = XMLSTRING(notationName);
}

- (void) setPublicID: (NSString*)publicID
{
    internal->node.entity->ExternalID = XMLSTRING(publicID);
}

- (void) setSystemID: (NSString*)systemID
{
    internal->node.entity->ExternalID = XMLSTRING(systemID);
}

- (NSString*) systemID
{
    return StringFromXMLStringPtr(internal->node.entity->SystemID);
}

@end

#endif	/* HAVE_LIBXML */
