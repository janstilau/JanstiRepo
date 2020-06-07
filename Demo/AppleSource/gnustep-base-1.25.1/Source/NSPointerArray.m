#import "common.h"
#import	"Foundation/NSPointerArray.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSKeyedArchiver.h"
#import "GSPrivate.h"
#import "NSConcretePointerFunctions.h"


static Class	abstractClass = Nil;
static Class	concreteClass = Nil;

@interface	NSConcretePointerArray : NSPointerArray
{
    PFInfo	_pf;
    NSUInteger	_count;
    void		**_contents;
    unsigned	_capacity;
    unsigned	_grow_factor;
}
@end


@implementation NSPointerArray


+ (id) pointerArrayWithOptions: (NSPointerFunctionsOptions)options
{
    return AUTORELEASE([[self alloc] initWithOptions: options]);
}

+ (id) pointerArrayWithPointerFunctions: (NSPointerFunctions *)functions
{
    return AUTORELEASE([[self alloc] initWithPointerFunctions: functions]);
}
+ (id) strongObjectsPointerArray
{
    return [self pointerArrayWithOptions: NSPointerFunctionsObjectPersonality |
            NSPointerFunctionsStrongMemory];
}
+ (id) weakObjectsPointerArray
{
    return [self pointerArrayWithOptions: NSPointerFunctionsObjectPersonality |
            NSPointerFunctionsWeakMemory];
}

- (int) count
{
    
    return _count;
}

- (id) init
{
    return [self initWithOptions: 0];
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
    NSPointerFunctions	*functions;
    
    functions = [NSPointerFunctions pointerFunctionsWithOptions: options];
    return [self initWithPointerFunctions: functions];
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (BOOL) isEqual: (id)other
{
    NSUInteger	count;
    
    if (other == self)
    {
        return YES;
    }
    if ([other isKindOfClass: abstractClass] == NO)
    {
        return NO;
    }
    if ([other hash] != [self hash])
    {
        return NO;
    }
    count = [self count];
    while (count-- > 0)
    {
        // FIXME
    }
    return YES;
}

- (void) addPointer: (void*)pointer
{
    [self insertPointer: pointer atIndex: [self count]];
}

- (void) insertPointer: (void*)pointer atIndex: (int)index
{
    [self subclassResponsibility: _cmd];
}

- (void*) pointerAtIndex: (int)index
{
    [self subclassResponsibility: _cmd];
    return 0;
}

- (NSPointerFunctions*) pointerFunctions
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (void) removePointerAtIndex: (int)index
{
    [self subclassResponsibility: _cmd];
}

- (void) replacePointerAtIndex: (int)index withPointer: (void*)item
{
    [self subclassResponsibility: _cmd];
}

- (void) setCount: (int)count
{
    [self subclassResponsibility: _cmd];
}

@end

@implementation NSPointerArray (NSArrayConveniences)  

+ (id) pointerArrayWithStrongObjects
{
    return [self pointerArrayWithOptions: NSPointerFunctionsStrongMemory];
}

+ (id) pointerArrayWithWeakObjects
{
    return [self pointerArrayWithOptions: NSPointerFunctionsZeroingWeakMemory];
}

- (NSArray*) allObjects
{
    [self subclassResponsibility: _cmd];
    return nil;
}

@end

@implementation NSConcretePointerArray

- (void) _raiseRangeExceptionWithIndex: (int)index from: (SEL)sel
{
    NSDictionary *info;
    NSException  *exception;
    NSString     *reason;
    
    info = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithUnsignedInteger: index], @"Index",
            [NSNumber numberWithUnsignedInteger: _count], @"Count",
            self, @"Array", nil, nil];
    
    reason = [NSString stringWithFormat:
              @"Index %"PRIuPTR" is out of range %"PRIuPTR" (in '%@')",
              index, _count, NSStringFromSelector(sel)];
    
    exception = [NSException exceptionWithName: NSRangeException
                                        reason: reason
                                      userInfo: info];
    [exception raise];
}

- (NSArray*) allObjects
{
    NSUInteger	i;
    NSUInteger	c = 0;
    
    for (i = 0; i < _count; i++)
    {
        if (pointerFunctionsRead(&_pf, &_contents[i]) != 0)
        {
            c++;
        }
    }
    
    if (0 == c)
    {
        return [NSArray array];
    }
    else
    {
        GSMutableArray	*a = [GSMutableArray arrayWithCapacity: c];
        
        for (i = 0; i < _count; i++)
        {
            id obj = pointerFunctionsRead(&_pf, &_contents[i]);
            if (obj != 0)
            {
                [a addObject: obj];
            }
        }
        return GS_IMMUTABLE(a);
    }
}

