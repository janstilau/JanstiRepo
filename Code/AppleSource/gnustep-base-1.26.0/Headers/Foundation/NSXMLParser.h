#ifndef __NSXMLParser_h_GNUSTEP_BASE_INCLUDE
#define __NSXMLParser_h_GNUSTEP_BASE_INCLUDE
#import	<GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_3, GS_API_LATEST)

#import	<Foundation/NSObject.h>

@class NSData, NSDictionary, NSError, NSString, NSURL;

/**
 * Domain for errors
 */
GS_EXPORT NSString* const NSXMLParserErrorDomain;

/**
 * This class is a PRE-ALPHA implementation.  You should be prepared to
 * track down and fix bugs and preferably contribute fixes back.<br />
 * If you don't want to do that, use the [GSXMLParser] class instead ...
 * This NSXMLParser class is implemented as a wrapper round some of the
 * functionality of the more powerful GSXML APIs, and is intended as a
 * MacOSX compatibility feature.
 * <p>
 *   This class implements an event driven parser handling the parsing
 *   process by sending messages to a delegate when certain parts of the
 *   XML document being parsed are encountered.
 * </p>
 * <p>
 *   To use the class, you create and initialise an instance with a particular
 *   XML document, set the delegate of the instance, and send a -parse message
 *   to it.  The delegate must then make use of the information it receives
 *   in the messages it gets from the parser.
 * </p>
 * <p>
 *   The [NSObject(NSXMLParserDelegateEventAdditions)] informal protocol
 *   documents the methods which the delegate object may implement in order
 *   to handle the parsing process.
 * </p>
 */
@interface NSXMLParser : NSObject
{
@public
    void		*_parser;	// GSXMLParser
    void		*_handler;	// SAXHandler
}

/**
 * Terminates the current parse operation and sends an error to the
 * delegate of the parser.
 */
- (void) abortParsing;

/**
 * Returns the delegate previously set using -setDelegate: or nil if
 * no delegate is set.
 */
- (id) delegate;

/**
 * Convenience method fetching data from anURL.<br />
 */
- (id) initWithContentsOfURL: (NSURL*)anURL;

/** <init />
 * Initialises the parser with the specified xml data.
 */
- (id) initWithData: (NSData*)data;

/**
 * Parses the supplied data and returns YES on success, NO otherwise.
 */
- (BOOL) parse;

/**
 * Returns the last error produced by parsing (if any).
 */
- (NSError*) parserError;

/**
 * Sets the parser delegate (which is not retained).
 */
- (void) setDelegate: (id)delegate;

/**
 * Set flag to determine whether the namespaceURI and the qualified name
 * of an element is provided in the
 * [NSObject(NSXMLParserDelegateEventAdditions)-parser:didStartElement:namespaceURI:qualifiedName:attributes:]
 * and [NSObject(NSXMLParserDelegateEventAdditions)-parser:didEndElement:namespaceURI:qualifiedName:] methods.
 */
- (void) setShouldProcessNamespaces: (BOOL)aFlag;

/**
 * Sets a flag to specify whether the parser should call the
 * [NSObject(NSXMLParserDelegateEventAdditions)-parser:didStartMappingPrefix:toURI:] and
 * [NSObject(NSXMLParserDelegateEventAdditions)-parser:didEndMappingPrefix:] delegate methods.
 */
- (void) setShouldReportNamespacePrefixes: (BOOL)aFlag;

/**
 * Sets flag to determine if declarations of external entities are
 * reported using
 * [NSObject(NSXMLParserDelegateEventAdditions)-parser:foundExternalEntityDeclarationWithName:publicID:systemID:]
 */
- (void) setShouldResolveExternalEntities: (BOOL)aFlag;

/**
 * Returns the value set by -setShouldProcessNamespaces:
 */
- (BOOL) shouldProcessNamespaces;

/**
 * Returns the value set by -setShouldReportNamespacePrefixes:
 */
- (BOOL) shouldReportNamespacePrefixes;

/**
 * Returns the value set by -setShouldResolveExternalEntities:
 */
- (BOOL) shouldResolveExternalEntities;

@end

@interface NSXMLParser (NSXMLParserLocatorAdditions)
/**
 * Returns the current column number of the document being parsed.
 */
- (NSInteger) columnNumber;

/**
 * Returns the current line number of the document being parsed.
 */
- (NSInteger) lineNumber;

