--- Performance tests for `properset`.
--
-- Requires `luaunit` and assumes that `luarocks` is installed.
--
-- @author Odin Kroeger
-- @copyright 2018 Odin Kroeger
-- @license MIT
-- @release 0.3-a0


-- Constants
-- =========

-- How many measurements to calculate the average of?
local RUNS = 5

-- Up to what size test making power sets?
local POWER_MAX = 16

-- Up to what rank (not size) test flattening sets?
local FLATTEN_MAX = 16

-- Up to what rank test converting sets to tables.
local TABLE_MAX = 16

-- At what size to start testing converting to strings?
local TOSTRING_MIN = math.floor(2^16)

-- Up to what size test converting to strings?
local TOSTRING_MAX = math.floor(2^20)


-- Boilerplate
-- ===========

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


--- Utility functions
-- @section functions

function measure(callable, n)
    n = n or RUNS
    local t = 0
    for j = 1, n do
        local s = os.clock()
        callable()
        local e = os.clock()
        t = t + e - s
    end
    return t/n
end

function report(name, n, t)
    print(string.format('%s() for n = %d: %.2f secs', name, n, t))
end

--- Tests
-- @section tests

function TestSetPower ()
    local a = Set:new()
    for i = 1, POWER_MAX do
        a:add{i}
        local t = measure(function() a:power() end)
        report('Set.power', i, t)
    end
end

function TestSetFlatten ()
    local a = Set:new()
    for i = 1, FLATTEN_MAX do
        a:add{a:copy(), i}
        local t = measure(function() a:flatten() end)
        report('Set.flatten', i, t)
    end
end

function TestSetToTable ()
    local a = Set:new()
    for i = 1, TABLE_MAX do
        a:add{a:copy(), i}
        local t = measure(function() a:totable() end)
        report('Set.totable', i, t)
    end
end

function TestSetToString ()
    local a = Set:new()
    for i = 0, TOSTRING_MAX, 16 do
        a:add{i+1, i+2, i+3, i+4, i+5, i+6, i+7, i+8,
            i+9, i+10, i+11, i+12, i+13, i+14, i+15, i+16}
        if i > 0 and (i + 16) % TOSTRING_MIN == 0 then
            local t = measure(function() a:__tostring() end)
            report('Set.__tostring', #a, t)
        end
    end
end

-- Backplate
-- =========

os.exit(lu.LuaUnit.run())
