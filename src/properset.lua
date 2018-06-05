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
-- @release 0.3b-0


-- Boilerplate
-- ===========

local properset = {}

local assert = assert
local error = error
local pcall = pcall
local table = table
local next = next
local ipairs = ipairs
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local string = string
local tonumber = tonumber
local tostring = tostring
local type = type
local rawequal = rawequal
local rawset = rawset

local upvalueid = debug.upvalueid
local huge = math.huge


-- DEBUG
local print = print


local _ENV = properset


-- Private constants
-- =================

-- Error message shown on attempts to change a `Set`.
local SETMODERR = "sets can only be modified by 'add', 'remove' and 'clear'."

-- Format for error shown if a value isn't a set.
local NOTASETERR = 'expected a Set, got a %s.'

-- Format for error shown if `add` or `remove` are invoked for `FrozenSet`.
local MODFROZENERR = 'set is frozen.'


-- Private utility functions
-- =========================

--- Adds an object to a set.
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
local function uncheckedadd (set, obj, n)
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
-- They can only be modified using `add` and `remove`.
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
--
-- Note: `a:new`, where `a` is itself an 'instance' of `Set`, will create
-- a new 'instance' of `Set`, *not* an 'instance' of `a`. That is,
-- `b = a:new()`, `b = Set:new()`, and `b = Set()` are equivalent.
--
--      > a = Set()
--      > b = a:new()
--      > getmetatable(a) == getmetatable(b)
--      true
function Set:new (elems)
    self = self or Set
    local set = {_val = {len = 0, mem = {}}, _tab = {}, _meta = {}}
    setmetatable(set, self.mt)
    if elems then set:add(elems) end
    return set
end

-- Convenience.
setmetatable(Set, {__call = Set.new})


--- Returns the ID of the set.
--
-- @tparam[opt=0] number flags If `ASNUM` is set, returns the ID as a number. 
--
-- @treturn number The ID.
--
-- @usage
--      > a = Set()
--      > a:id()
--      Set: 0x7f8a555d4df0
--      > a:id(properset.ASNUM)
--      140232114392560
function Set:id (flags)
    flags = flags or 0
    local m = self._meta
    if m.id == nil then
        -- Needed to make `upvalueid` return this method's `self`,
        -- rather than the caller's.
        local s = self
        local r = upvalueid(function () return s end, 1)
        m.id = tonumber(tostring(r):match(': (0x%x+)'))
    end
    if flags & ASNUM == ASNUM then return m.id
                              else return string.format('Set: 0x%x', m.id)
    end
end


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
    local uad = uncheckedadd
    local has = self.has
    local n
    -- This must be `pairs` to handle sparse arrays correctly.
    for _, v in pairs(elems) do
        if not has(self, v) then
            -- @todo Test if it's faster without passing n.
            n = uad(self, v, n) or n
        end
    end
end


--- Deletes members from a set.
--
-- Don't remove members from a set while you're iterating over it.
--
-- @tparam table mems A list of members to be removed.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:remove{2, 3}
--      > a
--      {1}
function Set:remove (mems)
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


--- Removes all members from the set.
--
-- Don't remove members from a set while you're iterating over it.
--
-- @usage
--      > a = Set{1, 2}
--      > a:clear()
--      > a
--      {}
function Set:clear ()
    self._val.mem = {}
    self._val.len = 0
    self._tab = {}
end


--- Tests whether the set is empty.
--
-- @treturn boolean Whether the set is empty.
--
-- @usage
--      > a = Set()
--      > a:isempty()
--      true
--      > b = Set{1}
--      > b:isempty()
--      false
function Set:isempty ()
    return #self == 0
end


--- Tests whether the set is frozen.
--
-- @treturn boolean `false`.
--
-- @usage
--      > a = Set()
--      > a:isfrozen()
--      false
function Set:isfrozen ()
    return false
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
function Set:has (obj, s)
    if type(obj) == 'table' then
        if s and s[obj] then return true end
        local ts = self._tab
        if isset(obj) then
            if s then s[obj] = true else s = {[obj] = true} end
            local eq = getmetatable(obj).__eq
            for i = 1, #ts do if eq(obj, ts[i], s) then return true end end
        else
            for i = 1, #ts do if ts[i] == obj then return true end end
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
    local uad = uncheckedadd
    local cop = copy
    local res = self:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local rt = res._tab
    local n = 1
    rt[n] = Set:new()
    for v in self:mems() do
        for i = 1, n do
            local s = cop(rt[i])
            uad(s, v)
            n = n + 1
            rt[n] = s
        end
    end
    if f then res:freeze() end
    return res
end


