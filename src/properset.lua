--- Handles complex sets.
--
-- @usage
--      > properset = require 'properset'
--      > Set = properset.Set
--      > a = Set{1, 2, 2, 3, 3, 3}
--      > a
--      {1, 2, 3}
--
-- @module properset
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT
-- @release 0.3-a0


-- Boilerplate
-- ===========

local properset = {}

local assert = assert
local error = error
local pcall = pcall
local debug = debug
local table = table
local next = next
local ipairs = ipairs
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local string = string
local tostring = tostring
local type = type
local rawequal = rawequal

local print = print

local _ENV = properset


-- Constants
-- =========

-- Error message shown on attempts to add a set to itself.
local SELFMEMERR = "sets cannot be members of themselves."

-- Error message shown on attempts to change a `Set`.
local SETMODERR = "sets can only be modified using 'add' and 'delete'."

-- Format for error shown if a value isn't a set.
local NOTASETERR = 'expected Set, got a %s.'

-- Format for error shown if `add` or `delete` are invoked for `ImmutableSet`.
local IMMUTABERR = 'set is immutable.'


-- Private utility functions
-- =========================

--- Adds an object to a set
--
-- Neither checks whether the object is a member already,
-- nor whether adding would make the set a a member of itself!
--
-- @tparam Set set The set to add to.
-- @param obj The object to add.
-- @tparam[opt] number n The index *after* which to store `obj`,
--  if it's a table.
--
-- @return number If `obj` is a table, index at which it was stored;
--  otherwise, `nil`.
local function direct_add (set, obj, n)
    local vt = set._val
    local vs = vt.mem
    local ts = set._tab
    n = n or #ts
    if type(obj) == 'table' then
        n = n + 1
        ts[n] = obj
        return n
    else
        vs[obj] = true
        vt.len = vt.len + 1
    end
end


-- Sets as types
-- =============

-- Set creation
-- ------------

---
-- Sets contain every item at most once.
-- They can only be modified using `add` and `delete`.
-- And set members are (mostly) immutable.
--
-- You should *not* attempt to modify set members.
-- If you do, you may break assumptions that others have based their code on.
-- (This includes me.)
--
-- @type Set

Set = {}
Set.mt = {}
Set.mt.__index = Set


--- Creates a new instance of a prototype, typically `Set`.
--
-- @tparam[opt] table elems Members for the new set.
--
-- @return An instance of the given prototype for sets,
--  populated with `elems`, if any were given.
--
-- @usage
--      > Set:new{1, 2, 3}
--      {1, 2, 3}
--      > Set{1, 2, 3}
--      {1, 2, 3}
function Set:new (elems)
    self = self or Set
    local set = {_val = {len = 0, mem = {}}, _tab = {}}
    setmetatable(set, self.mt)
    if elems then set:add(elems) end
    return set
end

-- Convenience.
setmetatable(Set, {__call = Set.new})


--- Adds elements to a set.
--
-- Don't add members to a set while you're iterating over it.
--
-- @tparam table elems A list of elements to be added.
--
-- @raise Raises an error if you try to add a set to itself.
--
-- @usage
--      > a = Set{1}
--      > a:add{2}
--      > a
--      {1, 2}
--      > a:add{2}
--      > a
--      {1, 2}
function Set:add (elems)
    local dad = direct_add
    local has = self.has
    local n
    -- This must be `pairs` to handle sparse arrays correctly.
    for _, v in pairs(elems) do
        if not has(self, v) then
            if rawequal(self, v) then error(SELFMEMERR, 2) end
            -- @todo Test if it's faster without passing n.
            n = dad(self, v, n) or n
        end
    end
end


--- Deletes members from a set.
--
-- Don't delete members of a set while you're iterating over it.
--
-- @tparam table mems A list of members to be deleted.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:delete{2, 3}
--      > a
--      {1}
function Set:delete (mems)
    local rem = table.remove
    local vt = self._val
    local vs = vt.mem
    local ts = self._tab
    for _, v in pairs(mems) do
        if type(v) == 'table' then
            for i = #ts, 1, -1 do
                if ts[i] == v then
                    -- `ts[i] = nil` causes a weird bug.
                    rem(ts, i)
                    break
                end
            end
        else
            vs[v] = nil
            vt.len = vt.len - 1
        end
    end
