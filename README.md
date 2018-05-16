



-- Betterset aims to:
--
--  * support all basic set operations (and some more),
--  * only overloads operators if the resulting code is intuitive,
--  * be well-documented,
--  * sport a consistent, easy to read, and easy to use API,
--  * be reasonably fast.
--
-- There's also:
--
-- * Wouter Scherphof's
--   [set](https://luarocks.org/modules/luarocks/set),
-- * Ivan Baidakou's
--   [OrderedSet](https://luarocks.org/modules/basiliscos/orderedset),
-- * and [some discussion](http://lua-users.org/wiki/SetOperations)
--   on the Wiki.
--
-- But all of those fail in respect to at least three of the first four points
-- above. That said, they may be faster. I haven't checked.
