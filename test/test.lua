require "luarocks.loader"
local lu = require 'luaunit'

do
    local path_sep = package.config:sub(1, 1)
    local script_dir = arg[0]:match('(.-)[\\/][^\\/]-$') or '.'
    package.path = package.path .. ';' ..
        table.concat({script_dir, '..', 'src', '?.lua'}, path_sep)
end

local properset = require 'properset'
local Set = properset.Set
local set = properset.set
local emptyset = properset.emptyset

function TestNew ()
    local a_set = Set:new{1, 2, 2, 3, 3, 3}
    local b_set = Set:new{1, 2, 3}
    local a_table = {1, 2, 3}
    lu.assertEquals(a_set, b_set)
    lu.assertEquals(a_set:unpack(), table.unpack(a_table))
    lu.assertEquals(tostring(a_set), '{1, 2, 3}')
    local a_set = set{1, 2, 2, 3, 3, 3}
    local b_set = set{1, 2, 3}
    local a_table = {1, 2, 3}
    lu.assertEquals(a_set, b_set)
    lu.assertEquals(a_set:unpack(), table.unpack(a_table))
    lu.assertEquals(tostring(a_set), '{1, 2, 3}')
end

function TestAccess ()
    local a = set{1, 2, 3}
    lu.assertError(function () a[1] = 2 end)
    lu.assertError(function () a['b'] = 2 end)
end

function TestCardinality()
    local a = set{1, 2, 3}
    lu.assertEquals(#a, 3)
end

function TestIterationMembers()
    local a = set{1, 2, 3}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestIterationIpairs()
    local a = set{1, 2, 3}
    local b = {}
    for _, v in ipairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestIterationPairs()
    local a = set{1, 2, 3}
    local b = {}
    for _, v in pairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestMap()
    local a = set{1, 2, 3}
    local b = set{2, 3, 4}
    local add = function(i) return i + 1 end
    lu.assertEquals(a:map(add), b)
end

function TestFilter()
    local a = set{1, 2, 3, 4}
    local b = set{2, 4}
    local even = function(i) return i % 2 == 0 end
    lu.assertEquals(a:filter(even), b)
end

function TestAdd()
    local a = set{1, 2, 3}
    a:add{4, 5}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3, 4, 5})
end

function TestDelete()
    local a = set{1, 2, 3}
    a:delete{2, 3}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1})
end

