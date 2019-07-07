#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSJSONSerialization.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"
#import "GSFastEnumeration.h"

/* Boolean constants.
 */
static id       boolN;
static id       boolY;

/**
 * The number of (unicode) characters to fetch from the source at once.
 */
#define BUFFER_SIZE 64

/**
 * Structure for storing the internal state of the parser.  An instance of this
 * is allocated on the stack, and a copy of it passed down to each parse
 * function.
 */
typedef struct ParserStateStruct
{
    /**
     * The data source.  This is either an NSString or an NSStream, depending on
     * the source.
     */
    id source;
    /**
     * The length of the byte order mark in the source.  0 if there is no BOM.
     */
    int BOMLength;
    /**
     * The string encoding used in the source.
     */
    NSStringEncoding enc;
    /**
     * Function used to pull the next BUFFER_SIZE characters from the string.
     */
    void (*updateBuffer)(struct ParserStateStruct*);
    /**
     * Buffer used to store the next data from the input stream.
     */
    unichar buffer[BUFFER_SIZE];
    /**
     * The index of the parser within the buffer.
     */
    NSUInteger bufferIndex;
    /**
     * The number of bytes stored within the buffer.
     */
    NSUInteger bufferLength;
    /**
     * The index of the parser within the source.
     */
    NSInteger sourceIndex;
    /**
     * Should the parser construct mutable string objects?
     */
    BOOL mutableStrings;
    /**
     * Should the parser construct mutable containers?
     */
    BOOL mutableContainers;
    /**
     * Error value, if this parser is currently in an error state, nil otherwise.
     */
    NSError *error;
} JSONParaser;

/**
 * Pulls the next group of characters from a string source.
 
 So called callbak is just a function pointer. And the struct know how and when to call it. Normal, pass the whole struct as a parameter into this funciton.
 */
static inline void
updateStringBuffer(JSONParaser* state)
{
    NSRange r = {state->sourceIndex, BUFFER_SIZE};
    NSUInteger end = [state->source length];
    
    if (end - state->sourceIndex < BUFFER_SIZE)
    {
        // correct the range length here.
        r.length = end - state->sourceIndex;
    }
    [state->source getCharacters: state->buffer range: r]; // copy the character into bufffer.
    state->sourceIndex = r.location;
    state->bufferIndex = 0;
    state->bufferLength = r.length;// update propertys.
    if (r.length == 0)
    {
        state->buffer[0] = 0;
    }
}

