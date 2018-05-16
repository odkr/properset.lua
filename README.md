properset.lua
=============

Allows to handles sets, including complex ones, -- properly.

`properset` allows to properly handle sets that contain objects, tables,
or other sets, sports a rich and sane interface, and is well-documented.


Comparison of Set Packages in Lua
---------------------------------

I have found the following approaches:

* Roberto Ierusalimschy's example in
  [*Learning Lua*](https://www.lua.org/pil/11.5.html)
* Wouter Scherphof's
  [set](https://luarocks.org/modules/luarocks/set)
* Ivan Baidakou's
  [OrderedSet](https://luarocks.org/modules/basiliscos/orderedset)
* Suggestions on the Lua User's
  [Wiki](http://lua-users.org/wiki/SetOperations)

Ierusalimschy proposes to emulate sets using tables:

    function Set (list)
        local set = {}
        for _, l in ipairs(list) do set[l] = true end
        return set
    end

    reserved = Set{"while", "end", "function", "local"}

This approach is simple and fast, however it gets into trouble if we want
set of complexes, say, tables or objects:

    > function Set (list)
    >    local set = {}
    >    for _, l in ipairs(list) do set[l] = true end
    >    return set
    > end
    >
    > a = {1}
    > b = {1}
    > set = Set{a, b}
    > for k in pairs(set) do print (k) end
    table: 0x7ffd87d04680
    table: 0x7ffd87f01100

`a` and `b` are, for all intents and purposes, equal, so they should not
*both* be members of the same set. However, because they are tables, all
that matters when they are used as keys in other tables is their identity;
and one and the same they are *not*.

Note: Defining what it means for `a` and `b` to be equal makes no difference:

    > equality = {__eq = function () return true end}
    > a = setmetatable(a, equality)
    > b = setmetatable(b, equality)
    > a == b
    true
    > set = Set{a, b}
    > for k in pairs(set) do print (k) end
    table: 0x7ffd87d04680
    table: 0x7ffd87f01100

When a table is used as a key in another table, no comparison takes place.
So defining what it means to be equal is pointless.

This is the main problem `properset` solves.

Scherphof, Baidakou and the Wiki adapt and expand upon Ierusalimschy's
approach. Consequently, `set` and `OrderedSet` share this problem.

Unfortunately, solving this problem means that elements have to be compared
one by one, so `properset` is slower than those approaches.

Furthermore, `set` and `OrderSet` both sport spartan, undocumented interfaces.
Scherphof even follows Ierusalimschy in overloading the `/` and `*` operators
for set operations, but neither of those symbols are associated with the
operations he assigns to them in set theory; hence, the interface is
counter-intuitive and the resulting code hard to read.

`properset` aims to have a rich, but sane interface.


Documentation
-------------

See the [package documentation](https://odkr.github.io/properset.lua/).

And use the source.


Installing `properset`
----------------------

You use `properset` **at your own risk**. You have been warned.

You need [Lua](https://www.lua.org/) 5.3 or newer.

If you are using [LuaRocks](https://luarocks.org/), simply say:

    luarocks install properset

Alternatively:

1. Download the source for the [current
   version](https://codeload.github.com/odkr/properset/tar.gz/0.1-0).
2. Unpack it.

On most modern Unix systems, you can simply say:

    curl https://codeload.github.com/odkr/properset/tar.gz/0.1-0 | tar -xz


Contact
-------

If there's something wrong with `properset`, [open an
issue](https://github.com/odkr/properset/issues).


License
-------

Copyright 2018 Odin Kroeger

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


Further Information
-------------------

GitHub:
<https://github.com/odkr/properset.lua>

LuaRocks:
<http://luarocks.org/modules/odkr/properset>