- (void) compact
{
    NSUInteger	insert = 0;
    NSUInteger	i;
    // We can't use memmove here for __weak pointers, because that would omit the
    // required read barriers.  We could use objc_memmoveCollectable() for strong
    // pointers, but we may as well use the same code path for everything
    for (i=0 ; i<_count ; i++)
    {
        id obj = pointerFunctionsRead(&_pf, &_contents[i]);
        // If this object is not nil, but at least one before it has been, then
        // move it back to the correct location.
        if (nil != obj && i != insert)
        {
            pointerFunctionsAssign(&_pf, &_contents[insert++], obj);
        }
    }
    _count = insert;
}

- (int) count
{
    return _count;
}

- (int) hash
{
    return _count;
}

- (id) initWithOptions: (NSPointerFunctionsOptions)options
{
    NSConcretePointerFunctions	*f;
    
    f = [[NSConcretePointerFunctions alloc] initWithOptions: options];
    self = [self initWithPointerFunctions: f];
    [f release];
    return self;
}

- (id) initWithPointerFunctions: (NSPointerFunctions*)functions
{
    if (![functions isKindOfClass: [NSConcretePointerFunctions class]])
    {
        static NSConcretePointerFunctions	*defaultFunctions = nil;
        
        if (defaultFunctions == nil)
        {
            defaultFunctions
            = [[NSConcretePointerFunctions alloc] initWithOptions: 0];
        }
        functions = defaultFunctions;
    }
    memcpy(&_pf, &((NSConcretePointerFunctions*)functions)->_x, sizeof(_pf));
    return self;
}

- (void) insertPointer: (void*)pointer atIndex: (int)index
{
    NSUInteger	i;
    
    
    if (index > _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    i = _count;
    [self setCount: _count + 1];
    while (i > index)
    {
        pointerFunctionsMove(&_pf, _contents+i, _contents + i-1);
        i--;
    }
    pointerFunctionsAcquire(&_pf, &_contents[index], pointer);
}

- (BOOL) isEqual: (id)other
{
    NSUInteger	count;
    
    if (other == self)
    {
        return YES;
    }
    if ([other isKindOfClass: abstractClass] == NO)
    {
        return NO;
    }
    if ([other hash] != [self hash])
    {
        return NO;
    }
    count = [self count];
    while (count-- > 0)
    {
        if (pointerFunctionsEqual(&_pf,
                                  pointerFunctionsRead(&_pf, &_contents[count]),
                                  [other pointerAtIndex: count]) == NO)
            return NO;
    }
    return YES;
}

- (void*) pointerAtIndex: (int)index
{
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    return pointerFunctionsRead(&_pf, &_contents[index]);
}

- (NSPointerFunctions*) pointerFunctions
{
    NSConcretePointerFunctions	*pf = [NSConcretePointerFunctions new];
    
    pf->_x = _pf;
    return [pf autorelease];
}

- (void) removePointerAtIndex: (int)index
{
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    pointerFunctionsRelinquish(&_pf, &_contents[index]);
    while (++index < _count)
    {
        pointerFunctionsMove(&_pf, &_contents[index-1], &_contents[index]);
    }
    [self setCount: _count - 1];
}

- (void) replacePointerAtIndex: (int)index withPointer: (void*)item
{
    if (index >= _count)
    {
        [self _raiseRangeExceptionWithIndex: index from: _cmd];
    }
    pointerFunctionsReplace(&_pf, &_contents[index], item);
}

- (void) setCount: (int)count
{
    if (count > _count)
    {
        _count = count;
        if (_count >= _capacity)
        {
            void		**ptr;
            size_t	size;
            size_t	new_cap = _capacity;
            size_t	new_gf = _grow_factor ? _grow_factor : 2;
            
            while (new_cap + new_gf < _count)
            {
                new_cap += new_gf;
                new_gf = new_cap/2;
            }
            size = (new_cap + new_gf)*sizeof(void*);
            new_cap += new_gf;
            new_gf = new_cap / 2;
            if (_contents == 0)
            {
                if (_pf.options & NSPointerFunctionsZeroingWeakMemory)
                {
                    ptr = (void**)NSAllocateCollectable(size, 0);
                }
                else
                {
                    ptr = (void**)NSAllocateCollectable(size, NSScannedOption);
                }
            }
            else
            {
                if (_pf.options & NSPointerFunctionsZeroingWeakMemory)
                {
                    ptr = (void**)NSReallocateCollectable(
                                                          _contents, size, 0);
                }
                else
                {
                    ptr = (void**)NSReallocateCollectable(
                                                          _contents, size, NSScannedOption);
                }
            }
            if (ptr == 0)
            {
                [NSException raise: NSMallocException
                            format: @"Unable to grow array"];
            }
            memset(ptr + _capacity, '\0',
                   (new_cap - _capacity) * sizeof(void*));
            _contents = ptr;
            _capacity = new_cap;
            _grow_factor = new_gf;
        }
    }
    else
    {
        while (count < _count)
        {
            _count--;
            pointerFunctionsRelinquish(&_pf, &_contents[_count]);
        }
    }
}

@end

