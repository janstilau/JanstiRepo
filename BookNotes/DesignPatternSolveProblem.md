# How Design Patterns Solve Design Problems

## Finding Appropriate Objects

* The hard part about object-oriented design is decomposing a system into objects.
* But object-oriented designs often end up with classes that have no counterparts in the real world.
* Design patterns help you identify less-obvious abstractions and the objects that can capture them.

## Determining Object Granularity

## Specifying Object Interfaces

* An object's interface characterizes the complete set of requests that can be sent to the object.
* A type is a name used to denote a particular interface.
* An object may have many types, and widely different objects can share a type.
* Interfaces are fundamental in object-oriented systems. Objects are known only through their interfaces.
* An object's interface says nothing about its implementation.
* When a request is sent to an object, the particular operation that's performed depends on both the request and the receiving object
* Dynamic binding means that issuing a request doesn't commit you to a particular implementation until run-time. Consequently, you can write programs that expect an object with a particular interface, knowing that any object that has the correct interface will accept the request. Moreover, dynamic binding lets you substitute objects that have identical interfaces for each other at run-time. This substitutability is known as polymorphism, and it's a key concept in object-oriented systems. It lets a client object make few assumptions about other objects beyond supporting a particular interface. Polymorphism simplifies the definitions of clients, decouples objects from each other, and lets them vary their relationships to each other at run-time.
* 