static inline void
updateStreamBuffer(JSONParaser* state)
{
    NSInputStream *stream = state->source;
    uint8_t *buffer;
    NSUInteger length;
    NSString *str;
    
    // Discard anything that we've already consumed
    while (state->sourceIndex > 0)
    {
        uint8_t discard[128];
        NSUInteger toRead = 128;
        NSInteger amountRead;
        
        if (state->sourceIndex < 128)
        {
            toRead = state->sourceIndex;
        }
        amountRead = [stream read: discard maxLength: toRead];
        /* If something goes wrong with the stream, return the stream
         * error as our error.
         */
        if (amountRead == 0)
        {
            state->error = [stream streamError];
            state->bufferIndex = 0;
            state->bufferLength = 0;
            state->buffer[0] = 0;
        }
        state->sourceIndex -= amountRead;
    }
    
    /* Get the temporary buffer.  We need to read from here so that we can read
     * characters from the stream without advancing the stream position.
     * If the stream doesn't do buffering, then we need to get data one character
     * at a time.
     */
    if (![stream getBuffer: &buffer length: &length])
    {
        uint8_t bytes[7] = { 0 };
        
        switch (state->enc)
        {
            case NSUTF8StringEncoding:
            {
                // Read one UTF8 character from the stream
                NSUInteger i = 0;
                NSInteger n;
                
                n = [stream read: &bytes[0] maxLength: 1];
                if (n != 1)
                {
                    state->error = [stream streamError];
                    if (state->error == nil)
                    {
                        state->error
                        = [NSError errorWithDomain: NSCocoaErrorDomain
                                              code: 0
                                          userInfo: nil];
                    }
                    break;
                }
                else
                {
                    if ((bytes[0] & 0xC0) == 0xC0)
                    {
                        for (i = 1; i <= 5; i++)
                            if ((bytes[0] & (0x40 >> i)) == 0)
                                break;
                    }
                }
                if (0 == i)
                {
                    state->buffer[0] = bytes[0];
                }
                else
                {
                    n = [stream read: &bytes[1] maxLength: i];
                    if (n == i)
                    {
                        str = [[NSString alloc] initWithUTF8String: (char*)bytes];
                        [str getCharacters: state->buffer
                                     range: NSMakeRange(0,1)];
                        [str release];
                    }
                    else
                    {
                        state->error = [stream streamError];
                        if (state->error == nil)
                        {
                            state->error
                            = [NSError errorWithDomain: NSCocoaErrorDomain
                                                  code: 0
                                              userInfo: nil];
                        }
                        break;
                    }
                }
                break;
            }
            case NSUTF32LittleEndianStringEncoding:
            {
                [stream read: bytes maxLength: 4];
                state->buffer[0] = (unichar)NSSwapLittleIntToHost
                (*(unsigned int*)(void*)bytes);
                break;
            }
            case NSUTF32BigEndianStringEncoding:
            {
                [stream read: bytes maxLength: 4];
                state->buffer[0] = (unichar)NSSwapBigIntToHost
                (*(unsigned int*)(void*)bytes);
                break;
            }
            case NSUTF16LittleEndianStringEncoding:
            {
                [stream read: bytes maxLength: 2];
                state->buffer[0] = (unichar)NSSwapLittleShortToHost
                (*(unsigned short*)(void*)bytes);
                break;
            }
            case NSUTF16BigEndianStringEncoding:
            {
                [stream read: bytes maxLength: 4];
                state->buffer[0] = (unichar)NSSwapBigShortToHost
                (*(unsigned short*)(void*)bytes);
                break;
            }
            default:
                GS_UNREACHABLE();
        }
        // Set the source index to -1 so it will be 0 when we've finished with it
        state->sourceIndex = -1;
        state->bufferIndex = 0;
        state->bufferLength = 1;
        return;
    }
    // Use an NSString to do the character set conversion.  We could do this more
    // efficiently.  We could also reuse the string.
    str = [[NSString alloc] initWithBytesNoCopy: buffer
                                         length: length
                                       encoding: state->enc
                                   freeWhenDone: NO];
    // Just use the string buffer fetch function to actually get the data
    state->source = str;
    updateStringBuffer(state);
    state->source = stream;
}

/**
 * Returns the current character.
 */
static inline unichar
currentChar(JSONParaser *state)
{
    if (state->bufferIndex >= state->bufferLength)
    {
        state->updateBuffer(state);
    }
    return state->buffer[state->bufferIndex];
}

/**
 * Consumes a character.
 */
static inline unichar
consumeChar(JSONParaser *state)
{
    state->sourceIndex++;
    state->bufferIndex++;
    if (state->bufferIndex >= state->bufferLength)
    {
        state->updateBuffer(state);
    }
    return currentChar(state);
}

/**
 * Consumes all whitespace characters and returns the first non-space
 * character.  Returns 0 if we're past the end of the input.
 */
static inline unichar
consumeSpace(JSONParaser *state)
{
    while (isspace(currentChar(state)))
    {
        consumeChar(state);
    }
    return currentChar(state);
}

/**
 * Sets an error state.
 */
static void
parseError(JSONParaser *state)
{
    /* TODO: Work out what stuff should go in this and probably add them to
     * parameters for this function.
     */
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                              _(@"JSON Parse error"), NSLocalizedDescriptionKey,
                              _(([NSString stringWithFormat: @"Unexpected character %c at index %"PRIdPTR,
                                  (char)currentChar(state), state->sourceIndex])), 
                              NSLocalizedFailureReasonErrorKey,
                              nil];
    state->error = [NSError errorWithDomain: NSCocoaErrorDomain
                                       code: 0
                                   userInfo: userInfo];
    [userInfo release];
}


