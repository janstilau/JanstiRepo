#import "common.h"

#if !defined (__GNU_LIBOBJC__)
#  include <objc/encoding.h>
#endif

#define	EXPOSE_NSArchiver_IVARS	1
#define	EXPOSE_NSUnarchiver_IVARS	1
/*
 *	Setup for inline operation of pointer map tables.
 */
#define	GSI_MAP_KTYPES	GSUNION_NSINT | GSUNION_PTR | GSUNION_OBJ | GSUNION_CLS
#define	GSI_MAP_VTYPES	GSUNION_NSINT | GSUNION_PTR | GSUNION_OBJ
#define	GSI_MAP_RETAIN_KEY(M, X)	
#define	GSI_MAP_RELEASE_KEY(M, X)	
#define	GSI_MAP_RETAIN_VAL(M, X)	
#define	GSI_MAP_RELEASE_VAL(M, X)	
#define	GSI_MAP_HASH(M, X)	((X).nsu)
#define	GSI_MAP_EQUAL(M, X,Y)	((X).ptr == (Y).ptr)
#define	GSI_MAP_NOCLEAN	1


#include "GNUstepBase/GSIMap.h"

#define	_IN_NSARCHIVER_M
#import "Foundation/NSArchiver.h"
#undef	_IN_NSARCHIVER_M

#import "Foundation/NSCoder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSException.h"

typedef	unsigned char	uchar;

NSString * const NSInconsistentArchiveException =
@"NSInconsistentArchiveException";

#define	PREFIX		"GNUstep archive"

static SEL serSel;
static SEL tagSel;
static SEL xRefSel;
static SEL encodeObjectSEL;
static SEL encodeValueOfObjCTypeAtSEL;

@class NSMutableDataMalloc;
@interface NSMutableDataMalloc : NSObject	// Help the compiler
@end
static Class	NSMutableDataMallocClass;

/**
 *  <p>Implementation of [NSCoder] capable of creating sequential archives which
 *  must be read in the same order they were written.  This class implements
 *  methods for saving to and restoring from a serial archive (usually a file
 *  on disk, but can be an [NSData] object) as well as methods that can be
 *  used by objects that need to write/restore themselves.</p>
 *
 * <p>Note, the sibling class [NSKeyedArchiver] supports a form of archive
 *  that is more robust to class changes, and is recommended over this one.</p>
 */
@implementation NSArchiver
{
}

+ (void) initialize
{
    if (self == [NSArchiver class])
    {
        serSel = @selector(serializeDataAt:ofObjCType:context:);
        tagSel = @selector(serializeTypeTag:);
        xRefSel = @selector(serializeTypeTag:andCrossRef:);
        encodeObjectSEL = @selector(encodeObject:);
        encodeValueOfObjCTypeAtSEL = @selector(encodeValueOfObjCType:at:);
        NSMutableDataMallocClass = [NSMutableDataMalloc class];
    }
}

- (id) init
{
    NSMutableData	*d;
    d = [[NSMutableDataMallocClass allocWithZone: [self zone]] init];
    self = [self initForWritingWithMutableData: d];
    RELEASE(d);
    return self;
}

/**
 *  Init instance that will archive its data to mdata.  (Even if
 *  [archiveRootObject:toFile:] is called, this still gets written to.)
 */
- (id) initForWritingWithMutableData: (NSMutableData*)mdata
{
    self = [super init];
    if (self)
    {
        NSZone		*zone = [self zone];
        
        _data = RETAIN(mdata);
        _destination = _data;
        
        _serImp = [_destination methodForSelector: serSel];
        _tagImp = [_destination methodForSelector: tagSel];
        _xRefImp = [_destination methodForSelector: xRefSel];
        _encodeObjectImp = [self methodForSelector: encodeObjectSEL];
        _eValImp = [self methodForSelector: encodeValueOfObjCTypeAtSEL];
        
        [self resetArchiver];
        
        /*
         *	Set up map tables.
         */
        _clsMap = (GSIMapTable)NSZoneMalloc(zone, sizeof(GSIMapTable_t)*6);
        _conditionIdMap = &_clsMap[1];
        _unconditionIdMap = &_clsMap[2];
        _pointerMap = &_clsMap[3];
        _namesMap = &_clsMap[4];
        _objectsMap = &_clsMap[5];
        GSIMapInitWithZoneAndCapacity(_clsMap, zone, 100);
        GSIMapInitWithZoneAndCapacity(_conditionIdMap, zone, 10);
        GSIMapInitWithZoneAndCapacity(_unconditionIdMap, zone, 200);
        GSIMapInitWithZoneAndCapacity(_pointerMap, zone, 100);
        GSIMapInitWithZoneAndCapacity(_namesMap, zone, 1);
        GSIMapInitWithZoneAndCapacity(_objectsMap, zone, 1);
    }
    return self;
}

