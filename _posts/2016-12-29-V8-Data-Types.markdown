---
layout: single
title:  "V8 Data Types"
date:   2016-12-29 13:30:00
categories: Outreachy
summary: V8 Data Types
tags:
- JavaScript
- V8
- Data types
---

This is a short post about a few key internals of V8 and the way that the
JavaScript variables are handled in the C++ code. 


*Isolate* and *Context* are important key concepts in V8.
V8 has its own memory management and data type facilities. When JavaScript creates
a variable, a space for it is created on the V8 heap and it is managed by the V8 garbage collector. An *Isolate* is an independent instance of V8, encapsulating memory management/garbage collection and execution context. Node.js creates a single
Isolate imposing a single-threaded rule (at a given time only a single thread
is allowed access).
A [Context](http://bespin.cz/~ondras/html/classv8_1_1Context.html) is a global object within an Isolate heap.
In order to run a JavaScript code we need a global object (with its "usual"
global properties, functions and EMCAScript Objects attached to it) and a global scope. The global scope in Node.js has functions like *module, exports, require*,
amongst [others](https://nodejs.org/api/globals.html).

There can be multiple contexts running within a given Isolate, each with its
independent set of globals. Implicitly, as mentioned above, there is a single context running in Node.js, but a number of those can be compiled via the *vm* object,
if required.
Isolate and Context are put to use whenever we read,
write or allocate to memory in the Javascript code via the V8 API. All action
takes place within the Node.js's event loop.

Therefore, it is V8 that handles objects and functions, their lifetime, placement in memory, tracks and manages their states. The project I'm working is concerned with porting ES6 Object definitions into Node.js. As I was refactoring the code, I found
that having direct access to the values of Object properties from within the Node.js'
code would give me a better picture of how properties were copied onto the V8 sandbox object (more on that in the next post). However, as variables are managed in the V8-like fashion, the references to values are governed by the so-called *Handles*.

[Handle](https://github.com/nodejs/node-v0.x-archive/blob/05e6f318c6ecccea73698367010e51812c5b3862/deps/v8/include/v8.h#L144) is `an object reference managed by the V8 garbage collector`,
to be tracked and updated as they are moved or deleted (created within the
*HandleScope* container and destroyed when it is removed).
Objects returned from within the V8 come most often wrapped in Local handles. More formally,  [Local](https://github.com/nodejs/node-v0.x-archive/blob/05e6f318c6ecccea73698367010e51812c5b3862/deps/v8/include/v8.h#L257) handles `are light-weight, stack-allocated, object handle,
which are transient and typically used in local operations`
(see the [V8 Embedder Guide](https://github.com/v8/v8/wiki/Embedder's%20Guide)
for an in-depth info).

With a little bit of practice, objects can be wrapped and un-wrapped fairly easily.
In order to be able to list the values, we have to extract the object stored
in the handle by dereferencing the handle e.g. to extract the `Object *` from
a `Local< Object >`. The value will still be governed by a handle behind
the scenes and follows the same rules.

For instance, having instantiated or referenced an isolate, one can create a [V8::String object](http://bespin.cz/~ondras/html/classv8_1_1String.html#aa4b8c052f5108ca6350c45922602b9d4)
with the following API call:

```
v8::Local<v8::String> stdString = v8::String::NewFromUtf8(isolate,"foo");
```

It comes as no surprise that JavaScript and C++ have distinct type systems...
V8 uses an inheritance [hierarchy](http://bespin.cz/~ondras/html/hierarchy.html).
The standard JavaScript primitives (Strings, Numbers,Booleans) are included in the
V8 Primitive and its subclasses, extending the [Value class](https://v8docs.nodesource.com/io.js-3.0/dc/d0a/classv8_1_1_value.html).
This hints to the existence of a `Cast` function in V8, which allows
to cast objects onto each other within a given hierarchy. This comes in handy,
for instance, when preparing a specific type of input to another function call or to be able access a specific method from another class.

For the purpose of accessing the values of Object properties,
I created helper functions which list out the un-wrapped
properties directly in the C++ code ([here](https://gist.github.com/AnnaMag/92b4d5ab5fbf1f3229534e4262843091)).
This code snippet consists of a lower-level `PrintLocalString` function, which prints
char to a string buffer; and a `PrintLocalArray` function, which uses the former to iterate over the elements in the array and prints them to the screen.
`Local < Object>` or `Local< Value>` can be casted onto `Local< Array >`, and calling
one of the  helper functions gives access to the value internals.
Understanding how data types and created and managed, allows for writing custom
code to access values of any type.

As the V8 API undergoes an ongoing and rapid revamp, many of the API calls become
deprecated in favor of the `Maybe< >` encapsulate. `Maybe` is a [Haskell](https://hackage.haskell.org/package/base-4.9.0.0/docs/Data-Maybe.html)-like type
(monad, to be precise) and provides a way to check whether the output is non-empty
(returning a `Just` data type).
Empty output (`Nothing`) provides an elegant way of dealing with exceptions. V8 provides `ToJust()/FromJust()/ToLocalChecked()`
calls to wrap and unwrap the Maybe handle, depending on the direction of change
and the type of Object.

As a short example, the code below depicts some of the concepts. `GetOwnPropertyDescriptor(context,key)` returns a MaybeLocal
Value, which we dereference using `ToLocalChecked()`. Next, we cast `Local< Value >`
 to `Local< Object >` to access its `Get(context, key)` method and cast it back
 to the `Local< Value >`
(as needed for subsequent step).

```
Local<Value> descVal = global->GetOwnPropertyDescriptor(context,key)
      .ToLocalChecked();

Local<Object> descObj = Local<Object>::Cast(descLoc);

Local<Value> descVal = Local<Value>::Cast(descObj->Get(context, key)
      .ToLocalChecked());
```          


Additional files to be compiled together with the Node.js code should be added to
the node.gyp located in the root folder (both .cpp and .h). Compilation is done
with `make -j4` (if run over 4 cores-- optional), which creates the *node*
executable.
