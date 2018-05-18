--- Test suite for `properset`.
--
-- Requires `luaunit` and assumes that `luarocks` is installed.
--
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT
-- @release 0.3-a0


-- Boilerplate
-- ===========

require "luarocks.loader"
lu = require 'luaunit'

do
    local path_sep = package.config:sub(1, 1)
    local script_dir = arg[0]:match('(.-)[\\/][^\\/]-$') or '.'
    package.path = package.path .. ';' ..
        table.concat({script_dir, '..', 'src', '?.lua'}, path_sep)
end

properset = require 'properset'
Set = properset.Set
emptyset = properset.emptyset


--- Constants
-- @section constants

---
-- @table CardinalEquality Metatable that provides an absurd equality function.
-- @field __eq The actual equality function.
CardinalEquality = {}
function CardinalEquality.__eq (a, b)
    return #a == #b
end

---
-- @table TableEquality Metatable that provides an simple equality function.
-- @field __eq The eactual equality function.
TableEquality = {}
function TableEquality.__eq (a, b)
    local function cmp(a, b, seen)
        if a == nil or b == nil then
            if a == nil and b == nil then return true end
            return false
        end
        seen = seen or {}
        for k, v in pairs(a) do
            if type(v) == 'table' then
                if not seen[v] then
                    seen[v] = true
                    if not cmp(v, b[k], seen) then return false end
                end
            else
                if b[k] ~= v then return false end
            end
        end
        return true
    end
    return cmp(a, b) and cmp(b, a)
end

---
-- @table TableNilIterator Metatable that fools `pairs`.
-- @field __pairs The actual iterator generator.
TableNilIterator = {}
function TableNilIterator.__pairs ()
    return function() end
end


--- A selection of tables for testing.
--
-- These tables will come in useful later.
--
-- @table sets
tables = {
    zer_e0_0 = {},
    num_e1_1 = {1, 2, 3},
    num_e1_2 = {5, 2, 3, 9},
    sim_e1_1 = {1, 2, 3, 'b', true, false},
    sim_e1_2 = {1, 2, 'x', false, 3, true},
    num_e3_0 = (function ()
        local t = {}
        for i = 1, 1000 do t[i] = i end
        return t
        end)(),
    tru_e0_0 = {true},
    fal_e0_0 = {false},
    bol_e1_1 = {true, false, true},
    str_e1_1 = {'a', 'b', 'c'},
    str_e2_0 = (function ()
        local t = {}
        for i = 33, 126 do t[i-32] = string.char(i) end
        return t
        end)(),
}

do
    local i = 0
    for k, v in pairs(tables) do
        i = i + 1
        tables['tab_e0_' .. i] = {v}
    end
end

tables.tab_e1_1 = {tables.num_e1_1, tables.sim_e1_2, tables.str_e1_1}
tables.tab_e1_2 = {tables.fal_e0_0, tables.str_e2_0, tables.sim_e1_1}
tables.tab_e1_3 = {tables.str_e1_1, tables.num_e3_0, tables.bol_e1_1}


--- Utility functions
-- @section utility

--- Tests whether a set of simples has all given members
--
-- @tparam Set set A set.
-- @tparam table ms A list of simples.
--
-- @treturn boolean Whether the set has all given members.
function simple_has_all (s, ms)
    for i = 1, #ms do
        if s._val.mem[ms[i]] == nil then return false end
    end
    return true
end


--- Tests whether a set of simples has only the given members
--
-- @tparam Set set A set.
-- @tparam table ms A list of simples.
--
-- @treturn boolean Whether the set has only the given members.
function simple_has_only (s, ms)
    for k in pairs(s._val.mem) do
        local found = false
        for i = 1, #ms do
            if ms[i] == k then
                found = true
                break
            end
        end
        if not found then return false end
    end
    return true
end