- (void) dealloc
{
    RELEASE(_data);
    if (_clsMap)
    {
        GSIMapEmptyMap(_clsMap);
        if (_conditionIdMap)
        {
            GSIMapEmptyMap(_conditionIdMap);
        }
        if (_unconditionIdMap)
        {
            GSIMapEmptyMap(_unconditionIdMap);
        }
        if (_pointerMap)
        {
            GSIMapEmptyMap(_pointerMap);
        }
        if (_namesMap)
        {
            GSIMapEmptyMap(_namesMap);
        }
        if (_objectsMap)
        {
            GSIMapEmptyMap(_objectsMap);
        }
        NSZoneFree(_clsMap->zone, (void*)_clsMap);
    }
    [super dealloc];
}

/**
 这个就是利用 archive 进行 encode 之后, 取得它的内部值然后进行一次 copy 而已.
 
 */
+ (NSData*) archivedDataWithRootObject: (id)rootObject
{
    NSArchiver	*archiver;
    id		resultM;
    NSZone	*z = NSDefaultMallocZone();
    
    resultM = [[NSMutableDataMallocClass allocWithZone: z] initWithCapacity: 0];
    if (resultM == nil)
    {
        return nil;
    }
    archiver = [[self allocWithZone: z] initForWritingWithMutableData: resultM];
    RELEASE(resultM);
    resultM = nil;
    if (archiver)
    {
       [archiver encodeRootObject: rootObject];
        resultM = AUTORELEASE([archiver->_data copy]);
    }
    
    return resultM;
}

/**
 先归档取得 NSData , 然后写入到文件中.
 
 */
+ (BOOL) archiveRootObject: (id)rootObject
                    toFile: (NSString*)path
{
    id	d = [self archivedDataWithRootObject: rootObject];
    return [d writeToFile: path atomically: YES];
}

- (void) encodeArrayOfObjCType: (const char*)type
                         count: (NSUInteger)count
                            at: (const void*)buf
{
    // 这里, 直接用 NSCode 的实现也能达到目的.
}

/*
 NSDictionary 的归档方法.
 {
 [aCoder encodeValueOfObjCType: @encode(unsigned) at: &count];
 if (count > 0)
 {
 NSEnumerator    *enumerator = [self keyEnumerator];
 id        key;
 IMP        enc;
 IMP        nxt;
 IMP        ofk;
 
 nxt = [enumerator methodForSelector: @selector(nextObject)];
 enc = [aCoder methodForSelector: @selector(encodeObject:)];
 ofk = [self methodForSelector: @selector(objectForKey:)];
 
 while ((key = (*nxt)(enumerator, @selector(nextObject))) != nil)
 {
 id    val = (*ofk)(self, @selector(objectForKey:), key);
 
 (*enc)(aCoder, @selector(encodeObject:), key);
 (*enc)(aCoder, @selector(encodeObject:), val);
 }
 }
 }
 
 
 */

