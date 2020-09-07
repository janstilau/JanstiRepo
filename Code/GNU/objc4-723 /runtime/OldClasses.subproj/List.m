#ifndef __OBJC2__

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <objc/List.h>

#define DATASIZE(count) ((count) * sizeof(id))

@implementation  List

+ (id)initialize
{
    [self setVersion: 1];
    return self;
}

- (id)initCount:(unsigned)numSlots
{
    maxElements = numSlots;
    if (maxElements)
        dataPtr = (id *)malloc(DATASIZE(maxElements));
    return self;
}

+ (id)newCount:(unsigned)numSlots
{
    return [[self alloc] initCount:numSlots];
}

+ (id)new
{
    return [self newCount:0];
}

- (id)init
{
    return [self initCount:0];
}

- (id)free
{
    free(dataPtr);
    return [super free];
}

- (id)freeObjects
{
    id element;
    while ((element = [self removeLastObject]))
        [element free];
    return self;
}

- (id)copyFromZone:(void *)z
{
    List	*new = [[[self class] alloc] initCount: numElements];
    new->numElements = numElements;
    bcopy ((const char*)dataPtr, (char*)new->dataPtr, DATASIZE(numElements));
    return new;
}

- (BOOL) isEqual: anObject
{
    List	*other;
    if (! [anObject isKindOf: [self class]]) return NO;
    other = (List *) anObject;
    return (numElements == other->numElements)
    && (bcmp ((const char*)dataPtr, (const char*)other->dataPtr, DATASIZE(numElements)) == 0);
}

- (unsigned)capacity
{
    return maxElements;
}

- (unsigned)count
{
    return numElements;
}

- (id)objectAt:(unsigned)index
{
    if (index >= numElements)
        return nil;
    return dataPtr[index];
}

- (unsigned)indexOf:anObject
{
    register id *this = dataPtr;
    register id *last = this + numElements;
    while (this < last) {
        if (*this == anObject)
            return this - dataPtr;
        this++;
    }
    return NX_NOT_IN_LIST;
}

- (id)lastObject
{
    if (! numElements)
        return nil;
    return dataPtr[numElements - 1];
}

- (id)setAvailableCapacity:(unsigned)numSlots
{
    volatile id *tempDataPtr;
    if (numSlots < numElements) return nil;
    tempDataPtr = (id *) realloc (dataPtr, DATASIZE(numSlots));
    dataPtr = (id *)tempDataPtr;
    maxElements = numSlots;
    return self;
}

- (id)insertObject:anObject at:(unsigned)index
{
    register id *this, *last, *prev;
    if (! anObject) return nil;
    if (index > numElements)
        return nil;
    if ((numElements + 1) > maxElements) {
        volatile id *tempDataPtr;
        /* we double the capacity, also a good size for malloc */
        maxElements += maxElements + 1;
        tempDataPtr = (id *) realloc (dataPtr, DATASIZE(maxElements));
        dataPtr = (id*)tempDataPtr;
    }
    this = dataPtr + numElements;
    prev = this - 1;
    last = dataPtr + index;
    while (this > last)
        *this-- = *prev--;
    *last = anObject;
    numElements++;
    return self;
}

- (id)addObject:anObject
{
    return [self insertObject:anObject at:numElements];
    
}


- (id)addObjectIfAbsent:anObject
{
    register id *this, *last;
    if (! anObject) return nil;
    this = dataPtr;
    last = dataPtr + numElements;
    while (this < last) {
        if (*this == anObject)
            return self;
        this++;
    }
    return [self insertObject:anObject at:numElements];
    
}


- (id)removeObjectAt:(unsigned)index
{
    register id *this, *last, *next;
    id retval;
    if (index >= numElements)
        return nil;
    this = dataPtr + index;
    last = dataPtr + numElements;
    next = this + 1;
    retval = *this;
    while (next < last)
        *this++ = *next++;
    numElements--;
    return retval;
}

- (id)removeObject:anObject
{
    register id *this, *last;
    this = dataPtr;
    last = dataPtr + numElements;
    while (this < last) {
        if (*this == anObject)
            return [self removeObjectAt:this - dataPtr];
        this++;
    }
    return nil;
}

- (id)removeLastObject
{
    if (! numElements)
        return nil;
    return [self removeObjectAt: numElements - 1];
}

- (id)empty
{
    numElements = 0;
    return self;
}

- (id)replaceObject:anObject with:newObject
{
    register id *this, *last;
    if (! newObject)
        return nil;
    this = dataPtr;
    last = dataPtr + numElements;
    while (this < last) {
        if (*this == anObject) {
            *this = newObject;
            return anObject;
        }
        this++;
    }
    return nil;
}

- (id)replaceObjectAt:(unsigned)index with:newObject
{
    register id *this;
    id retval;
    if (! newObject)
        return nil;
    if (index >= numElements)
        return nil;
    this = dataPtr + index;
    retval = *this;
    *this = newObject;
    return retval;
}

- (id)makeObjectsPerform:(SEL)aSelector
{
    unsigned	count = numElements;
    while (count--)
        [dataPtr[count] perform: aSelector];
    return self;
}

- (id)makeObjectsPerform:(SEL)aSelector with:anObject
{
    unsigned	count = numElements;
    while (count--)
        [dataPtr[count] perform: aSelector with: anObject];
    return self;
}

-(id)appendList: (List *)otherList
{
    unsigned i, count;
    
    for (i = 0, count = [otherList count]; i < count; i++)
        [self addObject: [otherList objectAt: i]];
    return self;
}

@end

#endif
