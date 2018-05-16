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

function TestNew ()
    local a_set = Set:new{1, 2, 2, 3, 3, 3}
    local b_set = Set:new{1, 2, 3}
    local a_table = {1, 2, 3}
    lu.assertEquals(a_set, b_set)
    lu.assertEquals(a_set:unpack(), table.unpack(a_table))
    lu.assertEquals(tostring(a_set), '{1, 2, 3}')
end

function TestAccess ()
    local a = Set:new{1, 2, 3}
    lu.assertError(function () a[1] = 2 end)
    lu.assertError(function () a['b'] = 2 end)
end

function TestCardinality()
    local a = Set:new{1, 2, 3}
    lu.assertEquals(#a, 3)
end

function TestIterationMembers()
    local a = Set:new{1, 2, 3}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestIterationIpairs()
    local a = Set:new{1, 2, 3}
    local b = {}
    for _, v in ipairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestIterationPairs()
    local a = Set:new{1, 2, 3}
    local b = {}
    for _, v in pairs(a) do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3})
end

function TestAdd()
    local a = Set:new{1, 2, 3}
    a:add{4, 5}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1, 2, 3, 4, 5})
end

function TestDelete()
    local a = Set:new{1, 2, 3}
    a:delete{2, 3}
    local b = {}
    for v in a:members() do table.insert(b, v) end
    lu.assertItemsEquals(b, {1})
end

function TestIsEmpty()
    local a = Set:new()
    local b = Set:new{1}
    lu.assertIsTrue(a:is_empty())
    lu.assertIsTrue(properset.empty:is_empty())
    lu.assertEquals(#a, 0)
    lu.assertIsFalse(b:is_empty())
    lu.assertNotEquals(#b, 0)
end

function TestHasMember()
    local a = Set:new{1}
    lu.assertIsTrue(a:has_member(1))
    lu.assertIsFalse(a:has_member(2))
end

function TestSubset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertIsTrue(b:__le(a))
    lu.assertIsFalse(a:__le(b))
    lu.assertIsTrue(c:__le(a))
end

function TestSuperset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertIsTrue(a:__ge(b))
    lu.assertIsFalse(b:__ge(a))
    lu.assertIsTrue(a:__ge(c))
end

function TestStrictSubset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertIsTrue(b:__lt(a))
    lu.assertIsFalse(a:__lt(b))
    lu.assertIsFalse(c:__lt(a))
end

function TestStrictSuperset()
    local a = Set:new{1, 2}
    local b = Set:new{1}
    local c = Set:new{1, 2}
    lu.assertIsTrue(a:__gt(b))
    lu.assertIsFalse(b:__gt(a))
    lu.assertIsFalse(a:__gt(c))
end

function TestEquality()
    local a = Set:new{1, 2, 3}
    local b = Set:new{1, 2, 3}
    local c = Set:new{}
    lu.assertEquals(a, b)
    lu.assertEquals(b, a)
    lu.assertNotEquals(a, c)
    lu.assertNotEquals(c, a)
end

function TestDisjoint()
    local a = Set:new{1, 2}
    local b = Set:new{2, 3}
    local c = Set:new{3, 4}
    lu.assertIsFalse(a:is_disjoint_from(b))
    lu.assertIsFalse(b:is_disjoint_from(c))
    lu.assertIsFalse(b:is_disjoint_from(a))
    lu.assertIsFalse(c:is_disjoint_from(b))
    lu.assertIsTrue(a:is_disjoint_from(c))
    lu.assertIsTrue(c:is_disjoint_from(a))
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

os.exit(lu.LuaUnit.run())