--- All members of rank *n*.
--
-- `a:flattened()` and `a:ofrank(0, propertyset.RECURSIVE)` are equivalent.
--
-- @tparam number n The rank.
-- @tparam[opt=0] number flags If `RECURSIVE` is set, then searches members
--   of the set that are sets, members of those sets that are sets, ..., too.
--
-- @treturn Set The members of rank *n*.
--
-- @usage
--      > a = Set{1, Set{2, Set{3, 4}, Set{5}}, Set{6}}
--      > a
--      {1, {2, {3, 4}, {5}}, {6}}
--      > a:ofrank(0)
--      {1}
--      > a:ofrank(1)
--      {{6}}
--      > a:ofrank(2)
--      {{2, {3, 4}, {5}}}
--      > a:ofrank(3)
--      {}
--      > a:ofrank(0, properset.RECURSIVE)
--      {1, 2, 3, 4, 5, 6}
--      > a:ofrank(1, properset.RECURSIVE)
--      {{3, 4}, {5}, {6}}
--      > a:ofrank(2, properset.RECURSIVE)
--      {{2, {3, 4}, {5}}}
--      > a:ofrank(3, properset.RECURSIVE)
--      {}
--
-- @see rank
function Set:ofrank (n, flags, s)
    flags = flags or 0
    -- `flattened` is faster than `ofrank`.
    if n == 0 and flags & RECURSIVE == RECURSIVE then 
        return self:flattened()
    end
    s = s or {}
    local isset = isset
    local rank = rank
    local res = self:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local add = res.add
    for v in self:mems() do
        if not s[v] then
            s[v] = true
            if rank(v) == n then add(res, {v}) end
            if flags & RECURSIVE == RECURSIVE and isset(v) then
                res = res + v:ofrank(n, flags, s)
            end
        end
    end
    if f then res:freeze() end
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
--      > a:atlevel(1)
--      {1, {2, {3, 4}, {5}}, {6}}
--      > a:atlevel(2)
--      {2, {3, 4}, {5}, 6}
--      > a:atlevel(3)
--      {3, 4, 5}
--      > a:atlevel(4)
--      {}
function Set:atlevel (n)
    assert(n > 0, "'n' must be greater than 0.")
    if n == 1 then
        return copy(self)
    else
        local isset = isset
        local res = self:new()
        local f = res:isfrozen()
        if f then res:unfreeze() end
        local add = res.add
        for v in self:mems() do
            if isset(v) then
                add(res, v:atlevel(n - 1))
            end
        end
        if f then res:freeze() end
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
    local res = self:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local add = res.add
    for v in self:mems() do
         add(res, {func(v)})
    end
    if f then res:freeze() end
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
    local res = self:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local add = res.add
    for v in self:mems() do
         if func(v) then
             add(res, {v})
         end
    end
    if f then res:freeze() end
    return res
end


--- The members of the set as a table.
--
-- @tparam[opt=0] number flags If `RECURSIVE` is set, then converts members of
--   the set that are sets, members of those sets that are sets, ..., too.
--
-- @treturn table All members of the set.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > r = a:totable()
--      > table.unpack(r)
--      1       2       3
function Set:totable (flags, s)
    local isset = isset
    local flags = flags or 0
    local s = s or {}
    local res = {}
    local n = 0
    s[self] = res
    for i in self:mems() do
        n = n + 1
        if flags & RECURSIVE == RECURSIVE and isset(i) then
            if s[i] then res[n] = s[i]
                    else res[n] = i:totable(flags, s)
            end
        else
            res[n] = i
        end
    end
    return res
end


--- Unpacks the members of the set.
--
-- @tparam[opt=0] number flags If `RECURSIVE` is set, then unpacks not
--  only this set, but all sets that are members of this set, members of
--  those sets, and so forth.
--
-- @return The members of the given set unpacked.
--
-- @usage
--      > a = Set{1, 2, 3}
--      > a:unpack()
--      1       2       3
function Set:unpack (flags)
    return table.unpack(self:totable(flags))
end


--- Returns the members of the set sorted.
--
-- Keep in mind, sets may be multidimensional.
--
-- @tparam[opt] function callable A sorting function.
-- @tparam[opt=0] number flags If `RECURSIVE` is set, then sorts not
--  only this set, but all sets that are members of this set, members of
--  those sets, and so forth.
--
-- @treturn table A list of the members of the given set, sorted.
--
-- @usage
--      > a = Set{1, 3, 5, 2, 4, 6, 8, 10, 5, 9, 7}
--      > r = a:sorted()
--      > table.concat(r, ', ')
--      1, 2, 3, 4, 5, 6, 7, 8, 9, 10
function Set:sorted (callable, flags)
    local t = self:totable(flags)
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
--      > b:flattened()
--      {1, 2, 3, 4}
function Set:flattened ()
    local isset = isset
    local res = self:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local add = res.add
    local s = {}
    local q = self:totable()
    local l = #q
    local n = 0
    while n <= l do
        n = n + 1
        if isset(q[n]) then
            if not s[q[n]] then
                s[q[n]] = true
                local t = q[n]:totable()
                for i = 1, #t do
                    l = l + 1
                    q[l] = t[i]
                end
            end
        else
            add(res, {q[n]})
        end
    end
    if f then res:freeze() end
    return res
end


--- Makes a set immutable.
--
-- @treturn FrozenSet The frozen set.
--
-- @usage
--      > a = Set()
--      > a:add{0}
--      > a
--      {0}
--      > a:freeze()
--      {0}
--      > a:add{1}
--      set is frozen.
--      [...]
function Set:freeze ()
    return setmetatable(self, FrozenSet.mt)
end


--- Does nothing.
--
-- @treturn Set The set.
--
-- @usage
--      > a = Set()
--      > a:unfreeze()
--      {}
function Set:unfreeze ()
    return self
end


--- Blocks accidential modifications of the set.
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
function Set.mt:__le (other, s)
    assert(isset(other))
    local has = other.has
    for i in self:mems() do
        if not has(other, i, s) then return false end
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
    assert(isset(other))
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
function Set.mt:__eq (other, s)
    if not isset(other) or not isset(self) then return false end
    if #self ~= #other then return false end 
    return getmetatable(self).__le(self, other, s)
end


--- The union of the set and another set.
--
-- `union(a, b)` and `a + b` are equivalent.
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
-- @treturn string A string that represents the set.
--
-- @usage
--      > a = Set{1, Set{2, 3}, 4}
--      > tostring(a)
--      {1, {2, 3}, 4}
function Set.mt:__tostring (s)
    local tostring = tostring
    local isset = isset
    local s = s or {}
    local t = {}
    local n = 0
    for v in self:mems() do
        n = n + 1
        if isset(v) then
            if not s[v] then
                s[v] = true
                t[n] = getmetatable(v).__tostring(v, s)
            else
                return string.format('(cycle: 0x%x)', v:id(ASNUM))
            end
        else
            t[n] = tostring(v)
        end
    end
    return table.concat({'{', '}'}, table.concat(t, ', '))
end


---
-- Frozen Sets are just sets whose `add`, `remove`, and `clear` methods raise
-- an error. They can be populated when they are created but cannot be changed
-- thereafter (through their interface at any rate). The prototype of
-- `FrozenSet` is `Set`, so, otherwise, they behave in the same way as Sets.
--
-- @type FrozenSet
FrozenSet = {}
FrozenSet.mt = {}
-- That I have to do this is a design flaw in Lua.
for k, v in pairs(Set.mt) do FrozenSet.mt[k] = v end
FrozenSet.mt.__index = FrozenSet


--- Creates a new instance of a set prototype, typically `FrozenSet`.
--
-- Note: You cannot create instances of `FrozenSet` using `Set.new`.
--
-- @tparam[opt] table elems Members for the new set.
--
-- @return An instance of the given `prototype` for sets,
--  populated with `members`, if any were given.
--
-- @usage
--      > FrozenSet:new{1, 2, 3}
--      {1, 2, 3}
--      > FrozenSet{1, 2, 3}
--      {1, 2, 3}
function FrozenSet:new (elems)
    self = self or FrozenSet
    local set = Set:new(elems)
    return setmetatable(set, self.mt)
end


--- Tests whether the set is frozen.
--
-- @treturn boolean `true`.
--
-- @usage
--      > a = FrozenSet()
--      > a:isfrozen()
--      true
function FrozenSet:isfrozen ()
    return true
end


---
-- Blocks accidential modifications of the set.
--
-- @raise An error whenever it's invoked.
function FrozenSet.add ()
    error(MODFROZENERR, 2)
end


---
-- Blocks accidential modifications of the set.
--
-- @raise An error whenever it's invoked.
function FrozenSet.remove ()
    error(MODFROZENERR, 2)
end


---
-- Blocks accidential modifications of the set.
--
-- @raise An error whenever it's invoked.
function FrozenSet.clear ()
    error(MODFROZENERR, 2)
end


--- Does nothing.
--
-- @treturn FrozenSet The frozen set.
--
-- @usage
--      > a = FrozenSet()
--      > a:freeze()
--      {}
function FrozenSet:freeze ()
    return self
end


--- Make the set mutable.
--
-- @treturn Set The unfrozen set.
--
-- @usage
--      > a = FrozenSet()
--      > a:add{0}
--      set is frozen.
--      [...]
--      > a:unfreeze()
--      {}
--      > a:add{0}
--      > a
--      {0}
function FrozenSet:unfreeze ()
    return setmetatable(self, Set.mt)
end


-- This must be done after the functions have been added.
-- Once `Set` is the metatable of `FrozenSet`,
-- its members can no longer be changed.
setmetatable(FrozenSet, Set.mt)