// 最重要的方法.
- (void) encodeValueOfObjCType: (const char*)type
                            at: (const void*)buf
{
    type = GSSkipTypeQualifierAndLayoutInfo(type);
    switch (*type)
    {
        case _C_ID:
            (*_encodeObjectImp)(self, encodeObjectSEL, *(void**)buf);
            return;
            
        case _C_ARY_B:
        {
            unsigned	count = atoi(++type);
            
            while (isdigit(*type))
            {
                type++;
            }
            
            if (_initialPass == NO)
            {
                (*_tagImp)(_destination, tagSel, _GSC_ARY_B);
            }
            
            [self encodeArrayOfObjCType: type count: count at: buf];
        }
            return;
            
        case _C_STRUCT_B:
        {
            struct objc_struct_layout layout;
            
            if (_initialPass == NO)
            {
                (*_tagImp)(_destination, tagSel, _GSC_STRUCT_B);
            }
            objc_layout_structure (type, &layout);
            while (objc_layout_structure_next_member (&layout))
            {
                unsigned		offset;
                unsigned		align;
                const char	*ftype;
                
                objc_layout_structure_get_info (&layout, &offset, &align, &ftype);
                
                (*_eValImp)(self, eValSel, ftype, (char*)buf + offset);
            }
        }
            return;
            
        case _C_PTR:
            if (*(void**)buf == 0)
            {
                if (_initialPass == NO)
                {
                    /*
                     *	Special case - a null pointer gets an xref of zero
                     */
                    (*_tagImp)(_destination, tagSel, _GSC_PTR | _GSC_XREF | _GSC_X_0);
                }
            }
            else
            {
                GSIMapNode	node;
                
                node = GSIMapNodeForKey(_pointerMap, (GSIMapKey)*(void**)buf);
                if (_initialPass == YES)
                {
                    /*
                     *	First pass - add pointer to map and encode item pointed
                     *	to in case it is a conditionally encoded object.
                     */
                    if (node == 0)
                    {
                        GSIMapAddPair(_pointerMap,
                                      (GSIMapKey)*(void**)buf, (GSIMapVal)(NSUInteger)0);
                        type++;
                        buf = *(char**)buf;
                        (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, type, buf);
                    }
                }
                else if (node == 0 || node->value.nsu == 0)
                {
                    /*
                     *	Second pass, unwritten pointer - write it.
                     */
                    if (node == 0)
                    {
                        node = GSIMapAddPair(_pointerMap,
                                             (GSIMapKey)*(void**)buf, (GSIMapVal)(NSUInteger)++_xRefP);
                    }
                    else
                    {
                        node->value.nsu = ++_xRefP;
                    }
                    (*_xRefImp)(_destination, xRefSel, _GSC_PTR, node->value.nsu);
                    type++;
                    buf = *(char**)buf;
                    (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, type, buf);
                }
                else
                {
                    /*
                     *	Second pass, write a cross-reference number.
                     */
                    (*_xRefImp)(_destination, xRefSel, _GSC_PTR|_GSC_XREF,
                                node->value.nsu);
                }
            }
            return;
            
        default:	/* Types that can be ignored in first pass.	*/
            if (_initialPass)
            {
                return;
            }
            break;
    }
    
    switch (*type)
    {
        case _C_CLASS:
            if (*(Class*)buf == 0)
            {
                /*
                 *	Special case - a null pointer gets an xref of zero
                 */
                (*_tagImp)(_destination, tagSel, _GSC_CLASS | _GSC_XREF | _GSC_X_0);
            }
            else
            {
                Class	c = *(Class*)buf;
                GSIMapNode	node;
                BOOL	done = NO;
                
                node = GSIMapNodeForKey(_clsMap, (GSIMapKey)(void*)c);
                
                if (node != 0)
                {
                    (*_xRefImp)(_destination, xRefSel, _GSC_CLASS | _GSC_XREF,
                                node->value.nsu);
                    return;
                }
                while (done == NO)
                {
                    int		tmp = class_getVersion(c);
                    unsigned	version = tmp;
                    Class		s = class_getSuperclass(c);
                    
                    if (tmp < 0)
                    {
                        [NSException raise: NSInternalInconsistencyException
                                    format: @"negative class version"];
                    }
                    node = GSIMapAddPair(_clsMap,
                                         (GSIMapKey)(void*)c, (GSIMapVal)(NSUInteger)++_xRefC);
                    /*
                     *	Encode tag and crossref number.
                     */
                    (*_xRefImp)(_destination, xRefSel, _GSC_CLASS, node->value.nsu);
                    /*
                     *	Encode class, and version.
                     */
                    (*_serImp)(_destination, serSel, &c, @encode(Class), nil);
                    (*_serImp)(_destination, serSel, &version, @encode(unsigned), nil);
                    /*
                     *	If we have a super class that has not been encoded,
                     *	we must loop round to encode it here so that its
                     *	version information will be available when objects
                     *	of its subclasses are decoded and call
                     *	[super initWithCoder:ccc]
                     */
                    if (s == c || s == 0
                        || GSIMapNodeForKey(_clsMap, (GSIMapKey)(void*)s) != 0)
                    {
                        done = YES;
                    }
                    else
                    {
                        c = s;
                    }
                }
                /*
                 *	Encode an empty tag to terminate the list of classes.
                 */
                (*_tagImp)(_destination, tagSel, _GSC_NONE);
            }
            return;
            
        case _C_SEL:
            if (*(SEL*)buf == 0)
            {
                /*
                 *	Special case - a null pointer gets an xref of zero
                 */
                (*_tagImp)(_destination, tagSel, _GSC_SEL | _GSC_XREF | _GSC_X_0);
            }
            else
            {
                SEL		s = *(SEL*)buf;
                GSIMapNode	node = GSIMapNodeForKey(_pointerMap, (GSIMapKey)(void*)s);
                
                if (node == 0)
                {
                    node = GSIMapAddPair(_pointerMap,
                                         (GSIMapKey)(void*)s, (GSIMapVal)(NSUInteger)++_xRefP);
                    (*_xRefImp)(_destination, xRefSel, _GSC_SEL, node->value.nsu);
                    /*
                     *	Encode selector.
                     */
                    (*_serImp)(_destination, serSel, buf, @encode(SEL), nil);
                }
                else
                {
                    (*_xRefImp)(_destination, xRefSel, _GSC_SEL|_GSC_XREF,
                                node->value.nsu);
                }
            }
            return;
            
        case _C_CHARPTR:
            if (*(char**)buf == 0)
            {
                /*
                 *	Special case - a null pointer gets an xref of zero
                 */
                (*_tagImp)(_destination, tagSel, _GSC_CHARPTR | _GSC_XREF | _GSC_X_0);
            }
            else
            {
                GSIMapNode	node;
                
                node = GSIMapNodeForKey(_pointerMap, (GSIMapKey)*(char**)buf);
                if (node == 0)
                {
                    node = GSIMapAddPair(_pointerMap,
                                         (GSIMapKey)*(char**)buf, (GSIMapVal)(NSUInteger)++_xRefP);
                    (*_xRefImp)(_destination, xRefSel, _GSC_CHARPTR, node->value.nsu);
                    (*_serImp)(_destination, serSel, buf, type, nil);
                }
                else
                {
                    (*_xRefImp)(_destination, xRefSel, _GSC_CHARPTR|_GSC_XREF,
                                node->value.nsu);
                }
            }
            return;
            
            // 上面的是在是太复杂, 这里比较简单, 就是先存 type ,后存 data
        case _C_CHR:
            (*_tagImp)(_destination, tagSel, _GSC_CHR);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(signed char), nil);
            return;
            
        case _C_UCHR:
            (*_tagImp)(_destination, tagSel, _GSC_UCHR);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(unsigned char), nil);
            return;
            
        case _C_SHT:
            (*_tagImp)(_dst, tagSel, _GSC_SHT | _GSC_S_SHT);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(short), nil);
            return;
            
        case _C_USHT:
            (*_tagImp)(_dst, tagSel, _GSC_USHT | _GSC_S_SHT);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(unsigned short), nil);
            return;
            
        case _C_INT:
            (*_tagImp)(_dst, tagSel, _GSC_INT | _GSC_S_INT);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(int), nil);
            return;
            
        case _C_UINT:
            (*_tagImp)(_dst, tagSel, _GSC_UINT | _GSC_S_INT);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(unsigned int), nil);
            return;
            
        case _C_LNG:
            (*_tagImp)(_dst, tagSel, _GSC_LNG | _GSC_S_LNG);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(long), nil);
            return;
            
        case _C_ULNG:
            (*_tagImp)(_dst, tagSel, _GSC_ULNG | _GSC_S_LNG);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(unsigned long), nil);
            return;
            
        case _C_LNG_LNG:
            (*_tagImp)(_dst, tagSel, _GSC_LNG_LNG | _GSC_S_LNG_LNG);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(long long), nil);
            return;
            
        case _C_ULNG_LNG:
            (*_tagImp)(_dst, tagSel, _GSC_ULNG_LNG | _GSC_S_LNG_LNG);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(unsigned long long), nil);
            return;
            
        case _C_FLT:
            (*_tagImp)(_destination, tagSel, _GSC_FLT);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(float), nil);
            return;
            
        case _C_DBL:
            (*_tagImp)(_destination, tagSel, _GSC_DBL);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(double), nil);
            return;
            
