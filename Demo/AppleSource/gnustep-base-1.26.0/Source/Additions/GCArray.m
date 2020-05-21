/* Implementation of garbage collecting array classes.
 
 Copyright (C) 2002 Free Software Foundation, Inc.
 
 Written by:  Richard Frith-Macdonald <rfm@gnu.org>
 Inspired by gc classes of  Ovidiu Predescu and Mircea Oancea
 
 This file is part of the GNUstep Base Library.
 
 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2 of the License, or (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Library General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free
 Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 Boston, MA 02111 USA.
 
 */

#import "common.h"
#ifndef NeXT_Foundation_LIBRARY
#import "Foundation/NSException.h"
#import "Foundation/NSRange.h"
#endif

#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/GCObject.h"

@implementation GCArray

static Class	gcClass = 0;

+ (void) initialize
{
    if (gcClass == 0)
    {
        gcClass = [GCObject class];
        GSObjCAddClassBehavior(self, gcClass);
    }
}

- (Class) classForCoder
{
    return [GCArray class];
}

// 拷贝.
- (id) copyWithZone: (NSZone*)zone
{
    GCArray *result;
    id *objects;
    NSUInteger i, c = [self count];
    
    if (NSShouldRetainWithZone(self, zone))
    {
        return [self retain];
    }
    
    objects = NSZoneMalloc(zone, c * sizeof(id));
    /* FIXME: Check if malloc return 0 */
    [self getObjects: objects]; // get 是将数据存放到一个预先开辟的空间, 这符合 apple 的一贯的风格.
    for (i = 0; i < c; i++)
    {
        objects[i] = [objects[i] copy];
    }
    result = [[GCArray allocWithZone: zone] initWithObjects: objects count: c];
    NSZoneFree(zone, objects);
    
    return result;
}

- (NSUInteger) count
{
    return _count;
}

- (void) dealloc
{
    NSUInteger	c = _count;
    
    while (c-- > 0)
    {
        DESTROY(_contents[c]); // 对于每一个持有的类进行 release 操作.
    }
    
    NSZoneFree([self zone], _contents);
    [super dealloc];
}

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
    _contents = NSZoneMalloc([self zone], count * (sizeof(id) + sizeof(BOOL)));
    _isGCObject = (BOOL*)&_contents[count];
    _count = 0;
    while (_count < count)
    {
        _contents[_count] = RETAIN(objects[_count]);
        if (_contents[_count] == nil) // 在这里, 是这个类库内部显示的抛出了异常. 所以, 很多的异常不是语言的内置, 而是语言的设置者做的安全性的限制.
        {
            DESTROY(self);
            [NSException raise: NSInvalidArgumentException
                        format: @"Nil object to be added in array"];
        } else
        {
            _isGCObject[_count] = [objects[_count] isKindOfClass: gcClass];// 这里是为 GarbageCollect 的一些配置.
        }
        _count++;
    }
    return self;
}

- (id) initWithArray: (NSArray*)anotherArray
{
    NSUInteger	count = [anotherArray count];
    
    _contents = NSZoneMalloc([self zone], count * (sizeof(id) + sizeof(BOOL)));
    _isGCObject = (BOOL*)&_contents[count];
    _count = 0;
    while (_count < count)
    {
        _contents[_count] = RETAIN([anotherArray objectAtIndex: _count]);
        _isGCObject[_count] = [_contents[_count] isKindOfClass: gcClass];
        _count++;
    }
    return self;
}

/**
 * We use the same initial instance variable layout as a GCObject and
 * ue the <em>behavior</em> mechanism to inherit methods from that class
 * to implement a form of multiple inheritance.  We need to implement
 * this method to make this apparent at runtime.
 */
- (BOOL) isKindOfClass: (Class)c
{
    if (c == gcClass)
    {
        return YES;
    }
    return [super isKindOfClass: c];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
    return [[GCMutableArray allocWithZone: zone] initWithArray: self];
}

- (id) objectAtIndex: (NSUInteger)index
{
    if (index >= _count) // 一个简单的安全性的检测, 实际上还是直接通过读取数组的值.
    {
        [NSException raise: NSRangeException
                    format: @"[%@-%@]: index: %"PRIuPTR,
         NSStringFromClass([self class]), NSStringFromSelector(_cmd), index];
    }
    return _contents[index];
}

@end



@implementation GCMutableArray

+ (void)initialize
{
    static BOOL beenHere = NO;
    
    if (beenHere == NO)
    {
        beenHere = YES;
        GSObjCAddClassBehavior(self, [GCArray class]);
    }
}

- (void) addObject: (id)anObject
{
    [self insertObject: anObject atIndex: _count];
}

- (Class) classForCoder
{
    return [GCMutableArray class];
}

- (id) copyWithZone: (NSZone*)zone
{
    GCArray *result;
    id *objects;
    NSUInteger i, c = [self count];
    
    objects = NSZoneMalloc(zone, c * sizeof(id));
    /* FIXME: Check if malloc return 0 */
    [self getObjects: objects];
    for (i = 0; i < c; i++)
    {
        objects[i] = [objects[i] copy];
    }
    result = [[GCArray allocWithZone: zone] initWithObjects: objects count: c];
    NSZoneFree(zone, objects);
    
    return result;
}