/**
 * Returns the public identifier of the external entity in the
 * document being parsed.
 */
- (NSString*) publicID;

/**
 * Returns the system identifier of the external entity in the
 * document being parsed.
 */
- (NSString*) systemID;
@end

/**
 * Methods implemented by a delegate in order to make use of the parser.<br />
 * This is now a formal protocol.
 */
@protocol NSXMLParserDelegate <NSObject>
@optional
@end
@interface NSObject (NSXMLParserDelegateEventAdditions)

/** <override-dummy />
 */
- (NSData*) parser: (NSXMLParser*)aParser
resolveExternalEntityName: (NSString*)aName
          systemID: (NSString*)aSystemID;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)anElementName
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
didEndMappingPrefix: (NSString*)aPrefix;

/** <override-dummy />
 * Called when the start of an element is encountered in the document,
 * this provides the name of the element, a dictionary containing the
 * attributes (if any) and (where namespaces are used) the namespace
 * information for the element.
 */
- (void) parser: (NSXMLParser*)aParser
didStartElement: (NSString*)anElementName
   namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
     attributes: (NSDictionary*)anAttributeDict;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
didStartMappingPrefix: (NSString*)aPrefix
          toURI: (NSString*)aNamespaceURI;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundAttributeDeclarationWithName: (NSString*)anAttributeName
     forElement: (NSString*)anElementName
           type: (NSString*)aType
   defaultValue: (NSString*)aDefaultValue;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
     foundCDATA: (NSData*)aBlock;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundCharacters: (NSString*)aString;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
   foundComment: (NSString*)aComment;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundElementDeclarationWithName: (NSString*)anElementName
          model: (NSString*)aModel;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundExternalEntityDeclarationWithName: (NSString*)aName
       publicID: (NSString*)aPublicID
       systemID: (NSString*)aSystemID;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundIgnorableWhitespace: (NSString*)aWhitespaceString;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundInternalEntityDeclarationWithName: (NSString*)aName
          value: (NSString*)aValue;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundNotationDeclarationWithName: (NSString*)aName
       publicID: (NSString*)aPublicID
       systemID: (NSString*)aSystemID;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundProcessingInstructionWithTarget: (NSString*)aTarget
           data: (NSString*)aData;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
foundUnparsedEntityDeclarationWithName: (NSString*)aName
       publicID: (NSString*)aPublicID
       systemID: (NSString*)aSystemID
   notationName: (NSString*)aNotationName;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
parseErrorOccurred: (NSError*)anError;

/** <override-dummy />
 */
- (void) parser: (NSXMLParser*)aParser
validationErrorOccurred: (NSError*)anError;

/** <override-dummy />
 * Called when parsing ends.
 */
- (void) parserDidEndDocument: (NSXMLParser*)aParser;

/** <override-dummy />
 * Called when parsing begins.
 */
- (void) parserDidStartDocument: (NSXMLParser*)aParser;
@end

/*
 * Provide the same error codes as MacOS-X, even if we don't use them all.
 */