end


--- Tests whether the set is empty.
--
-- @treturn boolean Whether the set is empty.
--
-- @usage
--      > a = Set()
--      > a:is_empty()
--      true
--      > b = Set{1}
--      > b:is_empty()
--      false
function Set:is_empty ()
    return #self == 0
end


--- Tests whether an object is a member of the set.
--
-- @param obj An object.
--
-- @treturn boolean Whether an object is a member of the set.
--
-- @usage
--      > a = Set{1}
--      > a:has(1)
--      true
--      > a:has(0)
--      false
function Set:has (obj)    
    if type(obj) == 'table' then
        -- To avoid problems with recursive data structures, which 
        -- may cause a cycle `Set.mt.__eq` -> `Set.mt.__le` -> 
        -- `Set.has` -> `Set.mt.__eq`, we need to check whether
        -- we have already seen `obj`.
        -- 
        -- I am using `debug.getlocal` to implement dynamic scoping.
        -- This ain't pretty, but since the cycle stretches over three
        -- methods, some of which are metamethods, it would be hard to
        -- pass an extra argument. And I doubt that adding a 'static'
        -- variable to `has` would be safe in a threaded environment --
        -- or much faster for that matter.
        local getlocal = debug.getlocal
        -- The current function is level 1, one cycle has a length of 3, and
        -- we need to add 1 level each for `pcall` and the lambda; hence 6.
        local n = 6
        while true do
            -- `obj` is the second variable that has been defined.
            local s, _, v = pcall(function () return getlocal(n, 2) end)
            if not s then break end
            if rawequal(obj, v) then return true end
            -- The cycle has a length of three.
            n = n + 3
        end        
        local ts = self._tab
        for i = 1, #ts do
            if ts[i] == obj then return true end
        end
        return false
    else
        return self._val.mem[obj] or false
    end
end


--- Iterates over all members of the set.
--
-- @treturn function A function that returns a member of the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > for v in a:mems() do print(v) end
--      1
--      2
--      3
function Set:mems ()
    local vs = self._val.mem
    local ts = self._tab
    local k = nil
    local i = 0
    return function ()
        if k ~= nil or i == 0 then
            k, _ = next(vs, k)
            if k ~= nil then return k end
        end
        i = i + 1
        return ts[i]
    end
end


--- The set's power set.
--
-- Calculating a power set runs in exponential time, namely, *O*(2^*n*).
-- Average times needed to calculate the power set of a set with *n* members
-- (on an 1,6 GHz Intel Core i5 with Lua 5.3.4):
--
-- * n = 8: <0.01s
-- * n = 9: 0.01s
-- * n = 10: 0.02s,
-- * n = 11: 0.03s
-- * n = 12: 0.06s
-- * n = 13: 0.12s
-- * n = 14: 0.28s
-- * n = 15: 0.51s
-- * n = 16: 1s
--
-- @treturn Set(Set,...) The set's power set.
--
-- @usage
--      > a = Set{0, 1}
--      > a:power()
--      {{0, 1}, {1}, {}, {0}}
function Set:power ()
    local dad = direct_add
    local cop = Set.copy
    local res = Set:new()
    local rt = res._tab
    local n = 1
    rt[n] = Set:new()
    for v in self:mems() do
        for i = 1, n do
            local s = cop(rt[i])
            dad(s, v)
            n = n + 1
            rt[n] = s
        end
    end
    return res
end


--- The set's rank.
--
-- @treturn number The set's rank.
--
-- @see rank
function Set:rank ()
    return rank(self)
end