NS_RETURNS_RETAINED static id parseValue(JSONParaser *state);

/**
 * Parse a string, as defined by RFC4627, section 2.5
 */
NS_RETURNS_RETAINED static NSString*
parseString(JSONParaser *state)
{
    NSMutableString *result = nil;
    unichar buffer[BUFFER_SIZE];
    int bufferIndex = 0;
    unichar next;
    
    if (state->error)
    {
        return nil;
    }
    
    if (currentChar(state) != '"')
    {
        parseError(state);
        return nil;
    }
    
    next = consumeChar(state);
    while ((next != 0) && (next != '"'))
    {
        // Unexpected end of stream
        if (next == '\\')
        {
            next = consumeChar(state);
            switch (next)
            {
                    // Simple escapes, just ignore the leading '
                case '"':
                case '\\':
                case '/':
                    break;
                    // Map to the unicode values specified in RFC4627
                case 'b': next = 0x0008; break;
                case 'f': next = 0x000c; break;
                case 'n': next = 0x000a; break;
                case 'r': next = 0x000d; break;
                case 't': next = 0x0009; break;
                    // decode a unicode value from 4 hex digits
                case 'u': 
                {
                    char hex[5] = {0};
                    unsigned i;
                    for (i = 0 ; i < 4 ; i++)
                    {
                        next = consumeChar(state);
                        if (!isxdigit(next))
                        {
                            [result release];
                            parseError(state);
                            return nil;
                        }
                        hex[i] = next;
                    }
                    // Parse 4 hex digits and a NULL terminator into a 16-bit
                    // unicode character ID.
                    next = (unichar)strtol(hex, 0, 16);
                }
            }
        }
        buffer[bufferIndex++] = next;
        if (bufferIndex >= BUFFER_SIZE)
        {
            NSMutableString *str;
            
            str = [[NSMutableString alloc] initWithCharacters: buffer
                                                       length: bufferIndex];
            bufferIndex = 0;
            if (nil == result)
            {
                result = str;
            }
            else
            {
                [result appendString: str];
                [str release];
            }
        }
        next = consumeChar(state);
    }
    
    if (currentChar(state) != '"')
    {
        [result release];
        parseError(state);
        return nil;
    }
    
    if (bufferIndex > 0)
    {
        NSMutableString *str;
        
        str = [[NSMutableString alloc] initWithCharacters: buffer
                                                   length: bufferIndex];
        if (nil == result)
        {
            result = str;
        }
        else
        {
            [result appendString: str];
            [str release];
        }
    }
    else if (nil == result)
    {
        result = [NSMutableString new];
    }
    if (!state->mutableStrings)
    {
        if (NO == [result makeImmutable])
        {
            result = [result copy];
        }
    }
    // Consume the trailing "
    consumeChar(state);
    return result;
}

/**
 * Parses a number, as defined by section 2.4 of the JSON specification.
 */
NS_RETURNS_RETAINED static NSNumber*
parseNumber(JSONParaser *state)
{
    unichar c = currentChar(state);
    // delete the number get code.
    num = 1;
    return [[NSNumber alloc] initWithDouble: num];
}
/**
 * Parse an array, as described by section 2.3 of RFC 4627.
 */
NS_RETURNS_RETAINED static NSArray*
parseArray(JSONParaser *state)
{
    unichar c = consumeSpace(state); // First consum the prefix space here.
    NSMutableArray *resultArrayM;
    
    if (c != '[')
    {
        parseError(state);
        return nil;
    }
    // Eat the [
    consumeChar(state);
    resultArrayM = [NSMutableArray new];
    c = consumeSpace(state);
    while (c != ']')
    {
        // If this fails, it will already set the error, so we don't have to.
        id obj = parseValue(state);
        if (nil == obj)
        {
            [resultArrayM release];
            return nil; // some Error happen inside.
        }
        [resultArrayM addObject: obj];
        [obj release];
        c = consumeSpace(state);
        if (c == ',')
        {
            consumeChar(state);
            c = consumeSpace(state);
        }
    }
    // Eat the trailing ]
    consumeChar(state);
    if (!state->mutableContainers)
    {
        // If need a mutableArray, return the mutableOne. Normal return a unmutable Array.
        if (NO == [resultArrayM makeImmutable])
        {
            resultArrayM = [resultArrayM copy];
        }
    }
    return resultArrayM;
}