#if __GNUC__ > 2 && defined(_C_BOOL)
        case _C_BOOL:
            (*_tagImp)(_destination, tagSel, _GSC_BOOL);
            (*_serImp)(_destination, serSel, (void*)buf, @encode(_Bool), nil);
            return;
#endif
            
        case _C_VOID:
            [NSException raise: NSInvalidArgumentException
                        format: @"can't encode void item"];
            
        default:
            [NSException raise: NSInvalidArgumentException
                        format: @"item with unknown type - %s", type];
    }
}

// 这就是最初会调用的方法.
- (void) encodeRootObject: (id)rootObject
{
    if (_encodingRoot) // 防卫式处理.
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"encoding root object more than once"];
    }
    
    _encodingRoot = YES;
    
    /*
     *	First pass - find conditional objects.
     */
    _initialPass = YES;
    //    (*_eObjImp)(self, encodeObjectSEL, rootObject); 这里为了效率, 牺牲了太多的可读性, 其实就是调用下面的方法了.
    [self encodeObject:rootObject];
    
    /*
     *	Second pass - write archive.
     */
    _initialPass = NO;
    //    (*_eObjImp)(self, encodeObjectSEL, rootObject);
    [self encodeObject:rootObject];
    // 之所以, 会有两个同样的调用, 是因为 _initialPass 变化了, 导致里面的实现会有不同的走向.
    
    /*
     *	Write sizes of crossref arrays to head of archive.
     */
    [self serializeHeaderAt: _startPos
                    version: [self systemVersion]
                    classes: _clsMap->nodeCount
                    objects: _uIdMap->nodeCount
                   pointers: _ptrMap->nodeCount];
    
    _encodingRoot = NO;
}


