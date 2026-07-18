local Json = {}

local function escapeString(value)
    local replacements = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }

    return "\"" .. value:gsub("[%z\1-\31\\\"]", function(character)
        return replacements[character] or string.format("\\u%04x", character:byte())
    end) .. "\""
end

local function isArray(value)
    local highest = 0
    local count = 0

    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return false
        end

        highest = math.max(highest, key)
        count = count + 1
    end

    return highest == count
end

function Json.Encode(value)
    local valueType = type(value)

    if valueType == "nil" then
        return "null"
    end

    if valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "string" then
        return escapeString(value)
    end

    if valueType ~= "table" then
        return "null"
    end

    local chunks = {}

    if isArray(value) then
        for index = 1, #value do
            chunks[#chunks + 1] = Json.Encode(value[index])
        end

        return "[" .. table.concat(chunks, ",") .. "]"
    end

    for key, child in pairs(value) do
        chunks[#chunks + 1] = escapeString(tostring(key)) .. ":" .. Json.Encode(child)
    end

    return "{" .. table.concat(chunks, ",") .. "}"
end

local Parser = {}
Parser.__index = Parser

function Parser:peek()
    return self.source:sub(self.position, self.position)
end

function Parser:next()
    local character = self:peek()
    self.position = self.position + 1
    return character
end

function Parser:skipWhitespace()
    while self:peek():match("%s") do
        self.position = self.position + 1
    end
end

function Parser:parseString()
    self:next()
    local result = {}

    while self.position <= #self.source do
        local character = self:next()

        if character == "\"" then
            return table.concat(result)
        end

        if character == "\\" then
            local escaped = self:next()
            local map = { b = "\b", f = "\f", n = "\n", r = "\r", t = "\t", ["\\"] = "\\", ["/"] = "/", ["\""] = "\"" }
            result[#result + 1] = map[escaped] or escaped
        else
            result[#result + 1] = character
        end
    end

    error("Unterminated string")
end

function Parser:parseNumber()
    local start = self.position

    while self:peek():match("[%d%+%-%.eE]") do
        self.position = self.position + 1
    end

    return tonumber(self.source:sub(start, self.position - 1))
end

function Parser:parseArray()
    self:next()
    local result = {}
    self:skipWhitespace()

    if self:peek() == "]" then
        self:next()
        return result
    end

    while true do
        result[#result + 1] = self:parseValue()
        self:skipWhitespace()

        local character = self:next()
        if character == "]" then
            return result
        end

        if character ~= "," then
            error("Expected comma in array")
        end
    end
end

function Parser:parseObject()
    self:next()
    local result = {}
    self:skipWhitespace()

    if self:peek() == "}" then
        self:next()
        return result
    end

    while true do
        self:skipWhitespace()
        local key = self:parseString()
        self:skipWhitespace()

        if self:next() ~= ":" then
            error("Expected colon in object")
        end

        result[key] = self:parseValue()
        self:skipWhitespace()

        local character = self:next()
        if character == "}" then
            return result
        end

        if character ~= "," then
            error("Expected comma in object")
        end
    end
end

function Parser:parseValue()
    self:skipWhitespace()
    local character = self:peek()

    if character == "\"" then
        return self:parseString()
    end

    if character == "{" then
        return self:parseObject()
    end

    if character == "[" then
        return self:parseArray()
    end

    if self.source:sub(self.position, self.position + 3) == "true" then
        self.position = self.position + 4
        return true
    end

    if self.source:sub(self.position, self.position + 4) == "false" then
        self.position = self.position + 5
        return false
    end

    if self.source:sub(self.position, self.position + 3) == "null" then
        self.position = self.position + 4
        return nil
    end

    return self:parseNumber()
end

function Json.Decode(source)
    if type(source) ~= "string" or source == "" then
        return nil
    end

    local parser = setmetatable({ source = source, position = 1 }, Parser)
    local ok, result = pcall(function()
        return parser:parseValue()
    end)

    if ok then
        return result
    end

    return nil
end

return Json
