local NBT = {}

NBT.VERSION = "1.0.0"

NBT.TAG_End        = 0
NBT.TAG_Byte       = 1
NBT.TAG_Short      = 2
NBT.TAG_Int        = 3
NBT.TAG_Long       = 4
NBT.TAG_Float      = 5
NBT.TAG_Double     = 6
NBT.TAG_Byte_Array = 7
NBT.TAG_String     = 8
NBT.TAG_List       = 9
NBT.TAG_Compound   = 10
NBT.TAG_Int_Array  = 11
NBT.TAG_Long_Array = 12

NBT.TAG_NAMES = {
    [0]  = "TAG_End",
    [1]  = "TAG_Byte",
    [2]  = "TAG_Short",
    [3]  = "TAG_Int",
    [4]  = "TAG_Long",
    [5]  = "TAG_Float",
    [6]  = "TAG_Double",
    [7]  = "TAG_Byte_Array",
    [8]  = "TAG_String",
    [9]  = "TAG_List",
    [10] = "TAG_Compound",
    [11] = "TAG_Int_Array",
    [12] = "TAG_Long_Array",
}

NBT.TAG_IDS = {
    TAG_End        = 0,
    TAG_Byte       = 1,
    TAG_Short      = 2,
    TAG_Int        = 3,
    TAG_Long       = 4,
    TAG_Float      = 5,
    TAG_Double     = 6,
    TAG_Byte_Array = 7,
    TAG_String     = 8,
    TAG_List       = 9,
    TAG_Compound   = 10,
    TAG_Int_Array  = 11,
    TAG_Long_Array = 12,
}

NBT.DEFAULT_ENDIAN = "be"
NBT.DEFAULT_LONG_AS = "string"

NBT.HUGE = math.huge or 1 / 0

NBT.Reader = {}
NBT.Reader.__index = NBT.Reader

function NBT.Reader.new(data, endian, pos, long_as)
    endian = endian or NBT.DEFAULT_ENDIAN

    if type(data) ~= "string" then
        error("NBT.Reader.new expected data to be a string")
    end

    if endian ~= "be" and endian ~= "le" then
        error("Invalid endian. Use 'be' or 'le'.")
    end

    long_as = long_as or NBT.DEFAULT_LONG_AS

    if long_as ~= "string" and long_as ~= "number" and long_as ~= "table" then
        error("Invalid long_as. Use 'string', 'number', or 'table'.")
    end

    return setmetatable({
        data = data,
        pos = pos or 1,
        endian = endian,
        long_as = long_as,
    }, NBT.Reader)
end

function NBT.Reader:remaining()
    return #self.data - self.pos + 1
end

function NBT.Reader:tell()
    return self.pos
end

function NBT.Reader:seek(pos)
    if pos < 1 or pos > #self.data + 1 then
        error("Invalid seek position: " .. tostring(pos))
    end

    self.pos = pos
end

function NBT.Reader:skip(n)
    self:need(n)
    self.pos = self.pos + n
end

function NBT.Reader:need(n)
    if self:remaining() < n then
        error("Unexpected end of NBT data at offset " .. tostring(self.pos))
    end
end

function NBT.Reader:readBytes(n)
    self:need(n)

    local s = self.data:sub(self.pos, self.pos + n - 1)
    self.pos = self.pos + n

    return s
end

function NBT.Reader:peekU8()
    self:need(1)
    return self.data:byte(self.pos)
end

function NBT.Reader:readU8()
    self:need(1)

    local b = self.data:byte(self.pos)
    self.pos = self.pos + 1

    return b
end

function NBT.Reader:readI8()
    local b = self:readU8()

    if b >= 128 then
        return b - 256
    end

    return b
end

function NBT.Reader:readU16()
    self:need(2)

    local b1, b2 = self.data:byte(self.pos, self.pos + 1)
    self.pos = self.pos + 2

    if self.endian == "be" then
        return b1 * 256 + b2
    else
        return b2 * 256 + b1
    end
end

function NBT.Reader:readI16()
    local n = self:readU16()

    if n >= 32768 then
        return n - 65536
    end

    return n
end

function NBT.Reader:readU32()
    self:need(4)

    local b1, b2, b3, b4 = self.data:byte(self.pos, self.pos + 3)
    self.pos = self.pos + 4

    if self.endian == "be" then
        return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    else
        return ((b4 * 256 + b3) * 256 + b2) * 256 + b1
    end
end

function NBT.Reader:readI32()
    local n = self:readU32()

    if n >= 2147483648 then
        return n - 4294967296
    end

    return n
end

function NBT.Reader:readLongBytesBE()
    local bytes = {
        self:readU8(),
        self:readU8(),
        self:readU8(),
        self:readU8(),
        self:readU8(),
        self:readU8(),
        self:readU8(),
        self:readU8(),
    }

    if self.endian == "le" then
        bytes = NBT.reverseBytes(bytes)
    end

    return bytes