- (void) encodeDataObject: (NSData*)anObject
{
    unsigned	l = [anObject length];
    
    (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, @encode(unsigned int), &l);
    if (l)
    {
        const void	*b = [anObject bytes];
        unsigned char	c = 0;			/* Type tag	*/
        
        /*
         * The type tag 'c' is used to specify an encoding scheme for the
         * actual data - at present we have '0' meaning raw data.  In the
         * future we might want zipped data for instance.
         */
        (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, @encode(unsigned char), &c);
        [self encodeArrayOfObjCType: @encode(unsigned char)
                              count: l
                                 at: b];
    }
}

// 向 objectMap 里面添加数据, 向 _conditionIdMap 里面添加数据.
- (void) encodeConditionalObject: (id)anObject
{
    if (_encodingRoot == NO)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"conditionally encoding without root object"];
        return;
    }
    
    if (_initialPass)
    {
        GSIMapNode    node;
        
        /*
         *    If we have already conditionally encoded this object, we can
         *    ignore it this time.
         */
        node = GSIMapNodeForKey(_conditionIdMap, (GSIMapKey)anObject);
        if (node != 0) { return; }
        
        /*
         *    If we have unconditionally encoded this object, we can ignore
         *    it now.
         */
        node = GSIMapNodeForKey(_unconditionIdMap, (GSIMapKey)anObject);
        if (node != 0) { return; }
        GSIMapAddPair(_conditionIdMap, (GSIMapKey)anObject, (GSIMapVal)(NSUInteger)0);
    } else {
        GSIMapNode    node;
        
        if (_objectsMap->nodeCount)
        {
            node = GSIMapNodeForKey(_objectsMap, (GSIMapKey)anObject);
            if (node)
            {
                anObject = (id)node->value.ptr;
            }
        }
        
        node = GSIMapNodeForKey(_conditionIdMap, (GSIMapKey)anObject);
        if (node != 0)
        {
            (*_encodeObjectImp)(self, encodeObjectSEL, nil);
        } else
        {
            (*_encodeObjectImp)(self, encodeObjectSEL, anObject);
        }
    }
}

