---
layout: single
title:  "Debugging Node.js core :bug: : stack trace"
date:   2017-01-18 10:30:00
categories: Outreachy
summary: Debugging Node.js
tags:
- JavaScript
- V8
- llnode
- debugging
---

Up to this point printing variable content on screen, as I digged into Node.js
internals, was sufficient.
I [wrote a bit](https://annamag.github.io/codeandart/outreachy/V8-Data-Types/)
about how variables in V8 were stored and how to go about creating helper functions
needed to access their content.
As the work progressed, it became clear that things had
to get a bit more pro and called for more advanced debugging tools and techniques.
This and the following post are highly inspired by the conversations and live coding sessions
with the project mentor [Franziska](https://github.com/fhinkel/).

There are two useful ways of inspecting the Node.js code: complete stack trace
(both C++ and JavaScript) and being able to step in the functions and
log the contents of variables of interest.
Here, I will focus on accessing the complete stack trace and more advanced
use of lldb with Node.js are summarized in the follow-up.

Node.js maintains and develops [llnode](https://github.com/nodejs/llnode)
:sparkles:,
which can be used to fill in  the gaps in the JavaScript stack trace
(in addition to the C++ one, that is). Another option (possible
to use with XCode) is the [jbt plug-in](https://github.com/thlorenz/lldb-jbt) to lldb.
From my experience, both llnode and jbt are easy to install (all worked as
	described in the install guidelines) and provide fairly similar
level of details. I personally opted for llnode as it is under active development
and guarded under the official Node.js umbrella.

To show an examples of how that could work in a practice, let us take a toy
example:

```js
'use strict';

require('../common');
var vm = require('vm');
const util = require('util');

const sandbox = {};
const context = vm.createContext(sandbox);

const code = `
   var globalVar = "set";
   var object = {value: 10};
   object.color = 'red';
`;

const res = vm.runInContext(code, context);

console.log(util.inspect(sandbox));

```

In the code snippet above, variables and objects are created inside the *vm* context.
For reference on function calls see the [vm](https://nodejs.org/api/vm.html)
API docs.

Assuming that Node.js is cloned locally (here I run it on master branch, v6.2.0),
let us build the debug version

```bash
./configure --debug && make -j4
```

and call llnode from the command line on the test script

```bash
lldb -- ./node_g --perf-basic-prof test.js

```

Calling ```help``` gives the current user-defined commands, in addition to the
lldb specific ones:

```bash
  findjsinstances -- List all objects which share the specified map.
  findjsobjects   -- Alias for `v8 findjsobjects`
  jsprint         -- Alias for `v8 inspect`
  jssource        -- Alias for `v8 source list`
  jsstack         -- Alias for `v8 bt`
  v8              -- Node.js helpers
```


We will set a breakpoint at one of the callbacks called when modifying
(in any way) properties on global objects inside the *vm*,
*GlobalPropertySetterCallback*. What we expect to see
is that the *globalVar*, *object* and *foo1* will be copied onto an object
associated internally with new instance of a V8 Context,
so-called sandbox (process referred to as *"contextifying" the sandbox*).
This and other callbacks are defined in [node_contextify.cc](https://github.com/nodejs/node/blob/master/src/node_contextify.cc).


Next, we execute the script:

```
b node::ContextifyContext::GlobalPropertySetterCallback
r
```

The script stops when hitting the breakpoint in GlobalPropertySetterCallback.

`bt` command shows a number of frames with empty stack trace.
<figure>
  <img src="/assets/images/bt1.png" alt="this is a placeholder image">
  <figcaption>Empty JS stack trace.</figcaption>
</figure>

This is the executed JavaScript code and the point where **jbt** plug-in comes
to rescue.

```
(lldb) v8 i 40
```
Re-runs the command using **jbt** that lists the first 40 frames,
and results in:
<figure>
  <img src="/assets/images/btjs.png" alt="this is a placeholder image">
  <figcaption>Filled in stack trace.</figcaption>
</figure>

The place of interest is the *vm.js* file, where the commands (and thus
	the callbacks) created inside the context are called.
Let us inspect the **0x000019f7d4ed1e99** Object, which corresponds
to the global sandbox object.

```js
(lldb) v8 i 0x000019f7d4ed1e99
    0x000019f7d4ed1e99:<Object: Object properties {
    .<non-string>=0x000019f7d4ed1f71:<unknown>,
    .<non-string>=0x000019f7d4ed5d29:<Object: no constructor>}>
```

As expected, before the Setter kicks in, it is an empty template object.

We continue (```c```) and see that the Setter copies the properties onto the
sandbox

```js
(lldb) v8 i 0x000019f7d4ed1e99
 0x000019f7d4ed1e99:<Object: Object properties {
    .<non-string>=0x000019f7d4ed1f71:<unknown>,
    .<non-string>=0x000019f7d4ed5d29:<Object: no constructor>,
    .globalVar=0x000016ff3ca036b1:<String: "set">}>
```

and again:

```js
(lldb)  v8 i 0x000019f7d4ed1e99
	0x000019f7d4ed1e99:<Object: Object properties {
    .<non-string>=0x000019f7d4ed1f71:<unknown>,
    .<non-string>=0x000019f7d4ed5d29:<Object: no constructor>,
    .globalVar=0x000016ff3ca036b1:<String: "set">,
    .object=0x000019f7d4ed5f21:<Object: Object>}>
```

We can further inspect the *object* property:

```js
(lldb) v8 i 0x000019f7d4ed5f21
  0x000019f7d4ed5f21:<Object: Object properties {
    .value=<Smi: 10>,
    .color=0x000011aa8ee41c61:<String: "red">}>
```

The properties created in the global scope inside the *vm* will be copied onto
the sandbox and visible from the JavaScript script.

```
console.log(util.inspect(sandbox));
```
reveals the modifications of the sanbox:
```JavaScript
{ globalVar: 'set',
  object: { value: 10, color: 'red' }
 }
```

This obviously just scratches the surface of possible uses of **jbt**.
Also, when working on Node.js core we want to use the full capabilities of
a debugger, move through the code and access V8 specific objects. 

Happy inspecting :ok_hand:
