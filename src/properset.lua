--- Handle complex sets.
--
-- @usage
--      > properset = require 'properset'
--      > Set = properset.Set
--      > a = Set:new{1, 2, 2, 3, 3, 3}
--      > a
--      {1, 2, 3}
--
-- @module properset
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT
-- @release 0.0

-- Boilerplate
-- ===========

local properset = {}

local assert = assert
local error = error
local table = table
local next = next
local ipairs = ipairs
local pairs = pairs
local getmetatable = getmetatable
local setmetatable = setmetatable
local tostring = tostring
local type = type

local print = print

local _ENV = properset


-- Sets as types
-- =============

-- Set creation
-- ------------

---
-- Sets can only be modified using `add` and `delete`.
-- And set members are (mostly) immutable.
--
-- You should *not* attempt to modify set members.
-- If you do, you may break assumptions that others have based their code on.
-- (This includes me.)
--
-- @type Set

Set = {}
Set.__index = Set


--- Creates a new instance of a prototype, typically `Set`.
--
-- @tparam[opt] table members Set members.
--
-- @return An instance of the given `prototype` for sets,
--  populated with `members`, if any were given.
--
-- @usage
--      > Set:new{1, 2, 3}
--      {1, 2, 3}
function Set:new (members)
    self = self or Set
    local set = {_members={}}
    setmetatable(set, self)
    if members then set:add(members) end
    return set
end


---
-- Blocks accidential modifications of a set or its members.
--
-- @raise An error whenever it's invoked.
function Set:__newindex()
    error("sets can only be modified using 'add' and 'delete'.", 2)
end


-- Cardinality
-- -----------

--- The number of elements in the set.
--
-- @treturn number Number of elements in the set.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > #a
--      3
function Set:__len ()
    return #self._members
end


-- Iterting over sets
-- ------------------

--- Iterates over all members of the set.
--
-- @treturn function A function that returns a member of the set.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > for v in a:members() do print(v) end
--      1
--      2
--      3
function Set:members ()
    local m = self._members
    local i = 0
    local n = #m
    return function ()
        i = i + 1
        if i <= n then return m[i] end
    end
end


--- Iterates over the set as if it were a list.
--
-- @usage
--      > a = Set:new{'a', 'b', 'c'}
--      > for i, v in ipairs(a) do print(i, v) end
--      1       a
--      2       b
--      3       c
function Set:__ipairs ()
    return nth_member, self, 0
end


--- Iterates over the set as if it were a table.
--
-- @usage
--      > a = Set:new{'a', 'b', 'c'}
--      > for k, v in pairs(a) do print(k, v) end
--      1       a
--      2       b
--      3       c
function Set:__pairs ()
    return next_member, self, nil
end


-- Manipulating sets
-- -----------------

--- Adds elements to a set.
--
-- @tparam table elements A list of elements to be added.
--
-- @usage
--      > a = Set:new{1}
--      > a:add{2}
--      > a
--      {1, 2}
--      > a:add{2}
--      > a
--      {1, 2}
function Set:add (elements)
    for _, v in ipairs(elements) do
        if not self:has_member(v) then
            table.insert(self._members, v)
        end
    end
end


--- Deletes elements from a set.
--
-- Don't delete members of a set while you're iterating over it.
--
-- That is, don't try something like this:
--
--      a = Set:new{1, 2}
--      b = Set:new{2, 4}
--      for v in a:members() do
--          for w in b:members() do
--              if v == w then
--                  a:delete{v}
--              end
--          end
--      end
--
--
-- @tparam table members A list of elements to be deleted.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > a:delete{2, 3}
--      > a
--      {1}
function Set:delete (members)
    for i = #self._members, 1, -1 do
        for _, v in ipairs(members) do
            if self._members[i] == v then
                table.remove(self._members, i)
                break
            end
        end
    end
end


-- Boolean relations
-- -----------------

--- Tests whether the set is empty.
--
-- @treturn boolean Whether the set is empty.
--
-- @usage
--      > a = Set:new()
--      > a:is_empty()
--      true
--      > b = Set:new{1}
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
--      > a = Set:new{1}
--      > a:has_member(1)
--      true
--      > a:has_member(0)
--      false
function Set:has_member (obj)
    for v in self:members() do
        if v == obj then return true end
    end
    return false
end


--- Tests whether the set is a subset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a subset of another set.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{1}
--      > c = Set:new{3}
--      > b <= a
--      true
--      > c <= a
--      false
function Set:__le (other)
    for i in self:members() do
        if not other:has_member(i) then return false end
    end
    return true
end


--- Tests whether the set is a superset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a superset of another set.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{1}
--      > c = Set:new{3}
--      > a >= b
--      true
--      > a >= c
--      false
function Set:__ge (other)
    return other <= self
end


--- Tests whether the set is a strict subset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a strict subset of another set.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{1}
--      > c = Set:new{3}
--      > a < a
--      false
--      > a <= a
--      true
--      > b < a
--      true
--      > c < a
--      false
function Set:__lt (other)
    if #self < #other then return self <= other end
    return false
end


--- Tests whether the set is a strict superset of another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is a strict superset of another set.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{1}
--      > c = Set:new{3}
--      > a > a
--      false
--      > a >= a
--      true
--      > a > b
--      true
--      > a > c
--      false
function Set:__gt (other)
    return other < self
end


--- Tests whether the set is equal to another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the set is equal to another set.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{1}
--      > c = Set:new{2}
--      > a == b
--      true
--      > a ~= b
--      false
--      > a == c
--      false
--      > a ~= c
--      true
function Set:__eq (other)
    if #self == #other then return self <= other end
    return false
end


--- Tests whether the set is disjoint from another set.
--
-- @tparam Set other The other set.
--
-- @treturn boolean Whether the two sets are disjoint.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{1, 2}
--      > c = Set:new{3}
--      > a:is_disjoint_from(b)
--      false
--      > a:is_disjoint_from(c)
--      true
function Set:is_disjoint_from (other)
    return are_disjoint{self, other}
end


-- Set arithmetics
-- ---------------

--- The complement of the sets and another set.
--
-- `complement(a, b)` and `a - b` are equivalent.
--
-- @tparam Set other The other set.
--
-- @treturn Set The complement of the two sets.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{2}
--      > a - b
--      {1}
function Set:__sub (other)
    return complement(self, other)
end


--- The union of the set and another set.
--
-- `a:union(b)` and `a + b` are equivalent.
--
-- @tparam Set other The other set.
--
-- @treturn Set The union of the two sets.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{2}
--      > a + b
--      {1, 2}
function Set:__add (other)
    return union{self, other}
end


--- The intersection of the set with another set.
--
-- @tparam Set other Another set to intersect the set with.
--
-- @treturn Set The intersection of the two sets.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{1,2}
--      > c = Set:new{2}
--      > a:intersection(b)
--      {1}
--      > b:intersection(c)
--      {2}
--      > a:intersection(c)
--      {}
function Set:intersection (other)
    return intersection {self, other}
end


--- The symmetric difference between the set and another set.
--
-- @tparam Set other The other set.
--
-- @treturn Set The symmetric difference of the two sets.
--
-- @usage
--      > a = Set:new{1, 2}
--      > b = Set:new{1, 3}
--      > a:difference(b)
--      {2, 3}
function Set:difference (other)
    return difference {self, other}
end


--- The set's power set.
--
-- @treturn Set(Set,...) The set's power set.
--
-- @usage
--      > a = Set:new{0, 1}
--      > a:power()
--      {{0, 1}, {1}, {}, {0}}
function Set:power ()
    local res = Set:new{self}
    for i in self:members() do
        local subset = self - Set:new{i}
        for j in subset:power():members() do
            res:add{j}
        end
    end
    return res
end


-- Sets of sets
-- ------------

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
-- @tparam boolean desc Whether to descend into members that are sets, too.
--
-- @treturn Set The members of rank *n*.
--
-- @usage
--      > a = Set:new{1, Set:new{2, Set:new{3, 4}, Set:new{5}}, Set:new{6}}
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
function Set:of_rankn (n, desc)
    if desc == nil then desc = false end
    if n == 0 and desc then return self:flatten() end
    local res = Set:new()
    for v in self:members() do
        if rank(v) == n then res:add{v} end
        if desc and is_set(v) then res = res + v:of_rankn(n, desc) end
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
--      > a = Set:new{1, Set:new{2, Set:new{3, 4}, Set:new{5}}, Set:new{6}}
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
        local res = Set:new()
        for v in self:members() do
            if is_set(v) then
                local m = v:at_leveln(n-1)
                res:add(m._members)
            end
        end
        return res
    end
end


-- Convenience methods
-- -------------------

--- A string representation of the set.
--
-- `__tostring(a)` and `tostring(a)` are equivalent.
--
-- @treturn string A string that represents the set.
--
-- @usage
--      > a = Set:new{1, Set:new{2, 3}, 4}
--      > tostring(a)
--      {1, {2, 3}, 4}
function Set:__tostring ()
    local res = '{'
    local i = 1
    for v in self:members() do
        if i ~= 1 then res = res .. ', ' end
        i = i + 1
        if is_set(v) then
            res = res .. v:__tostring()
        else
            res = res .. tostring(v)
        end
    end
    res = res .. '}'
    return res
end


--- The members of the set as a table.
--
-- If the set contains other sets, these will be converted to tables, too.
--
-- @treturn table All members of the set.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > r = a:totable()
--      > table.unpack(r)
--      1       2       3
function Set:totable ()
    local res = {}
    for i in self:members() do
        if is_set(i) then
            table.insert(res, i:totable())
        else
            table.insert(res, i)
        end
    end
    return res
end


--- The non-set members of the set and its descendants.
--
-- @treturn Set A set with all non-set members of the set and its descendants.
--
-- @usage
--      > a = Set:new{1, Set:new{2, 3}, 4}
--      > b = a:power()
--      > b:flatten()
--      {1, 2, 3, 4}
function Set:flatten ()
    local res = Set:new()
    for v in self:members() do
        if is_set(v) then
            res = res + v:flatten()
        else
            res:add{v}
        end
    end
    return res
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
--      > a = Set:new{1, 3, 5, 2, 4, 6, 8, 10, 5, 9, 7}
--      > r = a:sorted()
--      > table.concat(r, ', ')
--      1, 2, 3, 4, 5, 6, 7, 8, 9, 10
function Set:sorted (callable)
    local t = self:totable()
    table.sort(t, callable)
    return t
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
--      > a = Set:new{1, 2, 3}
--      > a:concat(', ')
--      1, 2, 3
function Set:concat (sep)
    return table.concat(self:totable(), sep)
end


--- Unpacks the members of the set.
--
-- @return The members of the given set unpacked.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > a:unpack()
--      1       2       3
function Set:unpack ()
    return table.unpack(self:totable())
end


--- Copies a set.
--
-- Copies are deep.
--
-- You should *never* need this function.
--
-- Instead of:
--
--      a = Set:new{1, 2, 3}
--      b = a:copy()
--      b:add{4}
--
-- Write:
--
--      a = Set:new{1, 2, 3}
--      b = a + Set:new{4}
--
-- @tparam Set set A set.
--
-- @return The same set, but a different instance.
--
-- @usage
--      > a = Set:new{1, 2, 3}
--      > r = a:copy()
--      > r
--      {1, 2, 3}
--      > a:add{4}
--      > r
--      {1, 2, 3}
function Set:copy ()
    local res = Set:new()
    res._members = copy(self._members)
    return res
end


--- n-ary set arithmetics
--
-- @section arithmetics

--- Tests whether two or more sets are disjoint.
--
-- @tparam {Set,...} sets A list of sets to compare.
--
-- @treturn boolean Whether the given sets are disjoint.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{1, 2}
--      > c = Set:new{2}
--      > d = Set:new{3}
--      > properset.are_disjoint{a, b, c}
--      false
--      > properset.are_disjoint{a, c, d}
--      true
function are_disjoint (sets)
    for i = 1, #sets do
        for j = i + 1, #sets do
            local s = intersection{sets[i], sets[j]}
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
--      > a = Set:new{1, 2}
--      > b = Set:new{2}
--      > properset.complement(a, b)
--      {1}
function complement (a, b)
    local res = Set:new()
    for i in a:members() do
        if not b:has_member(i) then res:add{i} end
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
--      > a = Set:new{1}
--      > b = Set:new{2}
--      > c = Set:new{3}
--      > properset.union{a, b, c}
--      {1, 2, 3}
function union (sets)
    local res = sets[1]:copy()
    for i = 2, #sets do res:add(sets[i]._members) end
    return res