--- All members of rank *n*.
--
-- `a:flatten()` and `a:of_rankn(0, true)` are equivalent.
--
-- @tparam number n The rank.
-- @tparam[opt=false] boolean rec Whether to recurse into members, too.
--
-- @treturn Set The members of rank *n*.
--
-- @usage
--      > a = Set{1, Set{2, Set{3, 4}, Set{5}}, Set{6}}
--      > a
--      {1, {2, {3, 4}, {5}}, {6}}
--      > a:of_rankn(0)
--      {1}
--      > a:of_rankn(1)
--      {{6}}
--      > a:of_rankn(2)
--      {{2, {3, 4}, {5}}}
--      > a:of_rankn(3)
--      {}
--      > a:of_rankn(0, true)
--      {1, 2, 3, 4, 5, 6}
--      > a:of_rankn(1, true)
--      {{3, 4}, {5}, {6}}
--      > a:of_rankn(2, true)
--      {{2, {3, 4}, {5}}}
--      > a:of_rankn(3, true)
--      {}
--
-- @see rank
function Set:of_rankn (n, rec)
    if rec == nil then rec = false end
    if n == 0 and rec then return self:flatten() end
    local is_set = is_set
    local rank = rank
    local add = Set.add
    local res = Set:new()
    for v in self:mems() do
        if rank(v) == n then add(res, {v}) end
        if rec and is_set(v) then res = res + v:of_rankn(n, rec) end
    end
    return res
end


--- All members at level *n*.
--
-- Levels:
--  1 = members of the set,
--  2 = members of members of the set,
--  3 = ...
--
-- @tparam number n The level.
--
-- @treturn Set The members at level *n*.
--
-- @raise Raises an error unless `n` > 0.
--
-- @usage
--      > a = Set{1, Set{2, Set{3, 4}, Set{5}}, Set{6}}
--      > a
--      {1, {2, {3, 4}, {5}}, {6}}
--      > a:at_leveln(1)
--      {1, {2, {3, 4}, {5}}, {6}}
--      > a:at_leveln(2)
--      {2, {3, 4}, {5}, 6}
--      > a:at_leveln(3)
--      {3, 4, 5}
--      > a:at_leveln(4)
--      {}
function Set:at_leveln (n)
    assert(n > 0, "'n' must be greater than 0.")
    if n == 1 then
        return self:copy()
    else
        local is_set = is_set
        local add = Set.add
        local res = Set:new()
        for v in self:mems() do
            if is_set(v) then
                add(res, v:at_leveln(n-1))
            end
        end
        return res
    end
end


--- Maps a function of all values of the set onto another set.
--
-- @tparam function func A function to be applied to each member.
--
-- @treturn Set The results of applying `func` to the members of the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:map(function(i) return i + 1 end)
--      {2, 3, 4}
function Set:map (func)
    local add = Set.add
    local res = Set:new()
    for v in self:mems() do
         add(res, {func(v)})
    end
    return res
end


--- Filters members of a set.
--
-- @tparam function func A function that defines which members will be selected.
--
-- @treturn Set The filtered set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:filter(function(i) return i % 2 == 0 end)
--      {2}
function Set:filter (func)
    local add = Set.add
    local res = Set:new()
    for v in self:mems() do
         if func(v) then
             add(res, {v})
         end
    end
    return res
end


--- The members of the set as a table.
--
-- @treturn table All members of the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > r = a:totable()
--      > table.unpack(r)
--      1       2       3
function Set:totable ()
    local res = {}
    local n = 0
    for i in self:mems() do
        n = n + 1
        res[n] = i
    end
    return res
end


--- The members of the set as a table, recursively.
--
-- Different to `Set.totable`, this method recurses into members of sets.
-- That is, it will return a higher-rank set as a multidimensional table.
--
-- @treturn table All members of the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > r = a:totable()
--      > table.unpack(r)
--      1       2       3
function Set:rtotable (s)
    local is_set = is_set
    local res = self:totable()
    local s = s or {}
    s[self] = res
    for i = 0, #res do
        if is_set(res[i]) then
            if s[res[i]] then
                res[i] = s[res[i]]
            else
                res[i] = res[i]:rtotable(s)
            end
        end
    end
    return res