function TestIsEmpty()
    local a = set()
    local b = set{1}
    lu.assertIsTrue(a:is_empty())
    lu.assertIsTrue(emptyset:is_empty())
    lu.assertEquals(#a, 0)
    lu.assertIsFalse(b:is_empty())
    lu.assertNotEquals(#b, 0)
end

function TestHasMember()
    local a = set{1}
    lu.assertIsTrue(a:has_member(1))
    lu.assertIsFalse(a:has_member(2))
end

function TestSubset()
    local a = set{1, 2}
    local b = set{1}
    local c = set{1, 2}
    lu.assertIsTrue(b:__le(a))
    lu.assertIsFalse(a:__le(b))
    lu.assertIsTrue(c:__le(a))
end

function TestSuperset()
    local a = set{1, 2}
    local b = set{1}
    local c = set{1, 2}
    lu.assertIsTrue(a:__ge(b))
    lu.assertIsFalse(b:__ge(a))
    lu.assertIsTrue(a:__ge(c))
end

function TestStrictSubset()
    local a = set{1, 2}
    local b = set{1}
    local c = set{1, 2}
    lu.assertIsTrue(b:__lt(a))
    lu.assertIsFalse(a:__lt(b))
    lu.assertIsFalse(c:__lt(a))
end

function TestStrictSuperset()
    local a = set{1, 2}
    local b = set{1}
    local c = set{1, 2}
    lu.assertIsTrue(a:__gt(b))
    lu.assertIsFalse(b:__gt(a))
    lu.assertIsFalse(a:__gt(c))
end

function TestEquality()
    local a = set{1, 2, 3}
    local b = set{3, 1, 2}
    local c = set{1, 2}
    lu.assertEquals(a, b)
    lu.assertEquals(b, a)
    lu.assertNotEquals(a, c)
    lu.assertNotEquals(c, a)
end

function TestDisjoint()
    local a = set{1, 2}
    local b = set{2, 3}
    local c = set{3, 4}
    lu.assertIsFalse(a:is_disjoint_from(b))
    lu.assertIsFalse(b:is_disjoint_from(c))
    lu.assertIsFalse(b:is_disjoint_from(a))
    lu.assertIsFalse(c:is_disjoint_from(b))
    lu.assertIsTrue(a:is_disjoint_from(c))
    lu.assertIsTrue(c:is_disjoint_from(a))
end

function TestComplement()
    local a = set{1, 2}
    local b = set{2}
    local c = set{1}
    lu.assertEquals(a - b, c)
end

function TestUnion()
    local a = set{1, 2}
    local b = set{3}
    local c = set{1, 2, 3}
    lu.assertEquals(a + b, c)
end

function TestIntersection()
    local a = set{1}
    local b = set{1, 2}
    local c = set{2}
    lu.assertEquals(a:intersection(b), set{1})
    lu.assertEquals(a:intersection(c), set())
    lu.assertEquals(b:intersection(c), set{2})
    lu.assertEquals(b:intersection(a), set{1})
    lu.assertEquals(c:intersection(a), set())
    lu.assertEquals(c:intersection(b), set{2})
end

function TestDifference()
    local a = set{1, 2}
    local b = set{1, 3}
    lu.assertEquals(a:difference(b), set{2, 3})
end

function TestPower()
    local a = set{0, 1}
    local b = set{a, set{0}, set{1}, emptyset}
    lu.assertEquals(a:power(), b)
end

function TestRank()
    local a = set{set{set{}}}
    lu.assertEquals(a:rank(), 3)
end

function TestRankN()
    local a = set{1, set{2, set{3, 4}, set{5}}, set{6}}
    lu.assertEquals(a:of_rankn(0), set{1})
    lu.assertEquals(a:of_rankn(1), set{set{6}})
    lu.assertEquals(a:of_rankn(2), set{set{2,
        set{3, 4}, set{5}}})
    lu.assertEquals(a:of_rankn(3), emptyset)
    lu.assertEquals(a:of_rankn(0, true), set{1, 2, 3, 4, 5, 6})
    lu.assertEquals(a:of_rankn(1, true), set{set{3, 4},
        set{5}, set{6}})
    lu.assertEquals(a:of_rankn(2, true), set{set{2,
        set{3, 4}, set{5}}})
    lu.assertEquals(a:of_rankn(3, true), emptyset)

end

function TestLevelN()
    local a = set{1, set{2, set{3, 4}, set{5}}, set{6}}
    lu.assertEquals(a:at_leveln(1), set{1, set{2, set{3, 4}, set{5}}, set{6}})
    lu.assertEquals(a:at_leveln(2), set{2, set{3, 4}, set{5}, 6})
    lu.assertEquals(a:at_leveln(3), set{3, 4, 5})
    lu.assertEquals(a:at_leveln(4), emptyset)
end

function TestToString()
    local a = set{1, 2, set{3, 4}}
    lu.assertEquals(tostring(a), '{1, 2, {3, 4}}')
end

function TestToTable()
    local a = set{1, 2, 3, 4}
    lu.assertItemsEquals(a:totable(), {1, 2, 3, 4})
end

function TestFlatten()
    local a = set{1, set{2, set{5, set{6}}, 3}, 4}
    local b = a:power()
    lu.assertEquals(b:flatten(), set{1, 2, 3, 4, 5, 6})
end

function TestSorted()
    local a = set{1, 3, 5, 2, 4, 6, 8, 10, 5, 9, 7}
    lu.assertItemsEquals(a:sorted(), {1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
end

function TestConcatenate()
    local a = set{1, 2, 3, 4}
    lu.assertEquals(a:concat(), '1234')
    lu.assertEquals(a:concat(', '), '1, 2, 3, 4')
end

function TestUnpack()
    local a = set{1, 2, 3, 4}
    local x, y, z = a:unpack()
    lu.assertEquals(x, 1)
    lu.assertEquals(y, 2)
    lu.assertEquals(z, 3)
end

function TestSetCopy()
    local a = set{1, 2, 3, 4, 5}
    local b = a:power()
    local c = b:copy()
    lu.assertEquals(b, c)
    b:add{1}
    lu.assertNotEquals(b, c)
end

function TestNDisjoint()
    local a = set{1}
    local b = set{1, 2}
    local c = set{2}
    local d = set{3}
    lu.assertFalse(properset.are_disjoint{a, b, c})
    lu.assertTrue(properset.are_disjoint{a, c, d})
end

function TestNUnion()
    local a = set{1}
    local b = set{2}
    local c = set{3}
    local d = properset.union{a, b, c}
    lu.assertEquals(d, set{1, 2, 3})
end

function TestNIntersection()
    local a = set{1}
    local b = set{1, 2}
    local c = set{2}
    local d = set{1, 3}
    lu.assertEquals(properset.intersection{a, b, c}, emptyset)
    lu.assertEquals(properset.intersection{a, b, d}, set{1})
end

function TestNDifference()
    local a = set{1, 2}
    local b = set{1, 3}
    local c = set{1, 2, 3, 4}
    lu.assertEquals(properset.difference{a, b, c}, set{1, 4})
end

function TestIPairIterator()
    local a = set{'a', 'b', 'c'}
    local t = {}
    for i, v in properset.nth_member, a, 0 do t[i] = v end
    lu.assertItemsEquals(t, {'a', 'b', 'c'})
end

function TestPairIterator()
    local a = set{'a', 'b', 'c'}
    local t = {}
    for k, v in properset.next_member, a, nil do table.insert(t, v) end
    lu.assertItemsEquals(t, {'a', 'b', 'c'})
end

function TestIsSet()
    local a = set{1}
    lu.assertTrue(properset.is_set(a))
    lu.assertFalse(properset.is_set(0))
end

function TestAssertSet()
    local a = set{1}
    lu.assertError(function() return properset.assert_set(0) end)
    lu.assertTrue(pcall(function() return properset.assert_set(a) end))
end

function TestRankF()
    local a = 0
    local b = set{}
    local c = set{b}
    local d = set{c}
    local e = set{d}
    lu.assertEquals(properset.rank(a), 0)
    lu.assertEquals(properset.rank(b), 1)
    lu.assertEquals(properset.rank(c), 2)
    lu.assertEquals(properset.rank(d), 3)
    lu.assertEquals(properset.rank(e), 4)
end

function TestSetShorthand()
    lu.assertEquals(Set:new{}, set{})
    lu.assertEquals(set{}, emptyset)
end

function TestCopy()
    local a = {a = 0, b = 1, c = 2, d = 3}
    a.a = a
    local b = properset.copy(a)
    b.a = a
    local c = {1, 2, {3, 4, {5, 6, {7, 8}}}}
    local d = properset.copy(c)
    lu.assertItemsEquals(b, a)
    lu.assertEquals(c, d)
end

function TestEmptySet()
    lu.assertEquals(#emptyset, 0)
    lu.assertEquals(emptyset, set{})
end

os.exit(lu.LuaUnit.run())