enum {
    NSXMLParserInternalError = 1,
    NSXMLParserOutOfMemoryError = 2,
    NSXMLParserDocumentStartError = 3,
    NSXMLParserEmptyDocumentError = 4,
    NSXMLParserPrematureDocumentEndError = 5,
    NSXMLParserInvalidHexCharacterRefError = 6,
    NSXMLParserInvalidDecimalCharacterRefError = 7,
    NSXMLParserInvalidCharacterRefError = 8,
    NSXMLParserInvalidCharacterError = 9,
    NSXMLParserCharacterRefAtEOFError = 10,
    NSXMLParserCharacterRefInPrologError = 11,
    NSXMLParserCharacterRefInEpilogError = 12,
    NSXMLParserCharacterRefInDTDError = 13,
    NSXMLParserEntityRefAtEOFError = 14,
    NSXMLParserEntityRefInPrologError = 15,
    NSXMLParserEntityRefInEpilogError = 16,
    NSXMLParserEntityRefInDTDError = 17,
    NSXMLParserParsedEntityRefAtEOFError = 18,
    NSXMLParserParsedEntityRefInPrologError = 19,
    NSXMLParserParsedEntityRefInEpilogError = 20,
    NSXMLParserParsedEntityRefInInternalSubsetError = 21,
    NSXMLParserEntityReferenceWithoutNameError = 22,
    NSXMLParserEntityReferenceMissingSemiError = 23,
    NSXMLParserParsedEntityRefNoNameError = 24,
    NSXMLParserParsedEntityRefMissingSemiError = 25,
    NSXMLParserUndeclaredEntityError = 26,
    NSXMLParserUnparsedEntityError = 28,
    NSXMLParserEntityIsExternalError = 29,
    NSXMLParserEntityIsParameterError = 30,
    NSXMLParserUnknownEncodingError = 31,
    NSXMLParserEncodingNotSupportedError = 32,
    NSXMLParserStringNotStartedError = 33,
    NSXMLParserStringNotClosedError = 34,
    NSXMLParserNamespaceDeclarationError = 35,
    NSXMLParserEntityNotStartedError = 36,
    NSXMLParserEntityNotFinishedError = 37,
    NSXMLParserLessThanSymbolInAttributeError = 38,
    NSXMLParserAttributeNotStartedError = 39,
    NSXMLParserAttributeNotFinishedError = 40,
    NSXMLParserAttributeHasNoValueError = 41,
    NSXMLParserAttributeRedefinedError = 42,
    NSXMLParserLiteralNotStartedError = 43,
    NSXMLParserLiteralNotFinishedError = 44,
    NSXMLParserCommentNotFinishedError = 45,
    NSXMLParserProcessingInstructionNotStartedError = 46,
    NSXMLParserProcessingInstructionNotFinishedError = 47,
    NSXMLParserNotationNotStartedError = 48,
    NSXMLParserNotationNotFinishedError = 49,
    NSXMLParserAttributeListNotStartedError = 50,
    NSXMLParserAttributeListNotFinishedError = 51,
    NSXMLParserMixedContentDeclNotStartedError = 52,
    NSXMLParserMixedContentDeclNotFinishedError = 53,
    NSXMLParserElementContentDeclNotStartedError = 54,
    NSXMLParserElementContentDeclNotFinishedError = 55,
    NSXMLParserXMLDeclNotStartedError = 56,
    NSXMLParserXMLDeclNotFinishedError = 57,
    NSXMLParserConditionalSectionNotStartedError = 58,
    NSXMLParserConditionalSectionNotFinishedError = 59,
    NSXMLParserExternalSubsetNotFinishedError = 60,
    NSXMLParserDOCTYPEDeclNotFinishedError = 61,
    NSXMLParserMisplacedCDATAEndStringError = 62,
    NSXMLParserCDATANotFinishedError = 63,
    NSXMLParserMisplacedXMLDeclarationError = 64,
    NSXMLParserSpaceRequiredError = 65,
    NSXMLParserSeparatorRequiredError = 66,
    NSXMLParserNMTOKENRequiredError = 67,
    NSXMLParserNAMERequiredError = 68,
    NSXMLParserPCDATARequiredError = 69,
    NSXMLParserURIRequiredError = 70,
    NSXMLParserPublicIdentifierRequiredError = 71,
    NSXMLParserLTRequiredError = 72,
    NSXMLParserGTRequiredError = 73,
    NSXMLParserLTSlashRequiredError = 74,
    NSXMLParserEqualExpectedError = 75,
    NSXMLParserTagNameMismatchError = 76,
    NSXMLParserUnfinishedTagError = 77,
    NSXMLParserStandaloneValueError = 78,
    NSXMLParserInvalidEncodingNameError = 79,
    NSXMLParserCommentContainsDoubleHyphenError = 80,
    NSXMLParserInvalidEncodingError = 81,
    NSXMLParserExternalStandaloneEntityError = 82,
    NSXMLParserInvalidConditionalSectionError = 83,
    NSXMLParserEntityValueRequiredError = 84,
    NSXMLParserNotWellBalancedError = 85,
    NSXMLParserExtraContentError = 86,
    NSXMLParserInvalidCharacterInEntityError = 87,
    NSXMLParserParsedEntityRefInInternalError = 88,
    NSXMLParserEntityRefLoopError = 89,
    NSXMLParserEntityBoundaryError = 90,
    NSXMLParserInvalidURIError = 91,
    NSXMLParserURIFragmentError = 92,
    NSXMLParserNoDTDError = 94,
    NSXMLParserDelegateAbortedParseError = 512
};
typedef NSUInteger NSXMLParserError;

#endif
#endif	/* __NSXMLParser_h_GNUSTEP_BASE_INCLUDE */
