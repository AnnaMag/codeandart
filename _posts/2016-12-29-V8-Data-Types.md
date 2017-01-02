---
layout: single
title:  "V8 Data Types"
date:   2016-12-29 13:30:00
categories: Outreachy
summary: V8 Data Types
tags:
- JavaScript
- V8
- Variables 
---

This is a short post about a few key internals of V8 and the way that the
JavaScript variables are handled in the C++ code.

*Isolate* and *Context* are important key concepts in V8.
V8 has its own memory management and data type facilities. When JavaScript creates
a variable, a space for it is created on the V8 heap and it is managed by the V8 garbage collector. An *Isolate* is an independent instance of V8, encapsulating memory management/garbage collection and execution context. Node.js creates a single
Isolate imposing a single-threaded rule (at a given time only a single thread
is allowed access).
A *Context* is a global object within an Isolate heap [http://bespin.cz/~ondras/html/classv8_1_1Context.html].
In order to run a JavaScript code we need a global object (with its "usual"
global properties, functions and EMCAScript Objects attached to it) and a global scope. The global scope in Node.js has functions like *module, exports, require*,
amongst [others][https://nodejs.org/api/globals.html].

There can be multiple contexts running within a given Isolate, each with its
independent set of globals. Implicitly, as mentioned above, there is a single context running in Node.js, but a number of those can be compiled via the *vm* object.
Isolate and Context that are put to use whenever we read,
write or allocate to memory in the Javascript code via the V8 API. All action
takes place within the Node.js's event loop.

Therefor, it is V8 that handles objects and functions, their lifetime, placement in memory and manages changes in states. When refactoring Node.js code for the changes in the V8 API, I found it to be helpful to have direct access to the Object properties from within the Node.js code. However, as all is governed in a V8-like fashion, the references to values are governed by the so-called *Handles*.

Handle is used as "an object reference managed by the V8 garbage collector",
to be tracked and updated as they are moved or deleted (created within the
*HandleScope* container and destroyed when it is removed).
Objects returned from within v8 are returned most often in local [handles][https://github.com/nodejs/node-v0.x-archive/blob/05e6f318c6ecccea73698367010e51812c5b3862/deps/v8/include/v8.h#L144]. More formally,  [Local][https://github.com/nodejs/node-v0.x-archive/blob/05e6f318c6ecccea73698367010e51812c5b3862/deps/v8/include/v8.h#L257] handles `are light-weight, stack-allocated, object handle,
which are transient and typically used in local operations.`
More in-depth information can be found in the official [V8 Embedder Guide][https://github.com/v8/v8/wiki/Embedder's%20Guide].

With a little bit of practice, objects can be wrapped and un-wrapped fairly easily.
In order to be able to list the values, we have to extract the object stored
in the handle by dereferencing the handle. e.g. to extract the Object* from
a Local<Object>. The value will still be governed by a handle behind
the scenes and follows the same rules.

For instance, having created or references an isolate, one can create a [V8::String object][http://bespin.cz/~ondras/html/classv8_1_1String.html#aa4b8c052f5108ca6350c45922602b9d4]
we can use the corresponding API call:
```
v8::Local<v8::String> stdString = v8::String::NewFromUtf8(isolate,"foo");

```
JavaScript and C++ have distinct type systems. V8 uses an inheritance [hierarchy]
[http://bespin.cz/~ondras/html/hierarchy.html].
The standard JavaScript primitives (Strings, Numbers,Booleans) are included in the
V8 Primitive and its subclasses, extending the [Value class][https://v8docs.nodesource.com/io.js-3.0/dc/d0a/classv8_1_1_value.html].
This hints to the existence of the *Cast* function in V8, which allows
to cast objects onto each other within a given hierarchy
(e.g. handy to use as an input to another function or access a specific method
  from another class).

For the purpose of accessing the values of Object properties,
I created helper functions,  which allow me to list the *un-wrap*
properties directly in C++ code:
https://gist.github.com/AnnaMag/92b4d5ab5fbf1f3229534e4262843091

The above code snippet has a lower-level *PrintLocalString* function, which prints
char to a string buffer; and a *PrintLocalArray* function, which uses the former to iterate over the elements in the array and, for example, print them to the screen.
*Local<Object>* or *Local<Value>* can be casted onto *Local<Array>*, and calling
one of the  helper functions gives access to the value internals.

Note: in order to include additional files to be compiled with the Node.js code,
one has to include them in the node-gyp (both .cpp and .h). Standard compilation
is done with `make -j4` (over 4 cores in this case), which creates the *node*
executable.