end


--- Unpacks the members of the set.
--
-- @return The members of the given set unpacked.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:unpack()
--      1       2       3
function Set:unpack ()
    return table.unpack(self:totable())
end


--- Concatenates all members of the set to a string.
--
-- Keep in mind, sets may be multidimensional. Consider using `flatten`.
--
-- @tparam[opt=''] string sep A string to seperate members.
--
-- @treturn string The members of the set, seperated by `sep`.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:concat(', ')
--      1, 2, 3
function Set:concat (sep)
    return table.concat(self:totable(), sep)
end


--- Returns the members of the set sorted.
--
-- Keep in mind, sets may be multidimensional. Consider using `flatten`.
--
-- @tparam[opt] function callable A sorting function.
--
-- @treturn table A list of the members of the given set, sorted.
--
-- @usage
--      > a = Set{1, 3, 5, 2, 4, 6, 8, 10, 5, 9, 7}
--      > r = a:sorted()
--      > table.concat(r, ', ')
--      1, 2, 3, 4, 5, 6, 7, 8, 9, 10
function Set:sorted (callable)
    local t = self:totable()
    table.sort(t, callable)
    return t
end


--- The non-set members of the set and its descendants.
--
-- @treturn Set A set with all non-set members of the set and its descendants.
--
-- @usage
--      > a = Set{1, Set{2, 3}, 4}
--      > b = a:power()
--      > b:flatten()
--      {1, 2, 3, 4}
function Set:flatten ()
    local is_set = is_set
    local add = Set.add
    local res = Set:new()
    for v in self:mems() do
        if is_set(v) then
            res = res + v:flatten()
        else
            add(res, {v})
        end
    end
    return res
end


--- Copies a set.
--
-- Copies are deep.
--
-- You should *never* need this function.
--
-- Instead of:
--
--      a = Set{1, 2, 3}
--      b = a:copy()
--      b:add{4}
--
-- Write:
--
--      a = Set{1, 2, 3}
--      b = a + Set{4}
--
-- @tparam Set set A set.
--
-- @return The same set, but a different instance.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > r = a:copy()
--      > r
--      {1, 2, 3}
--      > a:add{4}
--      > r
--      {1, 2, 3}
function Set:copy ()
    local res = Set:new()
    res._val = copy(self._val)
    res._tab = copy(self._tab)
    return res
end


--- Blocks accidential modifications of a set or its members.
--
-- @raise An error whenever it's invoked.
function Set.mt:__newindex ()
    error(SETMODERR, 2)
end


--- Easier access to new in derived prototypes.
--
-- @tparam[opt] table elems Members for the new set.
--
-- @return An instance of the given prototype for sets,
--  populated with `elems`, if any were given.
function Set.mt:__call (elems)
    return self:new(elems)
end


--- The number of elements in the set.
--
-- @treturn number Number of elements in the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > #a
--      3
function Set.mt:__len ()
    -- @todo maybe counting as needed is faster than keeping track.
    return self._val.len + #self._tab
end


--- Iterates over the set as if it were a list.
--
-- @usage
--      > a = Set{'a', 'b', 'c'}
--      > for i, v in ipairs(a) do print(i, v) end
--      1       a
--      2       b
--      3       c
function Set.mt:__ipairs ()
    local vs = self._val.mem
    local ts = self._tab
    local n = #ts
    local k = nil
    local i = 0
    local j = 0
    return function ()
        j = j + 1
        if k ~= nil or i == 0 then
            k, _ = next(vs, k)
            if k ~= nil then return j, k end
        end
        if i < n then
            i = i + 1
            return j, ts[i]
        end
    end
end


--- Iterates over the set as if it were a table.
--
-- @usage
--      > a = Set{'a', 'b', 'c'}
--      > for k, v in pairs(a) do print(k, v) end
--      1       a
--      2       b
--      3       c
Set.mt.__pairs = Set.mt.__ipairs