NS_RETURNS_RETAINED static NSDictionary*
parseObject(JSONParaser *state)
{
    unichar c = consumeSpace(state);
    NSMutableDictionary *dict;
    
    if (c != '{')
    {
        parseError(state);
        return nil;
    }
    // Eat the {
    consumeChar(state);
    dict = [NSMutableDictionary new];
    c = consumeSpace(state);
    while (c != '}')
    {
        id key = parseString(state);
        id obj;
        
        if (nil == key)
        {
            [dict release];
            return nil;
        }
        c = consumeSpace(state);
        if (':' != c)
        {
            [key release];
            [dict release];
            parseError(state);
            return nil;
        }
        // Eat the :
        consumeChar(state);
        obj = parseValue(state);
        if (nil == obj)
        {
            [key release];
            [dict release];
            return nil;
        }
        [dict setObject: obj forKey: key];
        [key release];
        [obj release];
        c = consumeSpace(state);
        if (c == ',')
        {
            consumeChar(state);
        }
        c = consumeSpace(state);
    }
    // Eat the trailing }
    consumeChar(state);
    if (!state->mutableContainers)
    {
        if (NO == [dict makeImmutable])
        {
            dict = [dict copy];
        }
    }
    return dict;
    
}

/**
 * Parses a JSON value, as defined by RFC4627, section 2.1.
 */
NS_RETURNS_RETAINED static id
parseValue(JSONParaser *state)
{
    unichar c;
    
    if (state->error) { return nil; };
    c = consumeSpace(state);
    switch (c) // parse every class if the first letter is a singal for class.
    {
        case (unichar)'"':
            return parseString(state);
        case (unichar)'[':
            return parseArray(state);
        case (unichar)'{':
            return parseObject(state);
        case (unichar)'-':
        case (unichar)'0' ... (unichar)'9':
            return parseNumber(state);
            // Literal null
        case 'n': // a specil consume cause null is a specil string as a class
        {
            if ((consumeChar(state) == 'u')
                && (consumeChar(state) == 'l')
                && (consumeChar(state) == 'l'))
            {
                consumeChar(state);
                return [[NSNull null] retain];
            }
            break;
        }
            // literal 
        case 't': // a specil consume cause true is a specil string as a class
        {
            if ((consumeChar(state) == 'r')
                && (consumeChar(state) == 'u')
                && (consumeChar(state) == 'e'))
            {
                consumeChar(state);
                return [boolY retain];
            }
            break;
        }
        case 'f': // a specil consume cause false is a specil string as a class
        {
            if ((consumeChar(state) == 'a')
                && (consumeChar(state) == 'l')
                && (consumeChar(state) == 's')
                && (consumeChar(state) == 'e'))
            {
                consumeChar(state);
                return [boolN retain];
            }
            break;
        }
    }
    parseError(state);
    return nil;
}

/**
 * We have to autodetect the string encoding.  We know that it is some
 * unicode encoding, which may or may not contain a BOM.  If it contains a
 * BOM, then we need to skip that.  If it doesn't, then we need to work out
 * the encoding from the position of the NULLs.  The first two characters are
 * guaranteed to be ASCII in a JSON stream, so we can work out the encoding
 * from the pattern of NULLs.
 */