// 如何 encode 对象的真正实现.
- (void) encodeObject: (id)targetObj
{
    if (targetObj == nil)
    {
        return;
    }
    
    /*
     *    Substitute replacement object if required.
     */
    GSIMapNode    node = GSIMapNodeForKey(_objectsMap, (GSIMapKey)targetObj);
    if (node)
    {
        targetObj = (id)node->value.ptr;
    }
    
    /*
     *    See if the object has already been encoded.
     */
    node = GSIMapNodeForKey(_unconditionIdMap, (GSIMapKey)targetObj);
    
    if (_initialPass) // 代表着还是 encodeRoot 的第一个阶段. 在这个阶段里面, encodeObject 里面的对象, 都是必须 encode 的.
    {
        if (node == 0)
        {
            /*
             *    Remove object from map of conditionally encoded objects
             *    and add it to the map of unconditionay encoded ones.
             */
            GSIMapRemoveKey(_conditionIdMap, (GSIMapKey)targetObj);
            GSIMapAddPair(_unconditionIdMap,
                          (GSIMapKey)targetObj, (GSIMapVal)(NSUInteger)0);
            [targetObj encodeWithCoder: self]; // 这里, 就会调用到各个具体类的方法里面了.
            // 然后, 在那里, 又会转到 encodeObject 中来, 所以这是一个会递归调用给的代码.
        }
        return;
    }
    
    if (node == 0 || node->value.nsu == 0)
    {
        Class    cls;
        id    archiveObj;
        
        if (node == 0)
        {
            node = GSIMapAddPair(_unconditionIdMap,
                                 (GSIMapKey)targetObj, (GSIMapVal)(NSUInteger)++_xRefO);
        }
        else
        {
            node->value.nsu = ++_xRefO;
        }
        
        archiveObj = [targetObj replacementObjectForArchiver: self];
        if (GSObjCIsInstance(archiveObj) == NO)
        {
            /*
             * If the object we have been given is actually a class,
             * we encode it as a special case.
             */
            (*_xRefImp)(_destination, xRefSel, _GSC_CID, node->value.nsu);
            (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, @encode(Class), &archiveObj);
        }
        else
        {
            cls = [archiveObj classForArchiver];
            if (_namesMap->nodeCount)
            {
                GSIMapNode    n;
                
                n = GSIMapNodeForKey(_namesMap, (GSIMapKey)cls);
                
                if (n)
                {
                    cls = (Class)n->value.ptr;
                }
            }
            (*_xRefImp)(_destination, xRefSel, _GSC_ID, node->value.nsu);
            (*_eValImp)(self, encodeValueOfObjCTypeAtSEL, @encode(Class), &cls);
            [archiveObj encodeWithCoder: self];
        }
    }
    else
    {
        (*_xRefImp)(_destination, xRefSel, _GSC_ID | _GSC_XREF, node->value.nsu);
    }
}

/**
 *  Returns whatever data has been encoded thus far.
 */
- (NSMutableData*) archiverData
{
    return _data;
}

/**
 *  Returns substitute class used to encode objects of given class.  This
 *  would have been set through an earlier call to
 *  [NSArchiver -encodeClassName:intoClassName:].
 */
- (NSString*) classNameEncodedForTrueClassName: (NSString*)trueName
{
    if (_namesMap->nodeCount)
    {
        GSIMapNode	node;
        Class		c;
        
        c = objc_lookUpClass([trueName cString]);
        node = GSIMapNodeForKey(_namesMap, (GSIMapKey)c);
        if (node)
        {
            c = (Class)node->value.ptr;
            return [NSString stringWithUTF8String: class_getName(c)];
        }
    }
    return trueName;
}