--- Tests whether the set is a subset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a subset of another set.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{1}
--      > c = Set{3}
--      > b <= a
--      true
--      > c <= a
--      false
function Set.mt:__le (other)
    assert_set(other, 'other')
    local has = other.has
    for i in self:mems() do
        if not has(other, i) then return false end
    end
    return true
end


--- Tests whether the set is a strict subset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a strict subset of another set.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{1}
--      > c = Set{3}
--      > a < a
--      false
--      > a <= a
--      true
--      > b < a
--      true
--      > c < a
--      false
function Set.mt:__lt (other)
    assert_set(other, 'other')
    if #self < #other then return self <= other end
    return false
end


--- Tests whether the set is equal to another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is equal to another set.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1}
--      > b = Set{1}
--      > c = Set{2}
--      > a == b
--      true
--      > a ~= b
--      false
--      > a == c
--      false
--      > a ~= c
--      true
function Set.mt:__eq (other)
    if not is_set(other) or not is_set(self) then return false end
    if #self ~= #other then return false end 
    return self <= other
end


--- The union of the set and another set.
--
-- `a:union(b)` and `a + b` are equivalent.
--
-- @tparam Set other The other set.
--
-- @treturn Set The union of the two sets.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1}
--      > b = Set{2}
--      > a + b
--      {1, 2}
function Set.mt:__add (other)
    return union{self, other}
end


--- The complement of the set and another set.
--
-- `complement(a, b)` and `a - b` are equivalent.
--
-- @tparam Set other The other set.
--
-- @treturn Set The complement of the two sets.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{2}
--      > a - b
--      {1}
function Set.mt:__sub (other)
    return complement(self, other)
end


--- The intersection of the set and another set.
--
-- `intersection(a, b)` and `a ^ b` are equivalent.
--
-- @tparam Set other The other set.
--
-- @treturn Set The intersection of the two sets.
--
-- @raise Raises an error of `other` is not a `Set`
--  (or another implementation of its protocol).
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{2, 3}
--      > a ^ b
--      {3}
function Set.mt:__pow (other)
    return intersection(self, other)
end


--- A string representation of the set.
--
-- `__tostring(a)` and `tostring(a)` are equivalent.
--
-- @treturn string A string that represents the set.
--
-- @usage
--      > a = Set{1, Set{2, 3}, 4}
--      > tostring(a)
--      {1, {2, 3}, 4}
function Set.mt:__tostring (s)
    local tostring = tostring
    local is_set = is_set
    local s = s or {}
    local t = {}
    local n = 0
    for v in self:mems() do
        n = n + 1
        if is_set(v) then
            if not s[v] then
                s[v] = true
                t[n] = getmetatable(v).__tostring(v, s)
            else
                return '(cycle)'
            end
        else
            t[n] = tostring(v)
        end
    end
    return table.concat({'{', '}'}, table.concat(t, ', '))
end


---
-- Immutable Sets are just sets without an `add` and a `delete` method.
-- (Strictly speaking, they have those methods, but calling them
-- results in a runtime error.) They can be populated when they are
-- created but cannot be changed afterwards (through their interface
-- at any rate).
--
-- @type ImmutableSet
ImmutableSet = {}
ImmutableSet.mt = {}
-- That I have to do this is a design flaw in Lua.
for k, v in pairs(Set.mt) do ImmutableSet.mt[k] = v end
ImmutableSet.mt.__index = ImmutableSet


--- Creates a new instance of a set prototype, typically `ImmutableSet`.
--
-- Note: You cannot create instances of `ImmutableSet` using `Set.new`.
--
-- @tparam[opt] table elems Members for the new set.
--
-- @return An instance of the given `prototype` for sets,
--  populated with `members`, if any were given.
--
-- @usage
--      > ImmutableSet:new{1, 2, 3}
--      {1, 2, 3}
--      > ImmutableSet{1, 2, 3}
--      {1, 2, 3}
function ImmutableSet:new (elems)
    self = self or ImmutableSet
    local set = {_val = {len = 0, mem = {}}, _tab = {}}
    setmetatable(set, self.mt)
    if elems then Set.add(set, elems) end
    return set