static void
getEncoding(const uint8_t BOM[4], JSONParaser *state)
{
    NSStringEncoding enc = NSUTF8StringEncoding;
    int BOMLength = 0;
    
    if ((BOM[0] == 0xEF) && (BOM[1] == 0xBB) && (BOM[2] == 0xBF))
    {
        BOMLength = 3;
    }
    else if ((BOM[0] == 0xFE) && (BOM[1] == 0xFF))
    {
        BOMLength = 2;
        enc = NSUTF16BigEndianStringEncoding;
    }
    else if ((BOM[0] == 0xFF) && (BOM[1] == 0xFE))
    {
        if ((BOM[2] == 0) && (BOM[3] == 0))
        {
            BOMLength = 4;
            enc = NSUTF32LittleEndianStringEncoding;
        }
        else
        {
            BOMLength = 2;
            enc = NSUTF16LittleEndianStringEncoding;
        }
    }
    else if ((BOM[0] == 0)
             && (BOM[1] == 0)
             && (BOM[2] == 0xFE)
             && (BOM[3] == 0xFF))
    {
        BOMLength = 4;
        enc = NSUTF32BigEndianStringEncoding;
    }
    else if (BOM[0] == 0)
    {
        // TODO: Throw an error if this doesn't match one of the patterns
        // described in section 3 of RFC4627
        if (BOM[1] == 0)
        {
            enc = NSUTF32BigEndianStringEncoding;
        }
        else
        {
            enc = NSUTF16BigEndianStringEncoding;
        }
    }
    else if (BOM[1] == 0)
    {
        if (BOM[2] == 0)
        {
            enc = NSUTF32LittleEndianStringEncoding;
        }
        else
        {
            enc = NSUTF16LittleEndianStringEncoding;
        }
    }
    state->enc = enc;
    state->BOMLength = BOMLength;
}

/**
 * Classes that are permitted to be written.  
 */
static Class NSArrayClass;
static Class NSDictionaryClass;
static Class NSNullClass;
static Class NSNumberClass;
static Class NSStringClass;

static NSMutableCharacterSet *escapeSet;

static inline void
writeTabs(NSMutableString *output, NSInteger tabs)
{
    NSInteger i;
    
    for (i = 0 ; i < tabs ; i++)
    {
        [output appendString: @"\t"];
    }
}

static inline void
writeNewline(NSMutableString *output, NSInteger tabs)
{
    if (tabs >= 0)
    {
        [output appendString: @"\n"];
    }
}

/**
 * Write funciton will be called recursively.
 
 Don't to remember recursive funciton call stack. Just see the recursive as a abstrsct level. And code will run correctly if the logic is right.
 
 So JSONed must be the class in json rule. YYKit will translate a object to NSArray and NSDictionary and then jsoned the got NSArray or NSDictionary.
 */
