/** Implementation of NSCopyObject() for GNUStep
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: August 1994

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02110 USA.

   <title>NSCopyObject class reference</title>
   $Date$ $Revision$
   */

#import "common.h"

NSObject *NSCopyObject(NSObject *anObject, NSUInteger extraBytes, NSZone *zone)
{
  Class	c = object_getClass(anObject);
  id copy = NSAllocateObject(c, extraBytes, zone);

/*
 所以, 就是直接进行的 bit 位的拷贝的工作.
 Copies count bytes from the object pointed to by src to the object pointed to by dest. Both objects are reinterpreted as arrays of unsigned char.
 If the objects overlap, the behavior is undefined.
 If either dest or src is an invalid or null pointer, the behavior is undefined, even if count is zero.
 If the objects are potentially-overlapping or not TriviallyCopy
 able, the behavior of memcpy is not specified and may be undefined.
 void* memcpy( void* dest, const void* src, std::size_t count );
 */
  memcpy(copy, anObject, class_getInstanceSize(c) + extraBytes);
  return copy;
}