end


--- The intersection of two or more sets.
--
-- @tparam {Set,...} sets A list of sets to intersect.
--
-- @treturn Set The intersection of the given sets.
--
-- @usage
--      > a = Set:new{1}
--      > b = Set:new{1,2}
--      > c = Set:new{2}
--      > d = Set:new{1,3}
--      > properset.intersection{a, b, c}
--      {}
--      > properset.intersection{a, b, d}
--      {1}
function intersection (sets)
    if #sets == 1 then
        return sets[1]
    elseif #sets > 1 then
        local res = sets[1]:copy()
        for i = 2, #sets do
            for j = #res._members, 1, -1 do
                if not sets[i]:has_member(res._members[j]) then
                    table.remove(res._members, j)
                end
            end
            if res:is_empty() then break end
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
--      > a = Set:new{1, 2}
--      > b = Set:new{1, 3}
--      > c = Set:new{1, 2, 3, 4}
--      > properset.difference{a, b, c}
--      {1, 4}
function difference (sets)
    local res = sets[1]:copy()
    for i = 2, #sets do
        res = complement(union{res, sets[i]}, intersection{res, sets[i]})
    end
    return res
end


--- Iterating over sets
--
-- @section iteration

--- Iterates over sets as if they were lists.
--
-- Unless you're building something fancy,
-- you'll want to use `Set:__ipairs` instead.
--
-- @tparam Set set The set to iterate over.
-- @tparam number i The current index.
--
-- @usage
--      > a = Set:new{'a', 'b', 'c'}
--      > for i, v in properset.nth_member, a, 0 do print(i, v) end
--      1       a
--      2       b
--      3       c
function nth_member(set, i)
    i = i + 1
    local v = set._members[i]
    if v then return i, v end
end


--- Iterates over sets as if they were tables.
--
-- Unless you're building something fancy,
-- you'll want to use `Set:__pairs` instead.
--
-- @tparam Set set The set to iterate over.
-- @tparam number k The current index.
--
-- @usage
--      > a = Set:new{'a', 'b', 'c'}
--      > for k, v in properset.next_member, a, nil do print(i, v) end
--      nil       a
--      nil       b
--      nil       c
function next_member(set, k)
    k, v = next(set._members, k)
    if v then return k, v end
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
--      > a = Set:new()
--      > properset.is_set(a)
--      true
--      > b = "I may be many things, but a Set I'm not."
--      > properset.is_set(b)
--      false
function is_set (obj)
    if type(obj) == 'table' then
        for k, v in pairs(Set) do
            if obj[k] == nil then return false end
        end
        return true
    end
    return false
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
--      > a = Set:new()
--      > properset.rank(a)
--      1
--      > b = Set:new{Set:new{Set:new{Set:new{}}, Set:new{}, 1}, 2}
--      > properset.rank(b)
--      4
function rank (obj)
    if not is_set(obj) then return 0 end
    local res = 1
    for v in obj:members() do
        if is_set(v) then
            r = rank(v) + 1
            if r > res then res = r end
        end
    end
    return res
end


--- Shorthand for creating sets.
--
-- Typing `Set:new{}` becomes tiresome quickly.
-- Hence this shorthand.
--
-- @tparam[opt] table members Objects.
--
-- @treturn Set A set, populated with `members`, if any were given.
--
-- @usage
--      > set = betterset.set
--      > a = set{1, 2, 3}
function set (members)
    return Set:new(members)
end


--- Copies a table recursively.
--
-- Handles metatables, recursive structures, tables as keys, metatables,
-- avoids the `__pairs` metemethod, and can handle instances of `Set`.
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
    if is_set(obj) then return obj:copy(true) end
    if seen and seen[obj] then return seen[obj] end
    local res = setmetatable({}, getmetatable(obj))
    seen = seen or {}
    seen[obj] = res
    for k, v in next, obj, nil do
        res[copy(k, deep, seen)] = copy(v, deep, seen)
    end
    return res
end


--- Useful constants
-- @section constants

--- The empty set.
-- @field emptyset The empty set (`Set:new{}`).
emptyset = Set:new()

return properset