static BOOL
writeObject(id obj, NSMutableString *outputStringM, NSInteger tabs) // tabs will added for 1, as the call into a new level.
{
    if ([obj isKindOfClass: NSArrayClass])
    {
        NSArray *arrayObj = (NSArray *)obj;
        BOOL writeComma = NO;
        [outputStringM appendString: @"["]; // write [ as a flag of an array.
        FOR_IN(id, aItem, arrayObj)
        if (writeComma)
        {
            [outputStringM appendString: @","];
        }
        writeComma = YES;
        writeNewline(outputStringM, tabs);
        writeTabs(outputStringM, tabs);
        writeObject(aItem, outputStringM, tabs + 1); // here wirte obj with the same funciton. And add new indent for tabs.
        END_FOR_IN(arrayObj)
        writeNewline(outputStringM, tabs);
        writeTabs(outputStringM, tabs);
        [outputStringM appendString: @"]"];
    }
    else if ([obj isKindOfClass: NSDictionaryClass])
    {
        BOOL writeComma = NO;
        [outputStringM appendString: @"{"];
        FOR_IN(id, dictKey, obj)
        // Keys in dictionaries must be strings
        if (![dictKey isKindOfClass: NSStringClass]) { return NO; } // is Key is not a stirng, return NO.
        if (writeComma)
        {
            [outputStringM appendString: @","];
        }
        writeComma = YES;
        writeNewline(outputStringM, tabs);
        writeTabs(outputStringM, tabs);
        writeObject(dictKey, outputStringM, tabs + 1);
        [outputStringM appendString: @": "];
        writeObject([obj objectForKey: dictKey], outputStringM, tabs + 1);
        END_FOR_IN(obj)
        writeNewline(outputStringM, tabs);
        writeTabs(outputStringM, tabs);
        [outputStringM appendString: @"}"];
    }
    else if ([obj isKindOfClass: NSStringClass])
    {
        NSString  *str = (NSString*)obj;
        unsigned	length = [str length];
        
        if (length == 0)
        {
            [outputStringM appendString: @"\"\""]; // write empty string.
        }
        else
        {
            unsigned	size = 2;
            unichar	*from;
            unsigned	i = 0;
            unichar	*to;
            unsigned	j = 0;
            
            from = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * length);
            [str getCharacters: from];
            
            for (i = 0; i < length; i++)
            {
                unichar	c = from[i];
                
                if (c == '"' || c == '\\' || c == '\b'
                    || c == '\f' || c == '\n' || c == '\r' || c == '\t')
                {
                    size += 2;
                }
                else if (c < 0x20)
                {
                    size += 6;
                }
                else
                {
                    size++;
                }
            }
            
            to = NSZoneMalloc (NSDefaultMallocZone(), sizeof(unichar) * size);
            to[j++] = '"';
            for (i = 0; i < length; i++)
            {
                unichar	c = from[i];
                
                if (c == '"' || c == '\\' || c == '\b'
                    || c == '\f' || c == '\n' || c == '\r' || c == '\t')
                {
                    to[j++] = '\\';
                    switch (c)
                    {
                        case '\\': to[j++] = '\\'; break;
                        case '\b': to[j++] = 'b'; break;
                        case '\f': to[j++] = 'f'; break;
                        case '\n': to[j++] = 'n'; break;
                        case '\r': to[j++] = 'r'; break;
                        case '\t': to[j++] = 't'; break;
                        default: to[j++] = '"'; break;
                    }
                }
                else if (c < 0x20)
                {
                    char	buf[5];
                    
                    to[j++] = '\\';
                    to[j++] = 'u';
                    sprintf(buf, "%04x", c);
                    to[j++] = buf[0];
                    to[j++] = buf[1];
                    to[j++] = buf[2];
                    to[j++] = buf[3];
                }
                else
                {
                    to[j++] = c;
                }
            }
            to[j] = '"';
            str = [[NSStringClass alloc] initWithCharacters: to length: size];
            NSZoneFree (NSDefaultMallocZone (), to);
            NSZoneFree (NSDefaultMallocZone (), from);
            [outputStringM appendString: str];
            [str release];
        }
    }
    else if (obj == boolN)
    {
        [outputStringM appendString: @"false"];
    }
    else if (obj == boolY)
    {
        [outputStringM appendString: @"true"];
    }
    else if ([obj isKindOfClass: NSNumberClass])
    {
        const char        *t = [obj objCType];
        
        if (strchr("csilq", *t) != 0)
        {
            long long     i = [(NSNumber*)obj longLongValue];
            
            [outputStringM appendFormat: @"%lld", i];
        }
        else if (strchr("CSILQ", *t) != 0)
        {
            unsigned long long u = [(NSNumber *)obj unsignedLongLongValue];
            [outputStringM appendFormat: @"%llu", u];
        }
        else
        {
            [outputStringM appendFormat: @"%.17g", [(NSNumber*)obj doubleValue]];
        }
    }
    else if ([obj isKindOfClass: NSNullClass])
    {
        [outputStringM appendString: @"null"];
    }
    else
    {
        return NO; // if Obj is not a valid class. return NO.
    }
    return YES;
}

@implementation NSJSONSerialization
+ (void) initialize
{
    static BOOL beenHere = NO;
    
    if (NO == beenHere)
    {
        NSNullClass = [NSNull class];
        NSArrayClass = [NSArray class];
        NSStringClass = [NSString class];
        NSDictionaryClass = [NSDictionary class];
        NSNumberClass = [NSNumber class];
        escapeSet = [NSMutableCharacterSet new];
        [escapeSet addCharactersInString: @"\"\\"];
        boolN = [[NSNumber alloc] initWithBool: NO];
        boolY = [[NSNumber alloc] initWithBool: YES];
        beenHere = YES;
    }
}