--- Set arithmetics
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
--      > properset.aredisjoint{a, b, c}
--      false
--      > properset.aredisjoint{a, c, d}
--      true
function aredisjoint (sets)
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
    -- @todo make n-ary; perhaps as in Python?
    assert(isset(a))
    assert(isset(b))
    local has = b.has
    local uad = uncheckedadd
    local res = a:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local n = 1
    for v in a:mems() do
        -- @todo Test if it's faster without passing n around.
        if not has(b, v) then n = uad(res, v, n) end
    end
    if f then res:freeze() end
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
    if #sets < 1 then return nil end
    local ass = function (x) assert(isset(x)) end
    ass(sets[1])
    local res = copy(sets[1])
    local f = res:isfrozen()
    if f then res:unfreeze() end
    local add = res.add
    local n = #sets
    for i = 2, n do
        ass(sets[i])
        add(res, sets[i])
    end
    if f then res:freeze() end
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
    local ass = function (x) assert(isset(x)) end
    local n = #sets
    if n == 1 then
        return sets[1]
    elseif n > 1 then
        ass(sets[1])
        local f = sets[1]:isfrozen()
        local res
        local acc = sets[1]
        for i = 2, n do
            ass(sets[i])
            res = sets[1]:new()
            if f then res:unfreeze() end
            for v in acc:mems() do
                -- @todo Check if properset.add would work.
                if sets[i]:has(v) then res:add{v} end
                acc = res
            end
            if #acc == 0 then break end
        end
        if f then res:freeze() end
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
    if #sets < 1 then return nil end
    local ass = function (x) assert(isset(x)) end
    local com = complement
    local uni = union
    local int = intersection
    local res = sets[1]:new()
    local f = res:isfrozen()
    if f then res:unfreeze() end
    for i = 1, #sets do
        ass(sets[i])
        res = com(uni{res, sets[i]}, int{res, sets[i]})
    end
    if f then res:freeze() end
    return res
end


--- Utility functions
-- @section function

--- Tests whether an object behaves like a Set.
--
-- That is, tests:
--
-- 1. whether an object's metatable has all fields defined in `Set.mt`;
-- 2. whether an object has all fields defined in `Set`.
--
-- Note: Does *not* test whether those fields refer to functions.
--
-- An object whose metatable provides all methods defined in `Set.mt`
-- and that itself provides all methods defined in `Set` is said to
-- implement the "Set protocol".
--
-- @param obj An object.
--
-- @treturn boolean Whether `obj` implements the Set protocol.
-- @treturn string If it doesn't implement the Set protocol, an error message.
--
-- @usage
--      > a = Set()
--      > properset.isset(a)
--      true
--      > b = "I may be many things, but a Set I'm not."
--      > properset.isset(b)
--      false     expected a Set, got a string.
function isset (obj)
    local rawequal = rawequal
    local t = type(obj)
    if t == 'table' then
        local mt = getmetatable(obj)
        if mt == nil then return false end
        for k in pairs(Set.mt) do if mt[k] == nil then return false end end
        local req = rawequal
        for k in pairs(Set) do if req(obj[k], nil) then return false end end
        return true
    end
    return false, string.format(NOTASETERR, t)
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
function rank (obj, s)
    local isset = isset
    if not isset(obj) then return 0 end
    s = s or {}
    local rank = rank
    local res = 1
    for v in obj:mems() do
        if isset(v) then
            if s[v] then return huge end
            s[v] = true
            local r = rank(v, s) + 1
            if r > res then res = r end
        end
    end
    return res
end


--- Copies a table recursively.
--
-- Handles metatables, recursive structures, tables as keys, and
-- avoids the `__pairs` and `__newindex` metamethods.
-- Copies are deep.
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
function copy (obj, s)
    -- Borrows from:
    -- * <https://gist.github.com/tylerneylon/81333721109155b2d244>
    -- * <http://lua-users.org/wiki/CopyTable>
    if type(obj) ~= 'table' then return obj end
    if s and s[obj] then return s[obj] end
    local copy = copy
    local res = setmetatable({}, getmetatable(obj))
    s = s or {}
    s[obj] = res
    for k, v in next, obj, nil do
        rawset(res, copy(k, s), copy(v, s))
    end
    return res
end


--- Constants 
-- @section constants

--- The empty set.
--
-- @field emptyset The empty set (`FrozenSet:new()`).
emptyset = FrozenSet:new()


--- If this flag is passed to a method that understands it,
-- sets are processed recursively.
--
-- Currently used by:
--
--  * `Set:ofrank`
--  * `Set:totable`
--  * `Set:unpack`
--  * `Set:sorted`
RECURSIVE = 1

--- If this flag is passed to `Set:id`, the set's ID is returned as a number.
--
-- Only used by `Set:id`.
ASNUM = 1


-- Backplate
-- =========

return properset