/**
 *  Specify substitute class used in archiving objects of given class.  This
 *  class is written to the archive as the class to use for restoring the
 *  object, instead of what is returned from [NSObject -classForArchiver].
 *  This can be used to provide backward compatibility across class name
 *  changes.  The object is still encoded by calling
 *  <code>encodeWithCoder:</code> as normal.
 */
- (void) encodeClassName: (NSString*)trueName
           intoClassName: (NSString*)inArchiveName
{
    GSIMapNode	node;
    Class		tc;
    Class		ic;
    
    tc = objc_lookUpClass([trueName cString]);
    if (tc == 0)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Can't find class '%@'.", trueName];
    }
    ic = objc_lookUpClass([inArchiveName cString]);
    if (ic == 0)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"Can't find class '%@'.", inArchiveName];
    }
    node = GSIMapNodeForKey(_namesMap, (GSIMapKey)tc);
    if (node == 0)
    {
        GSIMapAddPair(_namesMap, (GSIMapKey)(void*)tc, (GSIMapVal)(void*)ic);
    }
    else
    {
        node->value.ptr = (void*)ic;
    }
}

/**
 *  Set encoder to write out newObject in place of object.
 */
- (void) replaceObject: (id)object
            withObject: (id)newObject
{
    GSIMapNode	node;
    
    if (object == 0)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"attempt to remap nil"];
    }
    if (newObject == 0)
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"attempt to remap object to nil"];
    }
    node = GSIMapNodeForKey(_objectsMap, (GSIMapKey)object);
    if (node == 0)
    {
        GSIMapAddPair(_objectsMap, (GSIMapKey)object, (GSIMapVal)newObject);
    }
    else
    {
        node->value.ptr = (void*)newObject;
    }
}
@end



/**
 *  Category for compatibility with old GNUstep encoding.
 */
@implementation	NSArchiver (GNUstep)

/**
 // 一些清空操作, 将所有的数据归置到最初状态.
 */
- (void) resetArchiver
{
    if (_clsMap)
    {
        GSIMapCleanMap(_clsMap);
        if (_conditionIdMap)
        {
            GSIMapCleanMap(_conditionIdMap);
        }
        if (_unconditionIdMap)
        {
            GSIMapCleanMap(_unconditionIdMap);
        }
        if (_pointerMap)
        {
            GSIMapCleanMap(_pointerMap);
        }
        if (_namesMap)
        {
            GSIMapCleanMap(_namesMap);
        }
        if (_objectsMap)
        {
            GSIMapCleanMap(_objectsMap);
        }
    }
    _encodingRoot = NO;
    _initialPass = NO;
    _xRefC = 0;
    _xRefO = 0;
    _xRefP = 0;
    
    /*
     *	Write dummy header
     */
    _startPos = [_data length];
    [self serializeHeaderAt: _startPos
                    version: [self systemVersion]
                    classes: 0
                    objects: 0
                   pointers: 0];
}

/**
 *  Returns YES.
 */
- (BOOL) directDataAccess
{
    return YES;
}

/**
 *  Writes out header for GNUstep archive format.
 将一些头部信息写入到 data 中.
 */
- (void) serializeHeaderAt: (unsigned)positionInData
                   version: (unsigned)systemVersion
                   classes: (unsigned)classCount
                   objects: (unsigned)objectCount
                  pointers: (unsigned)pointerCount
{
    unsigned	headerLength = strlen(PREFIX)+36;
    char		header[headerLength+1];
    unsigned	dataLength = [_data length];
    
    snprintf(header,
             sizeof(header),
             "%s%08x:%08x:%08x:%08x:",
             PREFIX,
             systemVersion,
             classCount,
             objectCount,
             pointerCount);
    
    if (positionInData + headerLength <= dataLength)
    {
        [_data replaceBytesInRange: NSMakeRange(positionInData, headerLength)
                         withBytes: header];
    }
    else if (positionInData == dataLength)
    {
        [_data appendBytes: header length: headerLength];
    }
    else
    {
        [NSException raise: NSInternalInconsistencyException
                    format: @"serializeHeader:at: bad location"];
    }
}

@end