end


---
-- Blocks accidential modifications of a set or its members.
--
-- @raise An error whenever it's invoked.
function ImmutableSet.add ()
    error(IMMUTABERR, 2)
end


---
-- Blocks accidential modifications of a set or its members.
--
-- @raise An error whenever it's invoked.
function ImmutableSet.delete ()
    error(IMMUTABERR, 2)
end


-- This must be done after the functions have been added.
-- Once `Set` is the metatable of `ImmutableSet`,
-- its members can no longer be changed.
setmetatable(ImmutableSet, Set.mt)


--- n-ary set arithmetics
-- @section arithmetics

--- Tests whether two or more sets are disjoint.
--
-- @tparam {Set,...} sets A list of sets to compare.
--
-- @treturn boolean Whether the given sets are disjoint.
--
-- @usage
--      > a = Set{1}
--      > b = Set{1, 2}
--      > c = Set{2}
--      > d = Set{3}
--      > properset.are_disjoint{a, b, c}
--      false
--      > properset.are_disjoint{a, c, d}
--      true
function are_disjoint (sets)
    local int = intersection
    for i = 1, #sets do
        for j = i + 1, #sets do
            local s = int{sets[i], sets[j]}
            if #s ~= 0 then return false end
        end
    end
    return true
end


--- The complement of two sets A and B.
--
-- `complement(a, b)` and `a - b` are equivalent.
--
-- @tparam Set a Set A.
-- @tparam Set b Set B.
--
-- @treturn Set The complement of A and B.
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{2}
--      > properset.complement(a, b)
--      {1}
function complement (a, b)
    assert_set(a, 'a')
    assert_set(b, 'b')
    local has = b.has
    local dad = direct_add
    local res = Set:new()
    local n = 1
    for v in a:mems() do
        -- @todo Test if it's faster without passing n around.
        if not has(b, v) then n = dad(res, v, n) end
    end
    return res
end


--- The union of two or more sets.
--
-- `a:union(b)` and `a + b` are equivalent.
--
-- @tparam {Set,...} sets A list of sets of which to form a union.
--
-- @treturn Set The union of the given sets.
--
-- @usage
--      > a = Set{1}
--      > b = Set{2}
--      > c = Set{3}
--      > properset.union{a, b, c}
--      {1, 2, 3}
function union (sets)
    local ass = assert_set
    local add = Set.add
    local res = Set:new()
    local n = #sets
    for i = 1, n do
        ass(sets[i], "arg " .. i)
        add(res, sets[i])
    end
    return res
end


--- The intersection of two or more sets.
--
-- @tparam {Set,...} sets A list of sets to intersect.
--
-- @treturn Set The intersection of the given sets.
--
-- @usage
--      > a = Set{1}
--      > b = Set{1,2}
--      > c = Set{2}
--      > d = Set{1,3}
--      > properset.intersection{a, b, c}
--      {}
--      > properset.intersection{a, b, d}
--      {1}
function intersection (sets)
    local ass = assert_set
    local n = #sets
    if n == 1 then
        return sets[1]
    elseif n > 1 then
        ass(sets[1], "arg " .. 1)
        local add = Set.add
        local res
        local acc = sets[1]
        for i = 2, n do
            ass(sets[i], "arg " .. i)
            res = Set:new()
            for v in acc:mems() do
                -- @todo Check if properset.add would work.
                if sets[i]:has(v) then add(res, {v}) end
                acc = res
            end
            if #acc == 0 then break end
        end
        return res
    end
end