end

function NBT.Reader:readI64()
    local bytes = self:readLongBytesBE()

    if self.long_as == "table" then
        return {
            bytes = bytes,
            decimal = NBT.signedLongDecimal(bytes),
        }
    elseif self.long_as == "number" then
        return NBT.longBytesToNumberOrString(bytes)
    else
        return NBT.signedLongDecimal(bytes)
    end
end

function NBT.Reader:readFloat()
    self:need(4)

    local b1, b2, b3, b4 = self.data:byte(self.pos, self.pos + 3)
    self.pos = self.pos + 4

    if self.endian == "le" then
        b1, b2, b3, b4 = b4, b3, b2, b1
    end

    local u = ((b1 * 256 + b2) * 256 + b3) * 256 + b4

    local sign = 1
    if u >= 2147483648 then
        sign = -1
        u = u - 2147483648
    end

    local exp = math.floor(u / 8388608)
    local mant = u - exp * 8388608

    if exp == 255 then
        if mant == 0 then
            return sign * NBT.HUGE
        end

        return 0 / 0
    elseif exp == 0 then
        if mant == 0 then
            return sign * 0
        end

        return sign * (mant / 8388608) * 2 ^ -126
    else
        return sign * (1 + mant / 8388608) * 2 ^ (exp - 127)
    end
end

function NBT.Reader:readDouble()
    self:need(8)

    local b = { self.data:byte(self.pos, self.pos + 7) }
    self.pos = self.pos + 8

    if self.endian == "le" then
        b = NBT.reverseBytes(b)
    end

    local sign = 1

    if b[1] >= 128 then
        sign = -1
        b[1] = b[1] - 128
    end

    local exp = b[1] * 16 + math.floor(b[2] / 16)

    local frac = (b[2] % 16) / 16
    frac = frac + b[3] / 4096
    frac = frac + b[4] / 1048576
    frac = frac + b[5] / 268435456
    frac = frac + b[6] / 68719476736
    frac = frac + b[7] / 17592186044416
    frac = frac + b[8] / 4503599627370496

    if exp == 2047 then
        if frac == 0 then
            return sign * NBT.HUGE
        end

        return 0 / 0
    elseif exp == 0 then
        if frac == 0 then
            return sign * 0
        end

        return sign * frac * 2 ^ -1022
    else
        return sign * (1 + frac) * 2 ^ (exp - 1023)
    end
end

function NBT.Reader:readString()
    local len = self:readU16()
    return self:readBytes(len)
end

function NBT.copyBytes(t)
    local out = {}

    for i = 1, #t do
        out[i] = t[i]
    end

    return out
end