--- Converts string representation of sets to a table.
--
-- Flattens sets in the process.
-- Only supports string representions of sets of numbers.
--
-- @tparam string str A string representation of a set of numbers.
--
-- @treturn table A table with all numbers that were members of the set
--  (or of sets within the set).
local function strtotable(str)
    local res = {}
    for n in string.gmatch(str, '%d+') do res[#res + 1] = tonumber(n) end
    return res
end


--- Bootstrapping Tests
--
-- At first, I nned make sure that the datatype itself works as inteded.
--
-- Hence, I test the following basic behaviours:
--
--  * Creating new sets.
--  * Testing whether something is a set.
--  * Adding members.
--  * Iterating over sets.
--  * Testing for set membership.
--  * Counting the members of sets.
--  * Testing whether a set is a subset of another one.
--  * Testing whether two sets are equal.
--
-- All other operations on sets are built on these.
--
-- @section bootstrap

---
-- @table TestBootstrap Make sure that fundamental operations on sets work.
TestBootstrap = {}
    --- Tests whether new empty sets can be created.
    function TestBootstrap.TestSetNewEmpty ()
        local a = Set:new()

        -- I haven't yet tested behaviours,
        -- so I can't assume they're reliable.
        -- and start by testing the implementation.
        lu.assertItemsEquals(a._val, {mem = {}, len = 0})
        lu.assertItemsEquals(a._tab, {})
        lu.assertEquals(getmetatable(a), Set)

        -- But I should test behaviour, so I do that here:
        lu.assertEquals(#a, 0)
        lu.assertEquals(a, Set:new())
        lu.assertEquals(a, emptyset)
    end

    --- Tests whether sets and non-sets can be identified.
    function TestBootstrap.TestIsSet()
        local a = Set:new()

        -- These are basic operations.
        lu.assertTrue(properset.is_set(a))
        lu.assertFalse(properset.is_set(nil))
        lu.assertFalse(properset.is_set(0))
        lu.assertFalse(properset.is_set('also not a set.'))
        lu.assertFalse(properset.is_set(function() return nil end))
        lu.assertFalse(properset.is_set(tables.num_e1_1))

        -- Test prototyping.
        local b = {}
        setmetatable(b, {__index = a})
        lu.assertTrue(properset.is_set(b))

        -- Test sets of sets.
        local c = Set:new{a}
        lu.assertTrue(properset.is_set(a))
    end

    --- Tests whether adding to sets works, for simple elements.
    function TestBootstrap.TestSetAddSimple()
        local a = Set:new()

        -- Test whether items are added.
        -- Again, I'm testing the implementation only right now.
        a:add(tables.num_e1_1)
        local t = tables.num_e1_1

        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 3)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        a:add{1, 2, 2, 3, 3, 3, 'b', true, false, false, true, 'b', nil}
        local t = {1, 2, 3, 'b', true, false}
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 6)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(a, Set:new(tables.sim_e1_1))
        lu.assertEquals(#a, 6)

        -- Let's test for something weird.
        -- This should do nothing:
        local a = Set:new()
        local t = {}
        a:add{nil, nil, nil}
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 0)
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(a, Set:new{})
        lu.assertEquals(#a, 0)

        -- Test for large-ish numbers of items.
        local a = Set:new()
        local t = tables.num_e3_0
        a:add(t)
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 1000)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(#a, 1000)

        -- Test the other way round.
        local a = Set:new()
        for i = 1, 1000 do a:add{i} end
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(a._val.len, 1000)
        lu.assertEquals(#a, 1000)

        -- Let's see if sparse arrays are handled correctly.
        local a = Set:new()
        local t = {}
        t[9] = 'sparse'
        a:add(t)
        lu.assertTrue(simple_has_all(a, {'sparse'}))
        lu.assertTrue(simple_has_only(a, {'sparse'}))
        local a = Set:new()
        local t = {nil, nil, nil, 1}
        a:add(t)
        lu.assertTrue(simple_has_all(a, {1}))
        lu.assertTrue(simple_has_only(a, {1}))
    end

    -- Now that are sure simple sets can be created, it's time to test
    -- iteration, membership, counting, subsets and equalities for such sets.

    --- Tests whether iterating over sets of simples works.
    function TestBootstrap.TestSetMembersSimple()
        -- Test for numbers.
        local a = Set:new()
        local t = {}
        a:add(tables.num_e1_1)
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, tables.num_e1_1)
        lu.assertItemsEquals(a:totable(), tables.num_e1_1)

        local a = Set:new()
        local t = {}
        a:add(tables.num_e3_0)
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(tables.num_e3_0, t)
        lu.assertEquals(#t, 1000)
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)

        -- Tests for something very evil.
        local a = Set:new()
        local t = {}
        a:add{nil}
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, {})
        lu.assertItemsEquals(a:totable(), t)

        local a = Set:new()
        local t = {}
        for i = 1, 5 do a:add{nil} end
        for v in a:mems() do t[#t+1] = v end
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)

        -- Test for booleans.
        local a = Set:new()
        local t = {}
        a:add{true}
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, {true})
        lu.assertItemsEquals(a:totable(), t)

        local a = Set:new()
        local t = {}
        for i = 1, 5 do a:add{true} end
        for v in a:mems() do t[#t+1] = v end
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)

        local a = Set:new()
        local t = {}
        a:add{false}
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, {false})
        lu.assertItemsEquals(a:totable(), t)

        local a = Set:new()
        local t = {}
        for i = 1, 5 do a:add{false} end
        for v in a:mems() do t[#t+1] = v end
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)

        -- Test for strings.
        local a = Set:new()
        local t = {}
        a:add(tables.str_e1_1)
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, tables.str_e1_1)
        lu.assertItemsEquals(a:totable(), t)

        local a = Set:new()
        local t = {}
        a:add(tables.str_e2_0)
        for v in a:mems() do t[#t+1] = v end
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertItemsEquals(a:totable(), t)

        -- Test a combination of all of the above.
        local a = Set:new()
        local t = {}
        a:add(tables.sim_e1_2)
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, tables.sim_e1_2)
        lu.assertItemsEquals(a:totable(), tables.sim_e1_2)
    end

    --- Tests whether membership determination works.
    function TestBootstrap.TestSetHasMemberSimple()
        -- Test numbers.
        local a = Set:new()
        local t = {1, 2, 3}
        a:add(t)
        for i = 1, #t do lu.assertTrue(a:has(t[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end
        for _, k in ipairs{4, 5, 6} do lu.assertFalse(a:has(k)) end
        lu.assertFalse(a:has(nil))
        lu.assertFalse(a:has(true))
        lu.assertFalse(a:has(false))

        -- Test nil.
        local a = Set:new()
        local t = {nil, nil, nil}
        a:add(t)
        for i = 1, #t do lu.assertFalse(a:has(t[1])) end

        -- Test booleans.
        local a = Set:new()
        a:add{true}
        lu.assertTrue(a:has(true))
        lu.assertFalse(a:has(nil))
        lu.assertFalse(a:has(false))

        local a = Set:new()
        a:add{false}
        lu.assertTrue(a:has(false))
        lu.assertFalse(a:has(nil))
        lu.assertFalse(a:has(true))

        local a = Set:new()
        local t = {true, false, true}
        a:add(t)
        for i = 1, #t do lu.assertTrue(a:has(t[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end

        -- Test strings.
        local a = Set:new()
        local t = {'a', 'b', 'c'}
        a:add(t)
        for i = 1, #t do lu.assertTrue(a:has(t[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end
        for _, k in ipairs{'d', 'e'} do lu.assertFalse(a:has(k)) end
        lu.assertFalse(a:has(nil))
        lu.assertFalse(a:has(true))
        lu.assertFalse(a:has(false))

        -- Test a combination of all of the above.
        local a = Set:new()
        local t = {}
        a:add{1, 2, 'x', false, 3, true, nil, nil}
        for v in a:mems() do t[#t+1] = v end
        for i = 1, #t do lu.assertTrue(a:has(t[i])) end
        for _, k in pairs{'f', 9, 'z'} do lu.assertFalse(a:has(k)) end
    end

    --- Tests counting.
    function TestBootstrap.TestSetLenSimple()
        -- Start with something easy.
        lu.assertEquals(emptyset:__len(), 0)
        lu.assertEquals(#emptyset, 0)

        -- Let's do something more complicated.
        local a = Set:new()
        a:add{1, 2, 2, 3, 3, 3, 'b', true, false, false, true, 'b', nil}
        lu.assertEquals(a:__len(), 6)
        lu.assertEquals(#a, 6)

        -- Let's check that it counts correctly for large-ish numbers.
        local a = Set:new()
        a:add(tables.num_e3_0)
        lu.assertEquals(a:__len(), 1000)
        lu.assertEquals(#a, 1000)
    end

    --- Tests whether subsets are correctly identified.
    function TestBootstrap.TestSetLeSimple()
        -- Start off easy.
        local a = Set:new()
        local b = Set:new()

        lu.assertTrue(a:__le(b))
        lu.assertTrue(b:__le(a))
        lu.assertTrue(a <= b)
        lu.assertTrue(b <= a)

        -- Complicate things, with numbers.
        for i = 1, 10 do
            a:add{i}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        for i = 1, 9 do
            b:add{i}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        b:add{0}
        lu.assertFalse(b:__le(a))
        lu.assertFalse(b <= a)

        -- Test nil.
        local a = Set:new()
        local b = Set:new()

        a:add{nil}
        lu.assertTrue(b:__le(a))
        lu.assertTrue(a:__le(b))
        lu.assertTrue(b <= a)
        lu.assertTrue(a <= b)

        -- Test booleans.
        local a = Set:new()
        local b = Set:new()

        a:add{false}
        lu.assertTrue(b:__le(a))
        lu.assertFalse(a:__le(b))
        lu.assertTrue(b <= a)
        lu.assertFalse(a <= b)

        b:add{false}
        lu.assertTrue(b:__le(a))
        lu.assertTrue(a:__le(b))
        lu.assertTrue(b <= a)
        lu.assertTrue(a <= b)

        b:add{true}
        lu.assertFalse(b:__le(a))
        lu.assertFalse(b <= a)

        -- Test strings.
        local a = Set:new()
        local b = Set:new()

        for _, k in pairs{'a', 'b', 'c'} do
            a:add{k}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        for _, k in pairs{'a', 'b'} do
            b:add{k}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        b:add{'z'}
        lu.assertFalse(b:__le(a))
        lu.assertFalse(b <= a)

        -- Test a combination of all of the above.
        local a = Set:new()
        local b = Set:new()
        local c = Set:new()
        a:add{1, 2, 'x', false, 3, true, nil, nil}
        b:add{1, 'x', true}
        c:add{2, false}

        lu.assertTrue(b:__le(a))
        lu.assertTrue(b < a)
        lu.assertTrue(c:__le(a))
        lu.assertTrue(c < a)
        lu.assertFalse(a:__le(b))
        lu.assertFalse(a < b)
        lu.assertFalse(a:__le(c))
        lu.assertFalse(a < c)
        lu.assertFalse(b:__le(c))
        lu.assertFalse(b < c)
        lu.assertFalse(c:__le(b))
        lu.assertFalse(c < b)
    end

    --- Tests equality.
    function TestBootstrap.TestSetEqSimple()
        -- Start off easy.
        local a = Set:new()
        local b = Set:new()

        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        -- Complicate things, with numbers.
        for i = 1, 10 do
            a:add{i}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        for i = 1, 9 do
            b:add{i}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        b:add{10}
        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        -- Test nil.
        local a = Set:new()
        local b = Set:new()

        a:add{nil}
        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        -- Test booleans.
        local a = Set:new()
        local b = Set:new()

        a:add{false}
        lu.assertFalse(b:__eq(a))
        lu.assertFalse(a:__eq(b))
        lu.assertFalse(b == a)
        lu.assertFalse(a == b)
        lu.assertTrue(b ~= a)
        lu.assertTrue(a ~= b)

        b:add{false}
        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        b:add{true}
        lu.assertFalse(b:__eq(a))
        lu.assertFalse(a:__eq(b))
        lu.assertFalse(b == a)
        lu.assertFalse(a == b)
        lu.assertTrue(b ~= a)
        lu.assertTrue(a ~= b)

        local a = Set:new()
        local b = Set:new()

        a:add{true}
        lu.assertFalse(b:__eq(a))
        lu.assertFalse(a:__eq(b))
        lu.assertFalse(b == a)
        lu.assertFalse(a == b)
        lu.assertTrue(b ~= a)
        lu.assertTrue(a ~= b)

        b:add{true}
        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        b:add{false}
        lu.assertFalse(b:__eq(a))
        lu.assertFalse(a:__eq(b))
        lu.assertFalse(b == a)
        lu.assertFalse(a == b)
        lu.assertTrue(b ~= a)
        lu.assertTrue(a ~= b)

        -- Test strings.
        local a = Set:new()
        local b = Set:new()

        for _, k in pairs{'a', 'b', 'c'} do
            a:add{k}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        for _, k in pairs{'a', 'b'} do
            b:add{k}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        b:add{'c'}
        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        -- Test a combination of all of the above.
        local a = Set:new()
        local b = Set:new()
        local c = Set:new()
        a:add{1, 2, 'x', false, 3, true, nil, nil}
        b:add{1, 2, 'x', false, 3, true, nil, nil}
        c:add{2, false}

        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        lu.assertFalse(a:__eq(c))
        lu.assertFalse(c:__eq(a))
        lu.assertFalse(a == c)
        lu.assertFalse(c == a)
        lu.assertTrue(a ~= c)
        lu.assertTrue(c ~= a)

        lu.assertFalse(b:__eq(c))
        lu.assertFalse(c:__eq(b))
        lu.assertFalse(b == c)
        lu.assertFalse(c == b)
        lu.assertTrue(c ~= b)
        lu.assertTrue(b ~= c)
    end

    -- At this point, I can be sure that fundamental operations work.
    -- That means: The foundations are good. And, what is more,
    -- I can know use membership iterations, membershipts tests,
    -- equality tests and set size in tests, but only for sets of simples.

    --- Tests whether creating non-empty sets of simples works.
    function TestBootstrap.TestSetNewSimple()
        -- I start by testing the implementation.
        local a = Set:new(tables.num_e1_1)
        local b = Set:new()
        local t = tables.num_e1_1
        b:add(t)

        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 3)

        -- And some behaviour.
        lu.assertEquals(#a, 3)
        lu.assertEquals(a, b)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        local a = Set:new{1, 2, 2, 3, 3, 3, 'b',
            true, false, false, true, 'b', nil}
        local b = Set:new()
        local t = {1, 2, 3, 'b', true, false}
        b:add(t)

        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 6)

        lu.assertEquals(#a, 6)
        lu.assertEquals(a, b)

        -- Let's test for something weird.
        -- This should do nothing:
        local a = Set:new{nil, nil, nil}
        local t = {}
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 0)
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(a, Set:new{})
        lu.assertEquals(#a, 0)

        -- Test for large-ish numbers of items.
        local t = tables.num_e3_0
        local a = Set:new(t)
        lu.assertTrue(simple_has_all(a, t))
        lu.assertTrue(simple_has_only(a, t))
        lu.assertEquals(a._val.len, 1000)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(#a, 1000)

        -- Let's see if sparse arrays are handled correctly.
        local t = {}
        t[9] = 'sparse'
        local a = Set:new(t)
        lu.assertTrue(simple_has_all(a, {'sparse'}))
        lu.assertTrue(simple_has_only(a, {'sparse'}))
        local t = {nil, nil, nil, 1}
        local a = Set:new(t)
        lu.assertTrue(simple_has_all(a, {1}))
        lu.assertTrue(simple_has_only(a, {1}))
    end

    -- I'm done with testing the foundations for simples.
    -- Now I need to do the same thing for sets of tables and sets of sets.

    --- Tests whether adding to sets works, for tables.
    function TestBootstrap.TestSetAddTable()
        -- Test whether this confuses `add`.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new()
        a:add{{1}}
        local t = {{1}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new()
        a:add{{1}, {2}, {3}}
        local t = {{1}, {2}, {3}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        local a = Set:new()

        local t1 = setmetatable({1}, CardinalEquality)
        local t2 = setmetatable({2, 2}, CardinalEquality)
        local t3 = setmetatable({3, 3, 3}, CardinalEquality)

        a:add{t1, t2, t2, t3, t3, t3}
        local t = {t1, t2, t3}
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        local b = Set:new{t1, t2, t3}
        lu.assertItemsEquals(a:totable(), t)
        lu.assertItemsEquals(a, b)
        lu.assertTrue(a:__eq(b))
        lu.assertEquals(#a, 3)

        -- Test for large-ish numbers of items.
        local a = Set:new()
        local t = {}
        for i = 1, 100 do t[i] = {i} end
        a:add(t)
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(#a, 100)

        -- Test the other way round.
        local a = Set:new()
        for i = 1, 100 do a:add{{i}} end
        lu.assertEquals(a._tab, t)
        lu.assertEquals(#a, 100)
    end

    -- Now that are sure table sets can be created, it's time to test
    -- iteration, membership, counting, subsets and equalities for such sets.

    --- Tests whether iterating over sets of tables works.
    function TestBootstrap.TestSetMembersTable()
        local a = Set:new()
        local t = {}
        a:add{{1}, {2}, {3}}
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, {{1}, {2}, {3}})
        lu.assertItemsEquals(a:totable(), {{1}, {2}, {3}})

        local a = Set:new()
        local t = {}
        local u = {}
        for i = 1, 100 do a:add{{i}} end
        for i = 1, 100 do t[i] = {i} end
        for v in a:mems() do u[#u+1] = v end
        lu.assertItemsEquals(u, t)
        lu.assertItemsEquals(a:totable(), t)
        lu.assertItemsEquals(a:totable(), u)
    end

    --- Tests whether membership determination works.
    function TestBootstrap.TestSetHasMemberTable()
        local a = Set:new()
        local t = {{1}, {2}, {3}}
        a:add(t)
        for i = 1, #t do lu.assertTrue(a:has(t[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end
        for _, k in ipairs{{4}, {5}} do lu.assertFalse(a:has(k)) end
    end

    --- Tests counting.
    function TestBootstrap.TestSetLenTable()
        -- Let's do something more complicated.
        local a = Set:new()
        a:add{{1}, {2}, {3}}
        lu.assertEquals(a:__len(), 3)
        lu.assertEquals(#a, 3)

        -- Let's check that it counts correctly for large-ish numbers.
        local a = Set:new()
        local t = {}
        for i = 1, 1000 do t[i] = {i} end
        a:add(t)
        lu.assertEquals(a:__len(), 1000)
        lu.assertEquals(#a, 1000)
    end

    --- Tests whether subsets are correctly identified.
    function TestBootstrap.TestSetLeTable()
        local a = Set:new()
        local b = Set:new()

        lu.assertTrue(a:__le(b))
        lu.assertTrue(b:__le(a))
        lu.assertTrue(a <= b)
        lu.assertTrue(b <= a)

        for i = 1, 10 do
            local t = setmetatable({}, CardinalEquality)
            for j = 1, i do t[j] = j end
            a:add{t}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        for i = 1, 9 do
            local t = setmetatable({}, CardinalEquality)
            for j = 1, i do t[j] = j end
            b:add{t}
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        local t = setmetatable({}, CardinalEquality)
        b:add{t}

        lu.assertFalse(b:__le(a))
        lu.assertFalse(b <= a)
    end

    --- Tests equality.
    function TestBootstrap.TestSetEqTable()
        local a = Set:new()
        local b = Set:new()

        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)

        for i = 1, 10 do
            local t = setmetatable({}, CardinalEquality)
            for j = 1, i do t[j] = j end
            a:add{t}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        for i = 1, 9 do
            local t = setmetatable({}, CardinalEquality)
            for j = 1, i do t[j] = j end
            b:add{t}
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        local t = setmetatable({}, CardinalEquality)
        for j = 1, 10 do t[j] = j end
        b:add{t}

        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)
    end

    -- At this point, I can be sure that fundamental operations work.

    --- Tests whether creating non-empty sets of tables works.
    function TestBootstrap.TestSetNewTables()
        -- Test whether this confuses `new`.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new{{1}}
        local t = {{1}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new{{1}, {2}, {3}}
        local t = {{1}, {2}, {3}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        local t1 = setmetatable({1}, CardinalEquality)
        local t2 = setmetatable({2, 2}, CardinalEquality)
        local t3 = setmetatable({3, 3, 3}, CardinalEquality)
        local a = Set:new{t1, t2, t2, t3, t3, t3}
        local t = {t1, t2, t3}
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        local b = Set:new{t1, t2, t3}
        lu.assertItemsEquals(a:totable(), t)
        lu.assertItemsEquals(a, b)
        lu.assertTrue(a:__eq(b))
        lu.assertEquals(#a, 3)

        -- Test for large-ish numbers of items.
        local t = {}
        for i = 1, 100 do t[i] = {i} end
        local a = Set:new(t)
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(), t)
        lu.assertEquals(#a, 100)
    end

    -- I'm done with testing the foundations for sets of tables.
    -- Now I need to do the same thing for sets of sets; even though
    -- they are only a special case of sets for tables, better be safe
    -- than sorry.

    --- Tests whether adding to sets works, for sets.
    function TestBootstrap.TestSetAddSet()
        -- Test whether this confuses `add`.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new()
        a:add{Set:new{1}}
        local t = {Set:new{1}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new()
        a:add{Set:new{1}, Set:new{2}, Set:new{3}}
        local t = {Set:new{1}, Set:new{2}, Set:new{3}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        local a = Set:new()

        local s1 = Set:new{1}
        local s2 = Set:new{2}
        local s3 = Set:new{3}

        a:add{s1, s2, s2, s3, s3, s3}
        local t = {s1, s2, s3}
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        local b = Set:new{s1, s2, s3}
        lu.assertItemsEquals(a:totable(false), t)
        lu.assertItemsEquals(a, b)
        lu.assertTrue(a:__eq(b))
        lu.assertEquals(#a, 3)

        -- Test for large-ish numbers of items.
        local a = Set:new()
        local t = {}
        for i = 1, 100 do t[i] = Set:new{i} end
        a:add(t)
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(false), t)
        lu.assertEquals(#a, 100)

        -- Test the other way round.
        local a = Set:new()
        for i = 1, 100 do a:add{Set:new{i}} end
        lu.assertEquals(a._tab, t)
        lu.assertEquals(#a, 100)
    end

    -- Now that are sure sets of sets can be created, it's time to test
    -- iteration, membership, counting, subsets and equalities for such sets.

    --- Tests whether iterating over sets of tables works.
    function TestBootstrap.TestSetMembersSet()
        local a = Set:new()
        local t = {}
        a:add{Set:new{1}, Set:new{2}, Set:new{3}}
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, {Set:new{1}, Set:new{2}, Set:new{3}})
        lu.assertItemsEquals(a:totable(false),
            {Set:new{1}, Set:new{2}, Set:new{3}})

        local a = Set:new()
        local t = {}
        local u = {}
        for i = 1, 100 do a:add{Set:new{i}} end
        for i = 1, 100 do t[i] = Set:new{i} end
        for v in a:mems() do u[#u+1] = v end
        lu.assertItemsEquals(u, t)
        lu.assertItemsEquals(a:totable(false), t)
        lu.assertItemsEquals(a:totable(false), u)
    end

    --- Tests whether membership determination works.
    function TestBootstrap.TestSetHasMemberSet()
        local a = Set:new()
        local t = {Set:new{1}, Set:new{2}, Set:new{3}}
        a:add(t)
        for i = 1, #t do lu.assertTrue(a:has(t[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end
        for _, k in ipairs{Set:new{4}, Set:new{5}} do
            lu.assertFalse(a:has(k))
        end
    end

    --- Tests counting.
    function TestBootstrap.TestSetLenSet()
        -- Let's do something more complicated.
        local a = Set:new()
        a:add{Set:new{1}, Set:new{2}, Set:new{3}}
        lu.assertEquals(a:__len(), 3)
        lu.assertEquals(#a, 3)

        -- Let's check that it counts correctly for large-ish numbers.
        local a = Set:new()
        local t = {}
        for i = 1, 1000 do t[i] = Set:new{i} end
        a:add(t)
        lu.assertEquals(a:__len(), 1000)
        lu.assertEquals(#a, 1000)
    end

    --- Tests whether subsets are correctly identified.
    function TestBootstrap.TestSetLeSet()
        local a = Set:new()
        local b = Set:new()

        for i = 1, 10 do
            for j = 1, i do a:add{Set:new{j}} end
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        for i = 1, 9 do
            for j = 1, i do b:add{Set:new{j}} end
            lu.assertTrue(b:__le(a))
            lu.assertFalse(a:__le(b))
            lu.assertTrue(b <= a)
            lu.assertFalse(a <= b)
        end

        b:add{Set:new()}

        lu.assertFalse(b:__le(a))
        lu.assertFalse(b <= a)
    end

    --- Tests equality.
    function TestBootstrap.TestSetEqSet()
        local a = Set:new()
        local b = Set:new()

        for i = 1, 10 do
            for j = 1, i do a:add{Set:new{j}} end
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        for i = 1, 9 do
            for j = 1, i do b:add{Set:new{j}} end
            lu.assertFalse(b:__eq(a))
            lu.assertFalse(a:__eq(b))
            lu.assertFalse(b == a)
            lu.assertFalse(a == b)
            lu.assertTrue(b ~= a)
            lu.assertTrue(a ~= b)
        end

        b:add{Set:new{10}}

        lu.assertTrue(a:__eq(b))
        lu.assertTrue(b:__eq(a))
        lu.assertTrue(a == b)
        lu.assertTrue(b == a)
        lu.assertFalse(a ~= b)
        lu.assertFalse(b ~= a)
    end

    -- At this point, I can be sure that fundamental operations work.

    --- Tests whether creating non-empty sets of sets works.
    function TestBootstrap.TestSetNewSet()
        -- Test whether this confuses `add`.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new{Set:new{1}}
        local t = {Set:new{1}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added.
        -- Again, I'm testing the implementation only right now.
        local a = Set:new{Set:new{1}, Set:new{2}, Set:new{3}}
        local t = {Set:new{1}, Set:new{2}, Set:new{3}}
        lu.assertEquals(a._tab, t)

        -- Test whether items are added only once
        -- Still only testing the implementation.
        local s1 = Set:new{1}
        local s2 = Set:new{2}
        local s3 = Set:new{3}
        local a = Set:new{s1, s2, s2, s3, s3, s3}
        local t = {s1, s2, s3}
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        local b = Set:new{s1, s2, s3}
        lu.assertItemsEquals(a:totable(false), t)
        lu.assertItemsEquals(a, b)
        lu.assertTrue(a:__eq(b))
        lu.assertEquals(#a, 3)

        -- Test for large-ish numbers of items.
        local t = {}
        for i = 1, 100 do t[i] = Set:new{i} end
        local a = Set:new(t)
        lu.assertEquals(a._tab, t)

        -- Let's test behaviour.
        lu.assertItemsEquals(a:totable(false), t)
        lu.assertEquals(#a, 100)
    end

    -- I'm done with testing the foundations for sets of tables.
    -- Now I need to do the same thing for sets of all three
    -- types of elements.

    --- Tests whether adding to sets works, for arbitrary elements.
    function TestBootstrap.TestSetAdd()
        local a = Set:new()
        a:add{Set:new{1}, false, false, 1, Set:new{2}, {1}, {2}, 'a', 'a'}

        -- Test the implementation.
        lu.assertTrue(simple_has_all(a, {false, 1, 'a'}))
        lu.assertTrue(simple_has_only(a, {false, 1, 'a'}))
        lu.assertEquals(a._val.len, 3)
        lu.assertEquals(a._tab, {Set:new{1}, Set:new{2}, {1}, {2}})

        -- Let's test behaviour.
        lu.assertEquals(#a, 7)
        local t = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        lu.assertItemsEquals(a:totable(false), t)
        local b = Set:new()
        b:add(t)
        lu.assertItemsEquals(a, b)
    end

    -- Now that are sure sets of arbitrary elements can be created, it's time
    -- to test iteration, membership, counting, subsets and equalities for
    -- such sets.

    --- Tests whether iterating over sets of arbitrary elements works.
    function TestBootstrap.TestSetMembers()
        local m = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        local a = Set:new()
        local t = {}
        a:add(m)
        for v in a:mems() do t[#t+1] = v end
        lu.assertItemsEquals(t, m)
        lu.assertItemsEquals(a:totable(false), m)
    end

    --- Tests whether membership determination works.
    function TestBootstrap.TestSetHasMember()
        local m = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        local a = Set:new()
        a:add(m)
        for i = 1, #m do lu.assertTrue(a:has(m[1])) end
        for k in a:mems() do lu.assertTrue(a:has(k)) end
        for _, k in ipairs{Set:new{4}, {4}, true, 'z'} do
            lu.assertFalse(a:has(k))
        end
    end

    --- Tests counting.
    function TestBootstrap.TestSetLen()
        local m = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        local a = Set:new()
        a:add(m)
        lu.assertEquals(a:__len(), 7)
        lu.assertEquals(#a, 7)
    end

    --- Tests whether subsets are correctly identified.
    function TestBootstrap.TestSetLe()
        local m = {Set:new{1}, false, 1, Set:new{2}, 'x', 'a'}
        local n = {Set:new{1}, false, 1}
        local o = {Set:new{2}, 'x', 'a'}
        local a = Set:new()
        local b = Set:new()
        local c = Set:new()
        a:add(m)
        b:add(n)
        c:add(o)

        lu.assertTrue(a:__le(a))
        lu.assertTrue(b:__le(b))
        lu.assertTrue(c:__le(c))
        lu.assertTrue(a <= a)
        lu.assertTrue(b <= b)
        lu.assertTrue(c <= c)
        lu.assertTrue(b:__le(a))
        lu.assertTrue(c:__le(a))
        lu.assertTrue(b <= a)
        lu.assertTrue(c <= a)
        lu.assertFalse(a:__le(b))
        lu.assertFalse(a:__le(c))
        lu.assertFalse(a <= b)
        lu.assertFalse(a <= c)
        lu.assertFalse(b:__le(c))
        lu.assertFalse(c:__le(b))
        lu.assertFalse(b <= c)
        lu.assertFalse(c <= b)
    end

    --- Tests equality.
    function TestBootstrap.TestSetEq()
        local m = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        local n = {Set:new{1}, false, 1}
        local a = Set:new()
        local b = Set:new()
        local c = Set:new()
        a:add(m)
        b:add(n)
        c:add(n)
        lu.assertTrue(a:__eq(a))
        lu.assertTrue(b:__eq(b))
        lu.assertTrue(c:__eq(c))
        lu.assertTrue(c:__eq(b))
        lu.assertTrue(b:__eq(c))
        lu.assertTrue(a == a)
        lu.assertTrue(b == b)
        lu.assertTrue(c == c)
        lu.assertTrue(b == c)
        lu.assertTrue(c == b)
        lu.assertTrue(a ~= b)
        lu.assertTrue(b ~= a)
        lu.assertTrue(a ~= c)
        lu.assertTrue(c ~= a)
        lu.assertFalse(a ~= a)
        lu.assertFalse(b ~= b)
        lu.assertFalse(c ~= c)
        lu.assertFalse(b ~= c)
        lu.assertFalse(c ~= b)
        lu.assertFalse(a:__eq(b))
        lu.assertFalse(b:__eq(a))
        lu.assertFalse(a:__eq(c))
        lu.assertFalse(c:__eq(a))
        lu.assertFalse(a == b)
        lu.assertFalse(b == a)
        lu.assertFalse(c == a)
        lu.assertFalse(a == c)
    end

    -- At this point, I can be reasonably sure that the fundamental
    -- operations work.

    --- Tests whether creating non-empty sets with arbitrary elements works.
    function TestBootstrap.TestSetNew()
        local a = Set:new{Set:new{1}, false, false, 1, Set:new{2},
            {1}, {2}, 'a', 'a'}

        -- Test the implementation.
        lu.assertTrue(simple_has_all(a, {false, 1, 'a'}))
        lu.assertTrue(simple_has_only(a, {false, 1, 'a'}))
        lu.assertEquals(a._val.len, 3)
        lu.assertEquals(a._tab, {Set:new{1}, Set:new{2}, {1}, {2}})

        -- Let's test behaviour.
        lu.assertEquals(#a, 7)
        local t = {Set:new{1}, false, 1, Set:new{2}, {1}, {2}, 'a'}
        lu.assertItemsEquals(a:totable(false), t)
        local b = Set:new()
        b:add(t)
        lu.assertItemsEquals(a, b)

        -- Just more tests.
        for k, v in pairs(tables) do
            local s = Set:new(v)
            --lu.assertEquals(#v, #s)
            lu.assertItemsEquals(v, s:totable())
        end
    end


-- Now I can be reasonably sure that the operations needed to determine the
-- identity and the contents of sets work and can proceed with the remaining
-- tests.


--- More testing materials
-- @section tests

---
-- Sets for testing
-- At this point, it's reasonably sure that set creation works.
-- So let's create some sets for later.
--
-- @table sets
sets = {}
for k, v in pairs(tables) do sets[k] = Set:new(v) end


--- Test of core machinery
--
-- The following tests are of the core machinery, that is, either
-- behaviour that is useful for other tests (e.g., conversions),
-- or core parts that may not be relevant to users but are used
-- by other functions (`copy`, `Set.copy` and the `__pairs` and
-- `__ipairs` iterators).
--
-- @section machinery

---
-- `copy` and `set.copy` are used by the subsequent tests
-- by some operations, so they need to be tested first.
--
-- @table TestCopy
TestCopy = {}

    --- Test copying non-sets.
    function TestCopy.TestCopyNonSets()
        -- Test simple copies.
        for _, v in pairs(tables) do
            local t = properset.copy(v)
            lu.assertItemsEquals(t, v)
        end

        -- Test a nested table.
        local t = {1, 2, 3, {1, 2, 3, {4, 5, 6}}}
        local c = properset.copy(t)
        lu.assertItemsEquals(t, c)

        -- Test a self-referential table.
        local t = setmetatable({1, 2, 3}, TableEquality)
        t.t = t
        local c = properset.copy(t)
        lu.assertItemsEquals(c, t)

        -- Test a table that has another table as key.
        local t = setmetatable({1, 2, 3}, TableEquality)
        local u = {1, 2, 3, {4, 5, 6}}
        u[t] = 7
        local c = properset.copy(u)
        lu.assertItemsEquals(c, u)

        -- Test a table that overrides `__pairs`.
        local t = setmetatable({1, 2, 3}, TableNilIterator)
        local c = properset.copy(t)
        lu.assertItemsEquals(c, t)

        -- Test a table that does all of this.
        local t = setmetatable({1, 2, 3, {4, 5}},
            {__eq = TableEquality.__eq,
             __pairs = TableNilIterator.__pairs})
        local u = {1, 2, 3, {4, 5, 6}}
        t[u] = {1, 2, 3, {4, 5}}
        t.t = t
        local c = properset.copy(t)
        lu.assertItemsEquals(c, t)
    end

    --- Tests copying of sets.
    function TestCopy.TestSetCopy()
        -- Test if empty stays empty.
        local c = emptyset:copy()
        lu.assertEquals(c, emptyset)

        -- Test simple copies.
        for k, v in pairs(sets) do
            local s = v:copy()
            lu.assertItemsEquals(s, v)
        end

        -- Test a nested set.
        local a = Set:new{1, Set:new{2}, Set:new{3}}
        local c = a:copy()
        lu.assertItemsEquals(a, c)
    end

    --- Tests copying of sets with regular copy function.
    function TestCopy.TestCopySets()
        -- Test if empty stays empty.
        local c = properset.copy(emptyset)
        lu.assertEquals(c, emptyset)

        -- Test simple copies.
        for _, v in pairs(sets) do
            local s = properset.copy(v)
            lu.assertItemsEquals(s, v)
        end

        -- Test a nested set.
        local a = Set:new{1, Set:new{2}, Set:new{3}}
        local c = properset.copy(a)
        lu.assertItemsEquals(a, c)
    end


---
-- Conversion functions, as it happens, do not require fancy
-- machinery (e.g., `copy` or `Set.copy`); and they are useful
-- in testing because they allow to convert sets into other types.
--
-- @table TestConversion Make sure that conversion functions work.
TestConversion = {}

    --- Test conversion to tables.
    --
    -- I used `totable` above extensively.
    -- Now it's time at last to check whether
    -- it works (on the assumption that `Set:new` works.)
    function TestConversion.TestSetToTable()
        -- This doesn't test recursive construct, but a good variety of stuff.
        for k, v in pairs(sets) do
            lu.assertItemsEquals(v:totable(), tables[k])
        end

        -- Let's just check that recursive conversion works.
        local a = Set:new()
        local t = {}
        for i = 1, 100, 10 do
            local b = Set:new{i}
            local u = {i}
            for j = 1, 9 do
                b = Set:new{j+i, b}
                u = {j+i, u}
            end
            a:add{b}
            table.insert(t, u)
        end
        lu.assertItemsEquals(a:totable(), t)
    end

    --- Test conversion to strings.
    --
    -- It's good to be sure that string conversion shows the truth.
    function TestConversion.TestSetToString()
        -- Unfortunately, this tests sometimes fails only because
        -- the order of the elements in the set isn't stable.
        for k, v in pairs(sets) do
            if k:sub(1, 3) == 'num' then
                lu.assertItemsEquals(tables[k], strtotable(tostring(v)))
            end
        end

        -- Let's just check that recursive conversion works.
        local a = Set:new()
        for i = 1, 991, 10 do
            local b = Set:new{i}
            for j = 1, 9 do
                b = Set:new{j+i, b:copy()}
            end
            a:add{b}
        end
        local t = strtotable(tostring(a))
        lu.assertItemsEquals(tables.num_e3_0, t)
    end


---
-- Some functions are just shortcuts for converting a set to a table and
-- then calling a function from `table`. However `unpack` is an important
-- way to check the contents of a set; particularly if `__tostring`
-- doesn't suffice so these tests go first.
--
-- @table Tests for aable-ish functions
TestTable = {}

-- core utility methods (totable, unpack)
-- remaining iterators


-- access blocking

-- boolean operations
-- set manipulation

-- arithmetics
-- remaining methods
-- remaining functions

---
-- @table TestCoreUtilities Make sure that fundamental utility functions work.
--
-- These operations are:
--
-- *copy
--
-- All other operations on set are built on these.


-- MARK: old tests below:


function TestAccess ()
    local a = Set:new(tables.num_e1_1)
    lu.assertError(function () a[1] = 2 end)
    lu.assertError(function () a['b'] = 2 end)
end


function TestIterationIpairs()
    local a = Set:new(tables.num_e1_1)
    local b = {}
    for _, v in ipairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, tables.num_e1_1)
end

function TestIterationPairs()
    local a = Set:new(tables.num_e1_1)
    local b = {}
    for _, v in pairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, tables.num_e1_1)
end

function TestMap()
    local a = Set:new{1, 2, 3}
    local b = Set:new{2, 3, 4}
    local add = function(i) return i + 1 end
    lu.assertEquals(a:map(add), b)
end

function TestFilter()
    local a = Set:new{1, 2, 3, 4}
    local b = Set:new{2, 4}
    local even = function(i) return i % 2 == 0 end
    lu.assertEquals(a:filter(even), b)
end


function TestDelete()
    local a = Set:new{1, 2, 3}
    a:delete{2, 3}
    local b = {}
    for v in a:mems() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1})
end


function TestSuperset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertTrue(a:__ge(b))
    lu.assertFalse(b:__ge(a))
    lu.assertTrue(a:__ge(c))
end

function TestStrictSubset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertTrue(b:__lt(a))
    lu.assertFalse(a:__lt(b))
    lu.assertFalse(c:__lt(a))
end

function TestStrictSuperset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertTrue(a:__gt(b))
    lu.assertFalse(b:__gt(a))
    lu.assertFalse(a:__gt(c))
end


function TestDisjoint()
    local a = Set:new{1, 2}
    local b = Set:new{2, 3}
    local c = Set:new{3, 4}
    lu.assertFalse(a:is_disjoint_from(b))
    lu.assertFalse(b:is_disjoint_from(c))
    lu.assertFalse(b:is_disjoint_from(a))
    lu.assertFalse(c:is_disjoint_from(b))
    lu.assertTrue(a:is_disjoint_from(c))
    lu.assertTrue(c:is_disjoint_from(a))
end

function TestComplement()
    local a = Set:new{1, 2}
    local b = Set:new{2}
    local c = Set:new{1}
    lu.assertEquals(a - b, c)
end

function TestUnion()
    local a = Set:new{1, 2}
    local b = Set:new{3}
    local c = Set:new{1, 2, 3}
    lu.assertEquals(a + b, c)
end

function TestIntersection()
    local a = Set:new{1}
    local b = Set:new{1, 2}
    local c = Set:new{2}
    lu.assertEquals(a:intersection(b), Set:new{1})
    lu.assertEquals(a:intersection(c), Set:new())
    lu.assertEquals(b:intersection(c), Set:new{2})
    lu.assertEquals(b:intersection(a), Set:new{1})
    lu.assertEquals(c:intersection(a), Set:new())
    lu.assertEquals(c:intersection(b), Set:new{2})
end

function TestDifference()
    local a = Set:new{1, 2}
    local b = Set:new{1, 3}
    lu.assertEquals(a:difference(b), Set:new{2, 3})
end

function TestPower()
    local a = Set:new{0, 1}
    local b = Set:new{a, Set:new{0}, Set:new{1}, emptyset}
    lu.assertEquals(a:power(), b)
end

function TestRank()
    local a = Set:new{Set:new{Set:new{}}}
    lu.assertEquals(a:rank(), 3)
end

function TestRankN()
    local a = Set:new{1, Set:new{2, Set:new{3, 4}, Set:new{5}}, Set:new{6}}
    lu.assertEquals(a:of_rankn(0), Set:new{1})
    lu.assertEquals(a:of_rankn(1), Set:new{Set:new{6}})
    lu.assertEquals(a:of_rankn(2), Set:new{Set:new{2,
        Set:new{3, 4}, Set:new{5}}})
    lu.assertEquals(a:of_rankn(3), emptyset)
    lu.assertEquals(a:of_rankn(0, true), Set:new{1, 2, 3, 4, 5, 6})
    lu.assertEquals(a:of_rankn(1, true), Set:new{Set:new{3, 4},
        Set:new{5}, Set:new{6}})
    lu.assertEquals(a:of_rankn(2, true), Set:new{Set:new{2,
        Set:new{3, 4}, Set:new{5}}})
    lu.assertEquals(a:of_rankn(3, true), emptyset)

end

function TestLevelN()
    local a = Set:new{1, Set:new{2, Set:new{3, 4}, Set:new{5}}, Set:new{6}}
    lu.assertEquals(a:at_leveln(1), Set:new{1, Set:new{2, Set:new{3, 4},
        Set:new{5}}, Set:new{6}})
    lu.assertEquals(a:at_leveln(2), Set:new{2, Set:new{3, 4}, Set:new{5}, 6})
    lu.assertEquals(a:at_leveln(3), Set:new{3, 4, 5})
    lu.assertEquals(a:at_leveln(4), emptyset)
end

function TestFlatten()
    local a = Set:new{1, Set:new{2, Set:new{5, Set:new{6}}, 3}, 4}
    local b = a:power()
    lu.assertEquals(b:flatten(), Set:new{1, 2, 3, 4, 5, 6})
end

function TestSorted()
    local a = Set:new{1, 3, 5, 2, 4, 6, 8, 10, 5, 9, 7}
    lu.assertItemsEquals(a:sorted(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
end

function TestConcatenate()
    local a = Set:new{1, 2, 3, 4}
    lu.assertEquals(a:concat(), '1234')
    lu.assertEquals(a:concat(', '), '1, 2, 3, 4')
end

function TestUnpack()
    local a = Set:new{1, 2, 3, 4}
    local x, y, z = a:unpack()
    lu.assertEquals(x, 1)
    lu.assertEquals(y, 2)
    lu.assertEquals(z, 3)
end


function TestNDisjoint()
    local a = Set:new{1}
    local b = Set:new{1, 2}
    local c = Set:new{2}
    local d = Set:new{3}
    lu.assertFalse(properset.are_disjoint{a, b, c})
    lu.assertTrue(properset.are_disjoint{a, c, d})
end

function TestNUnion()
    local a = Set:new{1}
    local b = Set:new{2}
    local c = Set:new{3}
    local d = properset.union{a, b, c}
    lu.assertEquals(d, Set:new{1, 2, 3})
end

function TestNIntersection()
    local a = Set:new{1}
    local b = Set:new{1, 2}
    local c = Set:new{2}
    local d = Set:new{1, 3}
    lu.assertEquals(properset.intersection{a, b, c}, emptyset)
    lu.assertEquals(properset.intersection{a, b, d}, Set:new{1})
end

function TestNDifference()
    local a = Set:new{1, 2}
    local b = Set:new{1, 3}
    local c = Set:new{1, 2, 3, 4}
    lu.assertEquals(properset.difference{a, b, c}, Set:new{1, 4})
end


function TestAssertSet()
    local a = Set:new{1}
    lu.assertError(function() return properset.assert_set(0) end)
    lu.assertTrue(pcall(function() return properset.assert_set(a) end))
end

function TestRankF()
    local a = 0
    local b = Set:new{}
    local c = Set:new{b}
    local d = Set:new{c}
    local e = Set:new{d}
    lu.assertEquals(properset.rank(a), 0)
    lu.assertEquals(properset.rank(b), 1)
    lu.assertEquals(properset.rank(c), 2)
    lu.assertEquals(properset.rank(d), 3)
    lu.assertEquals(properset.rank(e), 4)
end




function TestEmptySet()
    lu.assertEquals(#emptyset, 0)
    lu.assertEquals(emptyset, Set:new())
end


-- Backplate
-- =========

os.exit(lu.LuaUnit.run())