--- The symmetric difference of two or more sets.
--
-- The symmetric difference, Δ, of three sets *A*, *B*, and *C* is defined as:
-- (*A* Δ *B*) Δ *C*, that is, as 'repetition' over a series, *not* as
-- (*A* ∪ *B* ∪ *C*) \ (*A* ∩ *B* ∩ *C*), that is, as the complement of the
-- union of *A*, *B*, and *C* and the intersection of *A*, *B*, and *C*.
-- Make sure you understand the example below. (A friendly reminder for us
-- non-mathematicians and non-computer science people.)
--
-- @tparam {Set,...} sets A list of sets to calculate the difference of.
--
-- @treturn Set The symmetric difference of the given sets.
--
-- @usage
--      > a = Set{1, 2}
--      > b = Set{1, 3}
--      > c = Set{1, 2, 3, 4}
--      > properset.difference{a, b, c}
--      {1, 4}
function difference (sets)
    local ass = assert_set
    local com = complement
    local uni = union
    local int = intersection
    local res = Set:new()
    for i = 1, #sets do
        ass(sets[i], "arg " .. i)
        res = com(uni{res, sets[i]}, int{res, sets[i]})
    end
    return res
end


--- Utility functions
-- @section function

--- Tests whether an object behaves Set-ish.
--
-- @param obj An object.
--
-- @treturn boolean Whether `obj` implements the `Set` protocol.
--
-- @usage
--      > a = Set()
--      > properset.is_set(a)
--      true
--      > b = "I may be many things, but a Set I'm not."
--      > properset.is_set(b)
--      false
function is_set (obj)
    local rawequal = rawequal
    if type(obj) == 'table' then
        local meta = getmetatable(obj)
        if meta == nil then return false end
        for k in pairs(Set.mt) do 
            if meta[k] == nil then return false end
        end
        for k in pairs(Set) do
            if rawequal(obj[k], nil) then return false end
        end
        return true
    end
    return false
end


--- Asserts that an object is a set.
--
-- @param obj An object.
-- @param[opt] var The name of the variable.
--
-- @raise An error if `obj` isn't a `Set` (or implements the Set protocol).
function assert_set (obj, var)
    local err = string.format(NOTASETERR, type(obj))
    if var then err = string.format('%q: ', var) .. err end
    assert(is_set(obj), err)
end


--- Calculates the rank of an object.
--
-- Ranks:
--  0 = non-set objects,
--  1 = sets that don't contain sets,
--  2 = sets that (also) contain sets, but only of rank 1,
--  3 = sets that (also) contain sets of rank 2,
--  4 = ...
--
-- @param obj An object.
--
-- @treturn number The rank of `obj`.
--
-- @usage
--      > s = "I'm nobody."
--      > properset.rank(s)
--      0
--      > a = Set()
--      > properset.rank(a)
--      1
--      > b = Set{Set{Set{Set{}}, Set{}, 1}, 2}
--      > properset.rank(b)
--      4
function rank (obj)
    local is_set = is_set
    local rank = rank
    if not is_set(obj) then return 0 end
    local res = 1
    for v in obj:mems() do
        if is_set(v) then
            r = rank(v) + 1
            if r > res then res = r end
        end
    end
    return res
end


--- Copies a table recursively.
--
-- Handles metatables, simple recursive structures, tables as keys,
-- avoids the `__pairs` metemethod, and can handle instances of `Set`.
--
-- *Cannot* handle cycles.
--
-- @param obj Object or value of an arbitrary type.
--
-- @return A copy of `obj`.
--
-- @usage
--      > a = {1, 2, 3}
--      > b = {a, 4}
--      > r = properset.copy(b)
--      > table.insert(a, 4)
--      > table.unpack(r[1])
--      1       2       3
function copy(obj, seen)
    -- Borrows from:
    -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
    -- * <http://lua-users.org/wiki/CopyTable>
    if type(obj) ~= 'table' then return obj end
    if is_set(obj) then return obj:copy() end
    if seen and seen[obj] then return seen[obj] end
    local copy = copy
    local res = setmetatable({}, getmetatable(obj))
    seen = seen or {}
    seen[obj] = res
    for k, v in next, obj, nil do
        res[copy(k, seen)] = copy(v, seen)
    end
    return res
end


--- Useful constants
-- @section constants

--- The empty set.
--
-- This set cannot be modified via `add` and `delete`.
--
-- @field emptyset The empty set (`ImmutableSet:new()`).
emptyset = ImmutableSet:new()


return properset