function NBT.reverseBytes(t)
    local out = {}

    for i = 1, #t do
        out[i] = t[#t - i + 1]
    end

    return out
end

function NBT.allZero(bytes)
    for i = 1, #bytes do
        if bytes[i] ~= 0 then
            return false
        end
    end

    return true
end

function NBT.unsignedBytesToDecimal(bytes)
    bytes = NBT.copyBytes(bytes)

    if NBT.allZero(bytes) then
        return "0"
    end

    local digits = {}

    while not NBT.allZero(bytes) do
        local carry = 0

        for i = 1, #bytes do
            local v = carry * 256 + bytes[i]
            local q = math.floor(v / 10)

            carry = v - q * 10
            bytes[i] = q
        end

        digits[#digits + 1] = tostring(carry)
    end

    local s = ""

    for i = #digits, 1, -1 do
        s = s .. digits[i]
    end

    return s
end

function NBT.twosComplementMagnitude(bytes)
    local out = {}

    for i = 1, #bytes do
        out[i] = 255 - bytes[i]
    end

    local carry = 1

    for i = #out, 1, -1 do
        local v = out[i] + carry

        if v >= 256 then
            out[i] = v - 256
            carry = 1
        else
            out[i] = v
            carry = 0
        end
    end

    return out
end

function NBT.beBytesToU32(b1, b2, b3, b4)
    return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
end

function NBT.longBytesToNumberOrString(bytes)
    local negative = bytes[1] >= 128
    local work = bytes

    if negative then
        work = NBT.twosComplementMagnitude(bytes)
    end

    local hi = NBT.beBytesToU32(work[1], work[2], work[3], work[4])
    local lo = NBT.beBytesToU32(work[5], work[6], work[7], work[8])

    if hi <= 2097151 then
        local n = hi * 4294967296 + lo

        if negative then
            return -n
        end

        return n
    end

    local dec = NBT.unsignedBytesToDecimal(work)

    if negative then
        return "-" .. dec
    end

    return dec
end

function NBT.signedLongDecimal(bytes)
    if bytes[1] >= 128 then
        return "-" .. NBT.unsignedBytesToDecimal(NBT.twosComplementMagnitude(bytes))
    end

    return NBT.unsignedBytesToDecimal(bytes)
end

function NBT.tagName(id)
    return NBT.TAG_NAMES[id] or ("UNKNOWN_TAG_" .. tostring(id))
end

function NBT.checkLength(len, what)
    if len < 0 then
        error(what .. " has negative length: " .. tostring(len))
    end
end

function NBT.makeNode(id, name, value, extra)
    local node = {
        id = id,
        tag = NBT.tagName(id),
        name = name,
        value = value,
    }

    if extra then
        for k, v in pairs(extra) do
            node[k] = v
        end
    end

    return node
end

function NBT.makeListNode(element_id, value, extra)
    local node = {
        id = element_id,
        tag = NBT.tagName(element_id),
        value = value,
    }

    if extra then
        for k, v in pairs(extra) do
            node[k] = v
        end
    end

    return node
end

function NBT.parsePayload(r, id)
    if id == NBT.TAG_End then
        return nil

    elseif id == NBT.TAG_Byte then
        return r:readI8()

    elseif id == NBT.TAG_Short then
        return r:readI16()

    elseif id == NBT.TAG_Int then
        return r:readI32()

    elseif id == NBT.TAG_Long then
        return r:readI64()

    elseif id == NBT.TAG_Float then
        return r:readFloat()

    elseif id == NBT.TAG_Double then
        return r:readDouble()

    elseif id == NBT.TAG_Byte_Array then
        local len = r:readI32()
        NBT.checkLength(len, "TAG_Byte_Array")

        local arr = {}

        for i = 1, len do
            arr[i] = r:readI8()
        end

        return arr

    elseif id == NBT.TAG_String then
        return r:readString()

    elseif id == NBT.TAG_List then
        local element_id = r:readU8()
        local len = r:readI32()
        NBT.checkLength(len, "TAG_List")

        if element_id == NBT.TAG_End and len > 0 then
            error("TAG_List has TAG_End element type with non-zero length")
        end

        local arr = {}

        for i = 1, len do
            local value, extra = NBT.parsePayload(r, element_id)

            arr[i] = NBT.makeListNode(element_id, value, extra)
        end

        return arr, {
            element_id = element_id,
            element_tag = NBT.tagName(element_id),
        }

    elseif id == NBT.TAG_Compound then
        local children = {}
        local order = {}

        while true do
            local child_id = r:readU8()

            if child_id == NBT.TAG_End then
                break
            end

            local child = NBT.parseNamedTag(r, child_id)

            children[child.name] = child
            order[#order + 1] = child.name
        end

        return children, {
            order = order,
        }

    elseif id == NBT.TAG_Int_Array then
        local len = r:readI32()
        NBT.checkLength(len, "TAG_Int_Array")

        local arr = {}

        for i = 1, len do
            arr[i] = r:readI32()
        end

        return arr

    elseif id == NBT.TAG_Long_Array then
        local len = r:readI32()
        NBT.checkLength(len, "TAG_Long_Array")

        local arr = {}

        for i = 1, len do
            arr[i] = r:readI64()
        end

        return arr

    else
        error("Unsupported NBT tag id: " .. tostring(id))
    end
end

function NBT.parseNamedTag(r, id)
    local name = r:readString()
    local value, extra = NBT.parsePayload(r, id)

    return NBT.makeNode(id, name, value, extra)
end

function NBT.parse(data, opts)
    opts = opts or {}

    local endian = opts.endian or NBT.DEFAULT_ENDIAN
    local offset = opts.offset or 1
    local long_as = opts.long_as or NBT.DEFAULT_LONG_AS

    local r = NBT.Reader.new(data, endian, offset, long_as)
    local root_id = r:readU8()

    if root_id == NBT.TAG_End then
        return {
            id = NBT.TAG_End,
            tag = "TAG_End",
            name = "",
            value = nil,
            offset = r.pos,
        }
    end

    local root = NBT.parseNamedTag(r, root_id)
    root.offset = r.pos

    return root
end

function NBT.detectLevelDatFormat(data, opts)
    opts = opts or {}

    local start_offset = opts.offset or 1
    local fmt = {
        endian = opts.endian or NBT.DEFAULT_ENDIAN,
        offset = start_offset,
        payload_offset = start_offset,
        bedrock_header = false,
        bedrock_version = nil,
        payload_size = #data - start_offset + 1,
        file_size = #data,
    }

    local should_detect = opts.detect_bedrock_header
    if should_detect == nil then
        should_detect = true
    end

    if opts.bedrock_header or should_detect then
        if #data >= start_offset + 8 then
            local probe = NBT.Reader.new(data, "le", start_offset, opts.long_as)
            local version = probe:readI32()
            local size = probe:readI32()
            local expected_payload_size = #data - start_offset - 7
            local next_id = data:byte(start_offset + 8)

            if opts.bedrock_header or
               (size == expected_payload_size and next_id and next_id >= 1 and next_id <= 12) then
                fmt.endian = opts.endian or "le"
                fmt.offset = start_offset + 8
                fmt.payload_offset = start_offset + 8
                fmt.bedrock_header = true
                fmt.bedrock_version = version
                fmt.payload_size = size
            end
        end
    end

    return fmt
end

function NBT.parseLevelDat(data, opts)
    opts = opts or {}

    local fmt = NBT.detectLevelDatFormat(data, opts)

    local root = NBT.parse(data, {
        endian = fmt.endian,
        offset = fmt.payload_offset,
        long_as = opts.long_as,
    })

    root.nbt_format = fmt

    return root
end

function NBT.loadFile(path, opts)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()

    return NBT.parseLevelDat(data, opts)
end

function NBT.readFileRaw(path)
    local f = assert(io.open(path, "rb"))
    local data = f:read("*a")
    f:close()

    return data
end

function NBT.toLua(node)
    if type(node) ~= "table" or not node.id then
        return node
    end

    if node.id == NBT.TAG_Compound then
        local out = {}

        for name, child in pairs(node.value) do
            out[name] = NBT.toLua(child)
        end

        return out

    elseif node.id == NBT.TAG_List then
        local out = {}

        for i, child in ipairs(node.value) do
            out[i] = NBT.toLua(child)
        end

        return out

    else
        return node.value
    end
end

function NBT.getChild(node, name)
    if not node or node.id ~= NBT.TAG_Compound or type(node.value) ~= "table" then
        return nil
    end

    return node.value[name]
end

function NBT.getValue(node, name, default)
    local child = NBT.getChild(node, name)

    if child == nil then
        return default
    end

    return child.value
end

function NBT.hasChild(node, name)
    return NBT.getChild(node, name) ~= nil
end

function NBT.eachCompound(node, fn)
    if not node or node.id ~= NBT.TAG_Compound or type(node.order) ~= "table" then
        return
    end

    for i = 1, #node.order do
        local name = node.order[i]
        fn(name, node.value[name], i)
    end
end

function NBT.prettyType(id)
    return NBT.tagName(id)
end

function NBT.dump(node, indent)
    indent = indent or ""

    if type(node) ~= "table" or not node.id then
        return indent .. tostring(node)
    end

    local line = indent .. NBT.tagName(node.id)

    if node.name ~= nil then
        line = line .. "(" .. tostring(node.name) .. ")"
    end

    if node.id == NBT.TAG_Compound then
        local lines = { line .. " {" }

        if node.order then
            for i = 1, #node.order do
                local name = node.order[i]
                lines[#lines + 1] = NBT.dump(node.value[name], indent .. "  ")
            end
        else
            for _, child in pairs(node.value) do
                lines[#lines + 1] = NBT.dump(child, indent .. "  ")
            end
        end

        lines[#lines + 1] = indent .. "}"
        return table.concat(lines, "\n")

    elseif node.id == NBT.TAG_List then
        local lines = {
            line .. " [" .. tostring(#node.value) .. "] of " .. tostring(node.element_tag)
        }

        for i = 1, #node.value do
            lines[#lines + 1] = NBT.dump(node.value[i], indent .. "  ")
        end

        return table.concat(lines, "\n")

    else
        return line .. " = " .. tostring(node.value)
    end
end

NBT.Writer = {}
NBT.Writer.__index = NBT.Writer

function NBT.Writer.new(endian)
    endian = endian or NBT.DEFAULT_ENDIAN

    if endian ~= "be" and endian ~= "le" then
        error("Invalid endian. Use 'be' or 'le'.")
    end

    return setmetatable({
        endian = endian,
        parts = {},
        size = 0,
    }, NBT.Writer)
end

function NBT.Writer:writeBytes(s)
    if type(s) ~= "string" then
        error("writeBytes expected string")
    end

    self.parts[#self.parts + 1] = s
    self.size = self.size + #s
end

function NBT.Writer:toString()
    return table.concat(self.parts)
end

function NBT.Writer:length()
    return self.size
end

function NBT.assertInteger(n, what)
    what = what or "number"

    if type(n) ~= "number" then
        error(what .. " must be a number")
    end

    if n ~= math.floor(n) then
        error(what .. " must be an integer")
    end
end

function NBT.assertRange(n, minv, maxv, what)
    NBT.assertInteger(n, what)

    if n < minv or n > maxv then
        error((what or "number") .. " out of range: " .. tostring(n))
    end
end

function NBT.Writer:writeU8(n)
    NBT.assertRange(n, 0, 255, "u8")
    self:writeBytes(string.char(n))
end

function NBT.Writer:writeI8(n)
    NBT.assertRange(n, -128, 127, "i8")

    if n < 0 then
        n = n + 256
    end

    self:writeU8(n)
end

function NBT.Writer:writeU16(n)
    NBT.assertRange(n, 0, 65535, "u16")

    local b1 = math.floor(n / 256)
    local b2 = n - b1 * 256

    if self.endian == "be" then
        self:writeBytes(string.char(b1, b2))
    else
        self:writeBytes(string.char(b2, b1))
    end
end

function NBT.Writer:writeI16(n)
    NBT.assertRange(n, -32768, 32767, "i16")

    if n < 0 then
        n = n + 65536
    end

    self:writeU16(n)
end

function NBT.Writer:writeU32(n)
    NBT.assertRange(n, 0, 4294967295, "u32")

    local b1 = math.floor(n / 16777216)
    n = n - b1 * 16777216

    local b2 = math.floor(n / 65536)
    n = n - b2 * 65536

    local b3 = math.floor(n / 256)
    local b4 = n - b3 * 256

    if self.endian == "be" then
        self:writeBytes(string.char(b1, b2, b3, b4))
    else
        self:writeBytes(string.char(b4, b3, b2, b1))
    end
end

function NBT.Writer:writeI32(n)
    NBT.assertRange(n, -2147483648, 2147483647, "i32")

    if n < 0 then
        n = n + 4294967296
    end

    self:writeU32(n)
end

function NBT.cleanIntegerDecimalString(value, what)
    what = what or "integer"

    if type(value) == "number" then
        NBT.assertInteger(value, what)
        return string.format("%.0f", value)
    elseif type(value) == "string" then
        local s = value

        if s:sub(1, 1) == "+" then
            s = s:sub(2)
        end

        if not s:match("^%-?%d+$") then
            error(what .. " string must contain only decimal digits")
        end

        local neg = false
        if s:sub(1, 1) == "-" then
            neg = true
            s = s:sub(2)
        end

        s = s:gsub("^0+", "")
        if s == "" then
            s = "0"
            neg = false
        end

        if neg then
            return "-" .. s
        end

        return s
    else
        error(what .. " must be a number or decimal string")
    end
end

function NBT.decimalCompareAbs(a, b)
    a = tostring(a):gsub("^%+", ""):gsub("^%-", ""):gsub("^0+", "")
    b = tostring(b):gsub("^%+", ""):gsub("^%-", ""):gsub("^0+", "")

    if a == "" then
        a = "0"
    end

    if b == "" then
        b = "0"
    end

    if #a < #b then
        return -1
    elseif #a > #b then
        return 1
    elseif a < b then
        return -1
    elseif a > b then
        return 1
    else
        return 0
    end
end

function NBT.decimalDivModSmall(dec, divisor)
    local q = {}
    local rem = 0
    local started = false

    for i = 1, #dec do
        local digit = dec:byte(i) - 48
        local v = rem * 10 + digit
        local qd = math.floor(v / divisor)
        rem = v - qd * divisor

        if qd ~= 0 or started then
            q[#q + 1] = string.char(48 + qd)
            started = true
        end
    end

    if not started then
        return "0", rem
    end

    return table.concat(q), rem
end

function NBT.decimalToUnsignedBytesBE(dec, width)
    dec = NBT.cleanIntegerDecimalString(dec, "decimal")

    if dec:sub(1, 1) == "-" then
        error("decimalToUnsignedBytesBE expected unsigned decimal")
    end

    local bytes = {}

    for i = 1, width do
        bytes[i] = 0
    end

    local index = width

    while dec ~= "0" do
        if index < 1 then
            error("integer too large for " .. tostring(width) .. " bytes")
        end

        local q, rem = NBT.decimalDivModSmall(dec, 256)
        bytes[index] = rem
        index = index - 1
        dec = q
    end

    return bytes
end

function NBT.twosComplementBytes(bytes)
    local out = {}

    for i = 1, #bytes do
        out[i] = 255 - bytes[i]
    end

    local carry = 1

    for i = #out, 1, -1 do
        local v = out[i] + carry

        if v >= 256 then
            out[i] = v - 256
            carry = 1
        else
            out[i] = v
            carry = 0
        end
    end

    return out
end

function NBT.signedLongToBytesBE(value)
    if type(value) == "table" and value.bytes then
        if #value.bytes ~= 8 then
            error("long table bytes must contain exactly 8 bytes")
        end

        local out = {}

        for i = 1, 8 do
            NBT.assertRange(value.bytes[i], 0, 255, "long byte")
            out[i] = value.bytes[i]
        end

        return out
    end

    local s = NBT.cleanIntegerDecimalString(value, "i64")
    local negative = false

    if s:sub(1, 1) == "-" then
        negative = true
        s = s:sub(2)
    end

    if negative then
        if NBT.decimalCompareAbs(s, "9223372036854775808") > 0 then
            error("i64 out of range: -" .. s)
        end
    else
        if NBT.decimalCompareAbs(s, "9223372036854775807") > 0 then
            error("i64 out of range: " .. s)
        end
    end

    local bytes = NBT.decimalToUnsignedBytesBE(s, 8)

    if negative then
        bytes = NBT.twosComplementBytes(bytes)
    end

    return bytes
end

function NBT.Writer:writeI64(value)
    local bytes = NBT.signedLongToBytesBE(value)

    if self.endian == "le" then
        bytes = NBT.reverseBytes(bytes)
    end

    self:writeBytes(string.char(
        bytes[1], bytes[2], bytes[3], bytes[4],
        bytes[5], bytes[6], bytes[7], bytes[8]
    ))
end

function NBT.numberSignBit(n)
    if n < 0 then
        return 1
    end

    if n == 0 then
        local ok, inv = pcall(function()
            return 1 / n
        end)

        if ok and inv == -NBT.HUGE then
            return 1
        end
    end

    return 0
end

function NBT.floorLog2(x)
    local e = math.floor(math.log(x) / math.log(2))
    local p = 2 ^ e

    while p > x do
        e = e - 1
        p = 2 ^ e
    end

    while p * 2 <= x do
        e = e + 1
        p = p * 2
    end

    return e
end

function NBT.floatToU32(value)
    if value ~= value then
        return 2143289344
    end

    local sign = NBT.numberSignBit(value)
    local x = math.abs(value)

    if x == NBT.HUGE then
        return sign * 2147483648 + 255 * 8388608
    end

    if x == 0 then
        return sign * 2147483648
    end

    local expbits
    local mant

    if x < 2 ^ -126 then
        expbits = 0
        mant = math.floor(x / (2 ^ -149) + 0.5)

        if mant <= 0 then
            return sign * 2147483648
        end

        if mant >= 8388608 then
            expbits = 1
            mant = 0
        end
    else
        local exp = NBT.floorLog2(x)

        if exp > 127 then
            return sign * 2147483648 + 255 * 8388608
        end

        expbits = exp + 127
        mant = math.floor((x / (2 ^ exp) - 1) * 8388608 + 0.5)

        if mant >= 8388608 then
            mant = 0
            expbits = expbits + 1

            if expbits >= 255 then
                return sign * 2147483648 + 255 * 8388608
            end
        end
    end

    return sign * 2147483648 + expbits * 8388608 + mant
end

function NBT.Writer:writeFloat(value)
    if type(value) ~= "number" then
        error("float value must be a number")
    end

    self:writeU32(NBT.floatToU32(value))
end

function NBT.doubleToBytesBE(value)
    if value ~= value then
        return { 0x7F, 0xF8, 0, 0, 0, 0, 0, 0 }
    end

    local sign = NBT.numberSignBit(value)
    local x = math.abs(value)

    local expbits
    local mant

    if x == NBT.HUGE then
        expbits = 2047
        mant = 0
    elseif x == 0 then
        expbits = 0
        mant = 0
    elseif x < 2 ^ -1022 then
        expbits = 0
        mant = math.floor(x / (2 ^ -1074) + 0.5)

        if mant <= 0 then
            mant = 0
        end

        if mant >= 4503599627370496 then
            expbits = 1
            mant = 0
        end
    else
        local exp = NBT.floorLog2(x)

        if exp > 1023 then
            expbits = 2047
            mant = 0
        else
            expbits = exp + 1023
            mant = math.floor((x / (2 ^ exp) - 1) * 4503599627370496 + 0.5)

            if mant >= 4503599627370496 then
                mant = 0
                expbits = expbits + 1

                if expbits >= 2047 then
                    expbits = 2047
                    mant = 0
                end
            end
        end
    end

    local b1 = sign * 128 + math.floor(expbits / 16)
    local b2 = (expbits - math.floor(expbits / 16) * 16) * 16

    local m1 = math.floor(mant / 281474976710656)
    mant = mant - m1 * 281474976710656
    b2 = b2 + m1

    local b3 = math.floor(mant / 1099511627776)
    mant = mant - b3 * 1099511627776

    local b4 = math.floor(mant / 4294967296)
    mant = mant - b4 * 4294967296

    local b5 = math.floor(mant / 16777216)
    mant = mant - b5 * 16777216

    local b6 = math.floor(mant / 65536)
    mant = mant - b6 * 65536

    local b7 = math.floor(mant / 256)
    local b8 = mant - b7 * 256

    return { b1, b2, b3, b4, b5, b6, b7, b8 }
end

function NBT.Writer:writeDouble(value)
    if type(value) ~= "number" then
        error("double value must be a number")
    end

    local bytes = NBT.doubleToBytesBE(value)

    if self.endian == "le" then
        bytes = NBT.reverseBytes(bytes)
    end

    self:writeBytes(string.char(
        bytes[1], bytes[2], bytes[3], bytes[4],
        bytes[5], bytes[6], bytes[7], bytes[8]
    ))
end

function NBT.Writer:writeString(value)
    if value == nil then
        value = ""
    end

    if type(value) ~= "string" then
        error("TAG_String value/name must be a string")
    end

    if #value > 65535 then
        error("NBT string is too long: " .. tostring(#value))
    end

    self:writeU16(#value)
    self:writeBytes(value)
end

function NBT.inferListElementId(list)
    if type(list) ~= "table" or #list == 0 then
        return NBT.TAG_End
    end

    local first = list[1]

    if type(first) == "table" and first.id ~= nil then
        return first.id
    end

    error("Cannot infer TAG_List element id from raw values. Set node.element_id.")
end

function NBT.writePayload(w, id, value, node)
    if id == NBT.TAG_End then
        return

    elseif id == NBT.TAG_Byte then
        w:writeI8(value)

    elseif id == NBT.TAG_Short then
        w:writeI16(value)

    elseif id == NBT.TAG_Int then
        w:writeI32(value)

    elseif id == NBT.TAG_Long then
        w:writeI64(value)

    elseif id == NBT.TAG_Float then
        w:writeFloat(value)

    elseif id == NBT.TAG_Double then
        w:writeDouble(value)

    elseif id == NBT.TAG_Byte_Array then
        if type(value) ~= "table" then
            error("TAG_Byte_Array value must be a table")
        end

        w:writeI32(#value)

        for i = 1, #value do
            w:writeI8(value[i])
        end

    elseif id == NBT.TAG_String then
        w:writeString(value)

    elseif id == NBT.TAG_List then
        if type(value) ~= "table" then
            error("TAG_List value must be a table")
        end

        local element_id = node and node.element_id or NBT.inferListElementId(value)
        w:writeU8(element_id)
        w:writeI32(#value)

        if element_id == NBT.TAG_End and #value > 0 then
            error("TAG_List cannot have TAG_End elements unless length is zero")
        end

        for i = 1, #value do
            local item = value[i]

            if type(item) == "table" and item.id ~= nil and item.value ~= nil then
                if item.id ~= element_id then
                    error("TAG_List element " .. tostring(i) .. " has id " .. tostring(item.id) ..
                          ", expected " .. tostring(element_id))
                end

                NBT.writePayload(w, element_id, item.value, item)
            else
                NBT.writePayload(w, element_id, item, nil)
            end
        end

    elseif id == NBT.TAG_Compound then
        if type(value) ~= "table" then
            error("TAG_Compound value must be a table")
        end

        local written = {}

        if node and type(node.order) == "table" then
            for i = 1, #node.order do
                local name = node.order[i]
                local child = value[name]

                if child then
                    NBT.writeNamedTag(w, child, name)
                    written[name] = true
                end
            end
        end

        for name, child in pairs(value) do
            if not written[name] then
                NBT.writeNamedTag(w, child, name)
            end
        end

        w:writeU8(NBT.TAG_End)

    elseif id == NBT.TAG_Int_Array then
        if type(value) ~= "table" then
            error("TAG_Int_Array value must be a table")
        end

        w:writeI32(#value)

        for i = 1, #value do
            w:writeI32(value[i])
        end

    elseif id == NBT.TAG_Long_Array then
        if type(value) ~= "table" then
            error("TAG_Long_Array value must be a table")
        end

        w:writeI32(#value)

        for i = 1, #value do
            w:writeI64(value[i])
        end

    else
        error("Unsupported NBT tag id for writing: " .. tostring(id))
    end
end

function NBT.writeNamedTag(w, node, forced_name)
    if type(node) ~= "table" then
        error("writeNamedTag expected node table")
    end

    if node.id == nil then
        error("NBT node missing id")
    end

    if node.id == NBT.TAG_End then
        w:writeU8(NBT.TAG_End)
        return
    end

    w:writeU8(node.id)
    w:writeString(forced_name or node.name or "")
    NBT.writePayload(w, node.id, node.value, node)
end

function NBT.write(data_or_node, opts)
    opts = opts or {}

    local w = NBT.Writer.new(opts.endian or NBT.DEFAULT_ENDIAN)
    NBT.writeNamedTag(w, data_or_node)

    return w:toString()
end

function NBT.writeLevelDat(node, opts)
    opts = opts or {}

    local fmt = node and node.nbt_format or {}

    local bedrock_header = opts.bedrock_header
    if bedrock_header == nil then
        bedrock_header = fmt.bedrock_header
    end

    local endian = opts.endian or fmt.endian

    if bedrock_header and not endian then
        endian = "le"
    end

    local payload = NBT.write(node, {
        endian = endian or NBT.DEFAULT_ENDIAN,
    })

    if bedrock_header then
        local header = NBT.Writer.new("le")
        header:writeI32(opts.bedrock_version or fmt.bedrock_version or 10)
        header:writeI32(#payload)
        return header:toString() .. payload
    end

    return payload
end

function NBT.writeLikeOriginal(node, opts)
    return NBT.writeLevelDat(node, opts or {})
end

function NBT.writeFileRaw(path, data)
    local f = assert(io.open(path, "wb"))
    f:write(data)
    f:close()
end

function NBT.saveFile(path, node, opts)
    NBT.writeFileRaw(path, NBT.writeLevelDat(node, opts))
end

function NBT.saveRawNBT(path, node, opts)
    opts = opts or {}
    NBT.writeFileRaw(path, NBT.write(node, opts))
end

function NBT.saveLevelDat(path, node, opts)
    NBT.writeFileRaw(path, NBT.writeLevelDat(node, opts))
end

function NBT.newNode(id, name, value, extra)
    return NBT.makeNode(id, name, value, extra)
end

function NBT.newByte(name, value)
    return NBT.newNode(NBT.TAG_Byte, name, value or 0)
end

function NBT.newShort(name, value)
    return NBT.newNode(NBT.TAG_Short, name, value or 0)
end

function NBT.newInt(name, value)
    return NBT.newNode(NBT.TAG_Int, name, value or 0)
end

function NBT.newLong(name, value)
    return NBT.newNode(NBT.TAG_Long, name, value or "0")
end

function NBT.newFloat(name, value)
    return NBT.newNode(NBT.TAG_Float, name, value or 0)
end

function NBT.newDouble(name, value)
    return NBT.newNode(NBT.TAG_Double, name, value or 0)
end

function NBT.newString(name, value)
    return NBT.newNode(NBT.TAG_String, name, value or "")
end

function NBT.newByteArray(name, value)
    return NBT.newNode(NBT.TAG_Byte_Array, name, value or {})
end

function NBT.newIntArray(name, value)
    return NBT.newNode(NBT.TAG_Int_Array, name, value or {})
end

function NBT.newLongArray(name, value)
    return NBT.newNode(NBT.TAG_Long_Array, name, value or {})
end

function NBT.newCompound(name)
    return NBT.newNode(NBT.TAG_Compound, name or "", {}, {
        order = {},
    })
end

function NBT.newList(name, element_id, value)
    return NBT.newNode(NBT.TAG_List, name or "", value or {}, {
        element_id = element_id or NBT.TAG_End,
        element_tag = NBT.tagName(element_id or NBT.TAG_End),
    })
end

function NBT.newListElement(element_id, value, extra)
    return NBT.makeListNode(element_id, value, extra)
end

function NBT.setChild(compound, child)
    if not compound or compound.id ~= NBT.TAG_Compound then
        error("setChild expected TAG_Compound node")
    end

    if not child or child.name == nil then
        error("setChild expected named child node")
    end

    if compound.value[child.name] == nil then
        compound.order = compound.order or {}
        compound.order[#compound.order + 1] = child.name
    end

    compound.value[child.name] = child
    return child
end

function NBT.setValue(compound, name, id, value, extra)
    return NBT.setChild(compound, NBT.newNode(id, name, value, extra))
end

function NBT.removeChild(compound, name)
    if not compound or compound.id ~= NBT.TAG_Compound then
        error("removeChild expected TAG_Compound node")
    end

    compound.value[name] = nil

    if compound.order then
        local out = {}

        for i = 1, #compound.order do
            if compound.order[i] ~= name then
                out[#out + 1] = compound.order[i]
            end
        end

        compound.order = out
    end
end

function NBT.listAppend(list_node, item_or_value)
    if not list_node or list_node.id ~= NBT.TAG_List then
        error("listAppend expected TAG_List node")
    end

    local element_id = list_node.element_id or NBT.inferListElementId(list_node.value)

    if element_id == NBT.TAG_End then
        if type(item_or_value) == "table" and item_or_value.id ~= nil then
            element_id = item_or_value.id
            list_node.element_id = element_id
            list_node.element_tag = NBT.tagName(element_id)
        else
            error("Cannot append raw value to empty TAG_List without element_id")
        end
    end

    if type(item_or_value) == "table" and item_or_value.id ~= nil then
        if item_or_value.id ~= element_id then
            error("List item id mismatch")
        end

        list_node.value[#list_node.value + 1] = item_or_value
    else
        list_node.value[#list_node.value + 1] = NBT.newListElement(element_id, item_or_value)
    end

    return list_node.value[#list_node.value]
end

function NBT.listRemove(list_node, index)
    if not list_node or list_node.id ~= NBT.TAG_List then
        error("listRemove expected TAG_List node")
    end

    return table.remove(list_node.value, index)
end



function NBT.saveLikeOriginal(path, node, opts)
    NBT.writeFileRaw(path, NBT.writeLikeOriginal(node, opts or {}))
end

function NBT.loadLevelDatAuto(path, opts)
    opts = opts or {}

    if opts.detect_bedrock_header == nil then
        opts.detect_bedrock_header = true
    end

    return NBT.loadFile(path, opts)
end

return NBT