- (id) init
{
    return [self initWithCapacity: 1];
}

- (id) initWithArray: (NSArray*)anotherArray
{
    NSUInteger	count = [anotherArray count];
    
    self = [self initWithCapacity: count];
    if (self != nil)
    {
        while (_count < count)
        {
            _contents[_count] = RETAIN([anotherArray objectAtIndex: _count]);
            _isGCObject[_count] = [_contents[_count] isKindOfClass: gcClass];
            _count++;
        }
    }
    return self;
}

- (id) initWithCapacity: (NSUInteger)aNumItems
{
    if (aNumItems < 1)
    {
        aNumItems = 1;
    } // 防卫式语句.
    _contents = NSZoneMalloc([self zone],
                             aNumItems * (sizeof(id) + sizeof(BOOL))); // 这里表现的很明白, capacity 的作用就是提前分配所需的空间的大小.
    _isGCObject = (BOOL*)&_contents[aNumItems];
    _maxCount = aNumItems;
    _count = 0;
    return self;
}

- (id) initWithObjects: (const id [])objects count: (NSUInteger)count
{
    self = [self initWithCapacity: count];
    if (self != nil)
    {
        while (_count < count)
        {
            _contents[_count] = RETAIN(objects[_count]);
            if (_contents[_count] == nil)
            {
                DESTROY(self);
                [NSException raise: NSInvalidArgumentException
                            format: @"Nil object to be added in array"];
            }
            else
            {
                _isGCObject[_count] = [objects[_count] isKindOfClass: gcClass];
            }
            _count++;
        }
    }
    return self;
}

- (void) insertObject: (id)anObject atIndex: (NSUInteger)index
{
    NSUInteger i;
    
    // 首先是两个防卫语句, 这样, 类库的作者, 首先想到的是安全.
    if (anObject == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: nil argument",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (index > _count)
    {
        [NSException raise: NSRangeException
                    format: @"[%@-%@]: bad index %"PRIuPTR,
         NSStringFromClass([self class]), NSStringFromSelector(_cmd), index];
    }
    
    if (_count == _maxCount) // 扩容的处理, 简单的把原来的值进行一次拷贝操作.
    {
        NSUInteger	old = _maxCount;
        BOOL	*optr;
        
        if (_maxCount > 0)
        {
            _maxCount += (_maxCount >> 1) ? (_maxCount >> 1) : 1; // 按照原有容量除以 2 进行的扩展.
        }
        else
        {
            _maxCount = 1;
        }
        _contents = (id*)NSZoneRealloc([self zone], _contents,
                                       _maxCount * (sizeof(id) + sizeof(BOOL)));
        optr = (BOOL*)&_contents[old];
        _isGCObject = (BOOL*)&_contents[_maxCount];
        memmove(_isGCObject, optr, sizeof(BOOL)*old);
    }
    for (i = _count; i > index; i--)
    {
        _contents[i] = _contents[i - 1];
        _isGCObject[i] = _isGCObject[i - 1];
    }
    _contents[index] = RETAIN(anObject);
    _isGCObject[index] = [anObject isKindOfClass: gcClass];
    _count++;
}

// 所以, 并没有什么可变对象, 仅仅是生成一个可变类, 这个可变类提供了可变的接口而已.
- (id) mutableCopyWithZone: (NSZone*)zone
{
    return [[GCMutableArray allocWithZone: zone] initWithArray: self];
}

- (void) removeAllObjects
{
    [self removeObjectsInRange: NSMakeRange(0, _count)];
}

- (void) removeObjectAtIndex: (NSUInteger)index
{
    [self removeObjectsInRange: NSMakeRange(index, 1)];
}

- (void) removeObjectsInRange: (NSRange)range
{
    NSUInteger	i;
    
    if (NSMaxRange(range) > _count)
    {
        [NSException raise: NSRangeException
                    format: @"[%@-%@]: bad range %@",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd),
         NSStringFromRange(range)];
    }
    if (range.length == 0)
    {
        return;
    }
    // 先对原有的每个数据进行 release 操作, 然后是后面的数据的搬移操作.
    for (i = range.location; i < NSMaxRange(range); i++)
    {
        RELEASE(_contents[i]);
    }
    for (i = NSMaxRange(range); i < _count; i++, range.location++)
    {
        _contents[range.location] = _contents[i];
        _isGCObject[range.location] = _isGCObject[i];
    }
    _count -= range.length;
}

- (void) replaceObjectAtIndex: (NSUInteger)index  withObject: (id)anObject
{
    // 先是防卫式语句.
    if (anObject == nil)
    {
        [NSException raise: NSInvalidArgumentException
                    format: @"[%@-%@]: nil argument",
         NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
    if (index >= _count)
    {
        [NSException raise: NSRangeException
                    format: @"[%@-%@]: bad index %"PRIuPTR,
         NSStringFromClass([self class]), NSStringFromSelector(_cmd), index];
    }
    // ASSIGN 会对原有的数据进行 release, 新的数据进行 retains
    ASSIGN(_contents[index], anObject); 
    _isGCObject[index] = [anObject isKindOfClass: gcClass];
}

@end

