-- aaden
-- physics based esolang :P

local debug = false

local output = ""

local oldprint = print
local print = io.write

local f = io.open(arg[1], "r")
local field = f:read("*all")
f:close()

local running = true

local olderror = error

function error(s)
    io.stderr:write(s.."\n") -- stderr moment
    os.exit(1)
end

_G.string.split = function(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end
string.split("Hi there fella!", " ") -- lol leftover code from like a while ago

_G.math.sign = function(n, zerosign)
    if zerosign == nil then
        zerosign = 1
    end
    if n < 0 then
        return -1
    elseif n > 0 then
        return 1
    end
    return zerosign
end

local lines = string.split(field, "\r\n")
local width = string.len(lines[1])
local height = #lines

for i,v in ipairs(lines) do
    if string.len(v) ~= width then
        error("The width of the playing field is inconsistent. First inconsistency found at: Line "..i..".")
    end
    if string.sub(lines[i], 1, 1) ~= "|" then
        error("Line "..i.." is missing the \"|\" character at the start.")
    end
    if string.sub(lines[i], -1, -1) ~= "#" then
        error("Line "..i.." is missing the \"#\" character at the end.")
    end
end

local pos = {
    x = 0,
    y = 0
}

local foundspawn = false

for i,v in pairs(lines) do
    if string.find(v, "o") ~= nil then
        local instr = false
        for j=1, #v do
            if string.sub(v, j, j) == "\"" then instr = not instr end
            if string.sub(v, j, j) == "o" and not instr then pos.x = j - 1 pos.y = i - 1 foundspawn = true break end
        end
    end
    
    if foundspawn then break end
end

if not foundspawn then
    error("No marble spawnpoint has been found. You need to create one using the \"o\" command.")
end

local vel = {
    x = 0,
    y = 0
}
-- local a = "\\"

-- local objects = "H|#"..string.char(92)..".=-"

for i,v in ipairs(lines) do
    if #string.split(v, "\"") % 2 ~= 1 then
        error("Line "..i.." has one or more incomplete string(s).")
    end
end

local stack = {
    [1] = {},
    [2] = {},
    [3] = {},
}
local stackpointer = 1

local function showstack()
    local s = ""
    for i,v in ipairs(stack) do
        if stackpointer == i then
            s = s.."> "
        end
        s = s.."Stack "..i..": "
        for _,t in ipairs(v) do
            if t > 31 and t < 256 then
                s = s..t.." ("..string.byte(t)..")\t"
            elseif t > -1 and t < 32 then
                local list = {"NUL", "SOH", "STX", "ETX", "EOT", "ENQ", "ACK", "BEL", "BS", "TAB", "LF", "VT", "DD", "CR", "SO", "SI", "DLE", "DC1", "DC2", "DC3", "DC4", "NAK", "SYN", "ETB", "CAN", "EM", "SUB", "ESC", "FS", "GS", "RS", "US"}
                s = s..t.." ("..list[t+1]..")\t"
            else
                s = s..t.."\t"
            end
        end
        s = s.."\n"
    end
    return string.sub(s, 1, -2)
end

function push(stacknum, num)
    stack[stacknum][#stack[stacknum]+1] = num
end

function pop(stacknum, degree)
    if #stack[stacknum] == 0 then
        error("Attempted to pop from stack "..stacknum..", which is an empty stack. Position: ("..pos.x..", "..pos.y..")")
    end

    if degree == nil then
        degree = 1
    end
    for _=1, degree do
        stack[stacknum][#stack[stacknum]] = nil
    end
end

function retrieve(stacknum, place)
    if place == nil then
        place = #stack[stacknum]
    else
        place = #stack[stacknum] - (place - 1)
    end

    if stack[stacknum][place] == nil then
        error("Attempted to get value "..place.." from stack "..stacknum..", which has a length of "..#stack[stacknum]..". Position: ("..pos.x..", "..pos.y..")\n"..showstack())
    end

    return stack[stacknum][place]
end

local collisions = {
    ["35"] = function() -- #
        os.exit()
    end,
    ["124"] = function() -- -
        vel.x = vel.x * -1
    end,
    ["45"] = function() -- |
        vel.y = vel.y * -1
    end,
    ["72"] = function() -- H
        vel.x = 0
        vel.y = math.sign(vel.y)
    end,
    ["61"] = function() -- =
        vel.y = 0
        vel.x = math.sign(vel.x)
    end,
    ["92"] = function() -- \
        if math.sign(vel.y, -1) == 1 then
            vel.x = 1
            vel.y = -1
        else
            vel.x = -1
            vel.y = 1
        end
    end,
    ["47"] = function() -- /
        if math.sign(vel.y, -1) == 1 then
            vel.x = -1
            vel.y = -1
        else
            vel.x = 1
            vel.y = 1
        end
    end,
    ["46"] = function() -- .
        if #string.split(lines[pos.y + 1], "\"") == 1 then
            if not debug then
                print("\n")
            else
                output = output.."\n"
            end
        else
            local split = string.split(string.sub(lines[pos.y + 1], pos.x + 1, -1), "\"")
            for i=1, #split, 2 do
                if string.find(split[i], "%.") ~= nil then
                    if not debug then
                        if split[i+1] ~= nil and string.find(split[i], "%.") == string.len(split[i]) then
                            print(split[i+1])
                        else
                            print("\n")
                        end
                    else
                        if split[i+1] ~= nil and string.find(split[i], "%.") == string.len(split[i]) then
                            output = output..split[i+1]
                        else
                            output = output.."\n"
                        end
                    end
                    break
                end
            end
        end
    end,
    ["48"] = function() -- 0 - 9
        push(stackpointer, tonumber(string.sub(lines[pos.y + 1], pos.x + 1, pos.x + 1)))
    end,
    ["94"] = function() -- ^
        pop(stackpointer)
    end,
    ["126"] = function() -- ~
        push(stackpointer, retrieve(stackpointer))
    end,
    ["42"] = function() -- *
        local num = retrieve(stackpointer, 2) * retrieve(stackpointer)
        pop(stackpointer, 2)
        push(stackpointer, num)
    end,
    ["37"] = function() -- %
        local num = retrieve(stackpointer, 2) % retrieve(stackpointer)
        pop(stackpointer, 2)
        push(stackpointer, num)
    end,
    ["43"] = function() -- +
        local num = retrieve(stackpointer, 2) + retrieve(stackpointer)
        pop(stackpointer, 2)
        push(stackpointer, num)
    end,
    ["58"] = function() -- :
        if not debug then
            print(string.char(retrieve(stackpointer)))
        else
            output = output..string.char(retrieve(stackpointer))
        end
        pop(stackpointer)
    end,
    ["59"] = function() -- ;
        if not debug then
            print(tostring(retrieve(stackpointer)))
        else
            output = output..tostring(retrieve(stackpointer))
        end
        pop(stackpointer)
    end,
    ["33"] = function() -- !
        local num = retrieve(stackpointer) * -1
        pop(stackpointer)
        push(stackpointer, num)
    end,
    ["44"] = function() -- ,
        if stackpointer == 1 then
            oldprint("Please input a number here: ")
            local input
            repeat
                input = io.read("*n")
            until tonumber(input) ~= nil
            push(stackpointer, input)
        elseif stackpointer == 2 then
            oldprint("Please input an ASCII character here: ")
            local input
            repeat
                input = io.read()
            until input ~= nil
            push(stackpointer, string.byte(input))
        else
            oldprint("You can only use the \",\" command when selecting stacks 1-2.")
        end
    end,
    ["60"] = function() -- <
        if retrieve(stackpointer, 2) >= retrieve(stackpointer) then
            vel.y = vel.y * -1
        end
    end,
    ["62"] = function() -- >
        if retrieve(stackpointer, 2) <= retrieve(stackpointer) then
            vel.y = vel.y * -1
        end
    end,
    ["95"] = function() -- _
        local a = retrieve(stackpointer)
        pop(stackpointer)
        local b = retrieve(stackpointer)
        pop(stackpointer)
        push(stackpointer, a)
        push(stackpointer, b)
    end,
    ["64"] = function() -- @
        local num = tonumber(tostring(retrieve(stackpointer, 2))..tostring(retrieve(stackpointer)))
        pop(stackpointer)
        pop(stackpointer)
        push(stackpointer, num)
    end,
    ["38"] = function() -- &
        local split = retrieve(stackpointer)
        local original = retrieve(stackpointer, 2)
        pop(stackpointer)
        pop(stackpointer)
        push(stackpointer, tonumber(string.split(tostring(original), 1, split)))
        push(stackpointer, tonumber(string.split(tostring(original), split + 1, -1)))
    end,
    ["91"] = function() -- [
        push(((stackpointer - 2) % 3) + 1, retrieve(stackpointer))
        pop(stackpointer)
    end,
    ["93"] = function() -- ]
        push(math.max((stackpointer + 1) % 4, 1), retrieve(stackpointer))
        pop(stackpointer)
    end,
    ["123"] = function() -- {
        stackpointer = ((stackpointer - 2) % 3) + 1
    end,
    ["125"] = function() -- }
        stackpointer = math.max((stackpointer + 1) % 4, 1)
    end,
}

for i=49, 57 do
    collisions[tostring(i)] = collisions["48"]
end

--[[
if debug then
    oldprint("This is the output.\n^^^ OUTPUT ^^^\nvvv Playing Field vvv\n|THIS IS THE PLAYING FIELD o#\n|THIS IS THE PLAYING FIELD \\#\nStack: This\tIs\tThe\tStack\nPress enter to step once\n\n")
end
]]

while running do
    if debug then
        io.read()
    end

    if pos.y == height then
        error("The marble fell to the bottom... Position: ("..pos.x..", "..pos.y..")")
    end
    if pos.y == -1 then
        error("The marble went too high... Position: ("..pos.x..", "..pos.y..")")
    end
    local funct = "0"
    for i,v in pairs(collisions) do
        if tonumber(i) == string.byte(string.sub(lines[pos.y + 1], pos.x + 1, pos.x + 1)) then
            local instring = false
            local incomment = false

            for a=1, pos.x + 1 do
                if string.sub(lines[pos.y + 1], a, a) == "\"" and not incomment then
                    instring = not instring
                elseif string.sub(lines[pos.y + 1], a, a) == "`" and not instring and not incomment then
                    incomment = not true
                end
                if string.sub(lines[pos.y + 1], a, a) == string.sub(lines[pos.y + 1], pos.x + 1, pos.x + 1) then
                    break
                end
            end
            if not incomment and not instring then
                funct = i
                break
            end
        end
    end
    if funct ~= "0" then
        collisions[funct]()
    end

    if debug then
        oldprint(output.."\n^^^ Output ^^^\nvvv Playing Field vvv\n"..string.sub(field, 0, pos.x + ((pos.y) * (width + 1))).."Q"..string.sub(field, (pos.x + 2) + ((pos.y) * (width + 1))).."\n"..showstack())
    end
    pos.x = pos.x + math.sign(vel.x, 0)
    pos.y = pos.y + math.sign(vel.y, 0)
    vel.y = math.min(vel.y + 0.5, 1)
end