+ (NSData*) dataWithJSONObject: (id)obj
                       options: (NSJSONWritingOptions)opt
                         error: (NSError **)error
{
    NSMutableString *jsonedString = [[NSMutableString alloc] initWithCapacity: 4096];
    NSData *data = nil;
    NSUInteger tabs;
    
    tabs = ((opt & NSJSONWritingPrettyPrinted) == NSJSONWritingPrettyPrinted) ?
    0 : NSIntegerMin;
    if (writeObject(obj, jsonedString, tabs))
    {
        data = [jsonedString dataUsingEncoding: NSUTF8StringEncoding];
        if (NULL != error)
        {
            *error = nil;
        }
    }
    else
    {
        if (NULL != error)
        {
            NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                                      @"JSON writing error", NSLocalizedDescriptionKey,
                                      nil];
            *error = [NSError errorWithDomain: NSCocoaErrorDomain
                                         code: 0
                                     userInfo: userInfo];
        }
    }
    [jsonedString release];
    return data;
}

+ (BOOL) isValidJSONObject: (id)obj
{
    // So the get function will call the writeObejct function.
    return writeObject(obj, nil, NSIntegerMin);
}

+ (id) JSONObjectWithData: (NSData *)data
                  options: (NSJSONReadingOptions)opt
                    error: (NSError **)error
{
    uint8_t BOM[4];
    JSONParaser p = { 0 };
    id obj;
    
    [data getBytes: BOM length: 4];
    getEncoding(BOM, &p);
    p.source = [[NSString alloc] initWithData: data encoding: p.enc];
    p.updateBuffer = updateStringBuffer;
    p.mutableContainers
    = (opt & NSJSONReadingMutableContainers) == NSJSONReadingMutableContainers;
    p.mutableStrings
    = (opt & NSJSONReadingMutableLeaves) == NSJSONReadingMutableLeaves;
    // all options will be property in JSONParser. And the real funcion is encapsulated in that struct.
    obj = parseValue(&p);
    [p.source release];
    if (NULL != error)
    {
        *error = p.error;
    }
    return [obj autorelease];
}

+ (id) JSONObjectWithStream: (NSInputStream *)stream
                    options: (NSJSONReadingOptions)opt
                      error: (NSError **)error
{
    uint8_t BOM[4];
    JSONParaser p = { 0 };
    id obj;
    
    [stream read: (uint8_t*)BOM maxLength: 4];
    getEncoding(BOM, &p);
    p.mutableContainers = (opt & NSJSONReadingMutableContainers) == NSJSONReadingMutableContainers;
    p.mutableStrings = (opt & NSJSONReadingMutableLeaves) == NSJSONReadingMutableLeaves;
    
    if (p.BOMLength < 4)
    {
        p.source = [[NSString alloc] initWithBytesNoCopy: &BOM[p.BOMLength]
                                                  length: 4 - p.BOMLength
                                                encoding: p.enc
                                            freeWhenDone: NO];
        updateStringBuffer(&p);
        p.sourceIndex = p.BOMLength - 4;
    }
    p.source = stream;
    p.updateBuffer = updateStreamBuffer;
    obj = parseValue(&p);
    // Consume any data in the stream that we've failed to read
    updateStreamBuffer(&p);
    if (NULL != error)
    {
        *error = p.error;
    }
    return [obj autorelease];
}

+ (NSInteger) writeJSONObject: (id)obj
                     toStream: (NSOutputStream *)stream
                      options: (NSJSONWritingOptions)opt
                        error: (NSError **)error
{
    NSData *data = [self dataWithJSONObject: obj options: opt error: error];
    
    if (nil != data)
    {
        const char *bytes = [data bytes];
        NSUInteger toWrite = [data length];
        
        while (toWrite > 0)
        {
            NSInteger wrote = [stream write: (uint8_t*)bytes maxLength: toWrite];
            bytes += wrote;
            toWrite -= wrote;
            if (0 == wrote)
            {
                if (NULL != error)
                {
                    *error = [stream streamError];
                }
                return 0;
            }
        }
    }
    return [data length];
}
@end
