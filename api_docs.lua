-- API docs / signatures for LunaCoreNBT

-- This file is documentation only.
-- Do not require this instead of LunaCoreNBT for real parsing.

-- Real usage:
--   local NBT = require("LunaCoreNBT")

---@class NBT
local NBT = {}

-- ============================================================================
-- Tag constants
-- ============================================================================

-- TAG_End = 0
-- Used only to mark the end of a TAG_Compound.
NBT.TAG_End = 0

-- TAG_Byte = 1
-- Signed 8-bit integer.
-- Range: -128 to 127.
NBT.TAG_Byte = 1

-- TAG_Short = 2
-- Signed 16-bit integer.
-- Range: -32768 to 32767.
NBT.TAG_Short = 2

-- TAG_Int = 3
-- Signed 32-bit integer.
-- Range: -2147483648 to 2147483647.
NBT.TAG_Int = 3

-- TAG_Long = 4
-- Signed 64-bit integer.
-- In Lua 5.1, safest as a decimal string.
NBT.TAG_Long = 4

-- TAG_Float = 5
-- 32-bit floating point number.
NBT.TAG_Float = 5

-- TAG_Double = 6
-- 64-bit floating point number.
NBT.TAG_Double = 6

-- TAG_Byte_Array = 7
-- Array/table of signed bytes.
NBT.TAG_Byte_Array = 7

-- TAG_String = 8
-- NBT string.
NBT.TAG_String = 8

-- TAG_List = 9
-- Array of same-type unnamed NBT values.
NBT.TAG_List = 9

-- TAG_Compound = 10
-- Named key/value map of NBT tags.
NBT.TAG_Compound = 10

-- TAG_Int_Array = 11
-- Array/table of signed 32-bit integers.
NBT.TAG_Int_Array = 11

-- TAG_Long_Array = 12
-- Array/table of signed 64-bit integers.
NBT.TAG_Long_Array = 12

-- Maps tag id -> tag name.
--
-- Example:
--   print(NBT.TAG_NAMES[10]) -- "TAG_Compound"
---@type table<number, string>
NBT.TAG_NAMES = {}

-- Maps tag name -> tag id.
--
-- Example:
--   print(NBT.TAG_IDS.TAG_Compound) -- 10
---@type table<string, number>
NBT.TAG_IDS = {}

-- Default endian when not specified.
-- Values:
--   "be" = big-endian
--   "le" = little-endian
NBT.DEFAULT_ENDIAN = "be"

-- Default TAG_Long output mode.
-- Values:
--   "string" = decimal string, safest
--   "number" = Lua number when safe, string when too large
--   "table"  = { bytes = {...}, decimal = "..." }
NBT.DEFAULT_LONG_AS = "string"

-- Infinity helper.
NBT.HUGE = math.huge

-- ============================================================================
-- Common data shapes
-- ============================================================================

--[[
NBT node shape:

---@class NBTNode
---@field id number              NBT tag id
---@field tag string             readable tag name, e.g. "TAG_Compound"
---@field name string|nil        tag name; nil for list elements
---@field value any              tag payload
---@field order string[]|nil     only on compounds; preserves child order
---@field element_id number|nil  only on lists
---@field element_tag string|nil only on lists
---@field offset number|nil      parse ending offset on root
---@field nbt_format table|nil   auto-detected level.dat format on root

Compound value shape:
  node.value = {
      SomeTagName = childNode,
      AnotherTagName = childNode,
  }

List value shape:
  node.value = {
      listElementNode1,
      listElementNode2,
      listElementNode3,
  }

Bedrock format shape:
---@class NBTFormat
---@field endian string
---@field offset number
---@field payload_offset number
---@field bedrock_header boolean
---@field bedrock_version number|nil
---@field payload_size number
---@field file_size number
]]

-- ============================================================================
-- Main loading / parsing API
-- ============================================================================

-- Reads a file and parses it as NBT/level.dat.
--
-- For nbt_rw_auto.lua, Bedrock-style 8-byte headers are auto-detected by default.
--
-- Options:
--   opts.endian: "be" or "le"
--   opts.offset: starting byte offset, default 1
--   opts.long_as: "string", "number", or "table"
--   opts.bedrock_header: true to force skipping 8-byte Bedrock header
--   opts.detect_bedrock_header: true/false, default true in nbt_rw_auto.lua
--
-- Example:
--   local root = NBT.loadFile("sdmc:/level.dat")
--   print(NBT.getValue(root, "LevelName", "Unknown"))
--
---@param path string
---@param opts table|nil
---@return NBTNode root
function NBT.loadFile(path, opts) end

-- Same as loadFile, but named to make auto-detection obvious.
--
-- Example:
--   local root = NBT.loadLevelDatAuto("sdmc:/level.dat")
--
---@param path string
---@param opts table|nil
---@return NBTNode root
function NBT.loadLevelDatAuto(path, opts) end

-- Parses raw NBT bytes.
--
-- This expects the data to start directly at the NBT root tag unless opts.offset is used.
-- It does not automatically skip the Bedrock header; use parseLevelDat for that.
--
-- Example:
--   local raw = NBT.readFileRaw("sdmc:/level.dat")
--   local root = NBT.parse(raw, { endian = "le", offset = 9 })
--
---@param data string
---@param opts table|nil
---@return NBTNode root
function NBT.parse(data, opts) end

-- Parses bytes as a level.dat-style file.
--
-- In nbt_rw_auto.lua this can auto-detect:
--   - Bedrock 8-byte header
--   - little-endian payload
--   - header version
--
-- Example:
--   local raw = NBT.readFileRaw("sdmc:/level.dat")
--   local root = NBT.parseLevelDat(raw)
--
---@param data string
---@param opts table|nil
---@return NBTNode root
function NBT.parseLevelDat(data, opts) end

-- Detects level.dat format without fully parsing all tags.
--
-- Returns:
--   {
--     endian = "le",
--     offset = 9,
--     payload_offset = 9,
--     bedrock_header = true,
--     bedrock_version = 5,
--     payload_size = 1154,
--     file_size = 1162,
--   }
--
---@param data string
---@param opts table|nil
---@return NBTFormat fmt
function NBT.detectLevelDatFormat(data, opts) end

-- Low-level parser for a named tag.
--
-- The tag id must already be read.
--
-- Example:
--   local r = NBT.Reader.new(data, "le")
--   local id = r:readU8()
--   local node = NBT.parseNamedTag(r, id)
--
---@param reader NBTReader
---@param id number
---@return NBTNode node
function NBT.parseNamedTag(reader, id) end

-- Low-level parser for only a tag payload.
--
-- Does not read tag id or name.
--
-- Example:
--   local value = NBT.parsePayload(reader, NBT.TAG_Int)
--
---@param reader NBTReader
---@param id number
---@return any value
---@return table|nil extra
function NBT.parsePayload(reader, id) end

-- ============================================================================
-- Saving / writing API
-- ============================================================================

-- Converts an NBT root node to raw NBT bytes with no Bedrock header.
--
-- Options:
--   opts.endian: "be" or "le"
--
-- Example:
--   local bytes = NBT.write(root, { endian = "le" })
--
---@param root NBTNode
---@param opts table|nil
---@return string bytes
function NBT.write(root, opts) end

-- Converts an NBT root node to level.dat bytes.
--
-- In nbt_rw_auto.lua, if the root was loaded from loadFile/parseLevelDat,
-- this can preserve:
--   - original endian
--   - original Bedrock header setting
--   - original Bedrock header version
--
-- Options:
--   opts.endian: "be" or "le"
--   opts.bedrock_header: true/false
--   opts.bedrock_version: number
--
-- Example:
--   local bytes = NBT.writeLevelDat(root)
--
---@param root NBTNode
---@param opts table|nil
---@return string bytes
function NBT.writeLevelDat(root, opts) end

-- Writes using the detected/original format when possible.
--
-- Same idea as writeLevelDat(root) but more explicit.
--
---@param root NBTNode
---@param opts table|nil
---@return string bytes
function NBT.writeLikeOriginal(root, opts) end

-- Saves an NBT root node to a file.
--
-- In nbt_rw_auto.lua, this saves like the original format when the root came from loadFile().
--
-- Example:
--   local root = NBT.loadFile("sdmc:/level.dat")
--   NBT.saveFile("sdmc:/level_out.dat", root)
--
---@param path string
---@param root NBTNode
---@param opts table|nil
function NBT.saveFile(path, root, opts) end

-- Saves raw NBT with no Bedrock header.
--
-- Example:
--   NBT.saveRawNBT("sdmc:/raw_nbt.dat", root, { endian = "le" })
--
---@param path string
---@param root NBTNode
---@param opts table|nil
function NBT.saveRawNBT(path, root, opts) end

-- Saves as a level.dat-style file.
--
-- Example:
--   NBT.saveLevelDat("sdmc:/level_out.dat", root, {
--       endian = "le",
--       bedrock_header = true,
--       bedrock_version = 5,
--   })
--
---@param path string
---@param root NBTNode
---@param opts table|nil
function NBT.saveLevelDat(path, root, opts) end

-- Saves using the original/detected level.dat format when possible.
--
-- Example:
--   NBT.saveLikeOriginal("sdmc:/level_out.dat", root)
--
---@param path string
---@param root NBTNode
---@param opts table|nil
function NBT.saveLikeOriginal(path, root, opts) end

-- Reads raw bytes from a file.
--
-- Example:
--   local raw = NBT.readFileRaw("sdmc:/level.dat")
--
---@param path string
---@return string data
function NBT.readFileRaw(path) end

-- Writes raw bytes to a file.
--
-- Example:
--   NBT.writeFileRaw("sdmc:/backup.dat", raw)
--
---@param path string
---@param data string
function NBT.writeFileRaw(path, data) end

-- Low-level writer for a complete named NBT tag.
--
---@param writer NBTWriter
---@param node NBTNode
---@param forced_name string|nil
function NBT.writeNamedTag(writer, node, forced_name) end

-- Low-level writer for only a tag payload.
--
---@param writer NBTWriter
---@param id number
---@param value any
---@param node NBTNode|nil
function NBT.writePayload(writer, id, value, node) end

-- ============================================================================
-- Node creation API
-- ============================================================================

-- Creates a generic NBT node.
--
-- Example:
--   local node = NBT.newNode(NBT.TAG_Int, "Health", 20)
--
---@param id number
---@param name string|nil
---@param value any
---@param extra table|nil
---@return NBTNode node
function NBT.newNode(id, name, value, extra) end

-- Internal/public node maker used by newNode.
--
---@param id number
---@param name string|nil
---@param value any
---@param extra table|nil
---@return NBTNode node
function NBT.makeNode(id, name, value, extra) end

-- Creates TAG_Byte.
--
---@param name string
---@param value number|nil
---@return NBTNode node
function NBT.newByte(name, value) end

-- Creates TAG_Short.
--
---@param name string
---@param value number|nil
---@return NBTNode node
function NBT.newShort(name, value) end

-- Creates TAG_Int.
--
---@param name string
---@param value number|nil
---@return NBTNode node
function NBT.newInt(name, value) end

-- Creates TAG_Long.
--
-- Use string values for full 64-bit safety.
--
-- Example:
--   NBT.newLong("RandomSeed", "123456789012345")
--
---@param name string
---@param value string|number|table|nil
---@return NBTNode node
function NBT.newLong(name, value) end

-- Creates TAG_Float.
--
---@param name string
---@param value number|nil
---@return NBTNode node
function NBT.newFloat(name, value) end

-- Creates TAG_Double.
--
---@param name string
---@param value number|nil
---@return NBTNode node
function NBT.newDouble(name, value) end

-- Creates TAG_String.
--
---@param name string
---@param value string|nil
---@return NBTNode node
function NBT.newString(name, value) end

-- Creates TAG_Byte_Array.
--
-- Value is a Lua array/table of signed bytes.
--
---@param name string
---@param value number[]|nil
---@return NBTNode node
function NBT.newByteArray(name, value) end

-- Creates TAG_Int_Array.
--
-- Value is a Lua array/table of signed 32-bit integers.
--
---@param name string
---@param value number[]|nil
---@return NBTNode node
function NBT.newIntArray(name, value) end

-- Creates TAG_Long_Array.
--
-- Value is a Lua array/table of i64 values.
-- Use decimal strings for safety.
--
---@param name string
---@param value table|nil
---@return NBTNode node
function NBT.newLongArray(name, value) end

-- Creates TAG_Compound.
--
-- Example:
--   local c = NBT.newCompound("Player")
--   NBT.setChild(c, NBT.newInt("Health", 20))
--
---@param name string|nil
---@return NBTNode compound
function NBT.newCompound(name) end

-- Creates TAG_List.
--
-- element_id must be the tag id every list item will use.
--
-- Example:
--   local list = NBT.newList("Names", NBT.TAG_String)
--   NBT.listAppend(list, "Steve")
--
---@param name string|nil
---@param element_id number|nil
---@param value table|nil
---@return NBTNode list
function NBT.newList(name, element_id, value) end

-- Creates an unnamed list element node.
--
-- Example:
--   local item = NBT.newListElement(NBT.TAG_String, "hello")
--
---@param element_id number
---@param value any
---@param extra table|nil
---@return NBTNode node
function NBT.newListElement(element_id, value, extra) end

-- Lower-level list-node maker used by newListElement.
--
---@param element_id number
---@param value any
---@param extra table|nil
---@return NBTNode node
function NBT.makeListNode(element_id, value, extra) end

-- ============================================================================
-- Editing helpers
-- ============================================================================

-- Adds or replaces a child inside a TAG_Compound.
--
-- Keeps compound.order updated for stable save order.
--
-- Example:
--   NBT.setChild(root, NBT.newString("LevelName", "My Edited World"))
--
---@param compound NBTNode
---@param child NBTNode
---@return NBTNode child
function NBT.setChild(compound, child) end

-- Generic set helper.
--
-- Example:
--   NBT.setValue(root, "SpawnX", NBT.TAG_Int, 100)
--
---@param compound NBTNode
---@param name string
---@param id number
---@param value any
---@param extra table|nil
---@return NBTNode child
function NBT.setValue(compound, name, id, value, extra) end

-- Removes a child from a TAG_Compound.
--
-- Example:
--   NBT.removeChild(root, "SomeOldTag")
--
---@param compound NBTNode
---@param name string
function NBT.removeChild(compound, name) end

-- Gets a child node from a TAG_Compound.
--
-- Example:
--   local node = NBT.getChild(root, "LevelName")
--
---@param compound NBTNode
---@param name string
---@return NBTNode|nil child
function NBT.getChild(compound, name) end

-- Gets only the .value from a child node.
--
-- Example:
--   local name = NBT.getValue(root, "LevelName", "Unknown")
--
---@param compound NBTNode
---@param name string
---@param default any
---@return any value
function NBT.getValue(compound, name, default) end

-- Checks whether a compound has a named child.
--
---@param compound NBTNode
---@param name string
---@return boolean exists
function NBT.hasChild(compound, name) end

-- Iterates compound children in saved order when possible.
--
-- Example:
--   NBT.eachCompound(root, function(name, child, index)
--       print(index, name, child.tag)
--   end)
--
---@param compound NBTNode
---@param fn fun(name:string, child:NBTNode, index:number)
function NBT.eachCompound(compound, fn) end

-- Appends a value or list-element node to TAG_List.
--
-- Example:
--   local list = NBT.newList("Names", NBT.TAG_String)
--   NBT.listAppend(list, "first")
--
---@param list_node NBTNode
---@param item_or_value any
---@return NBTNode item
function NBT.listAppend(list_node, item_or_value) end

-- Removes an item from TAG_List.
--
---@param list_node NBTNode
---@param index number
---@return NBTNode removed
function NBT.listRemove(list_node, index) end

-- Tries to infer list element id from the first list element.
--
---@param list table
---@return number element_id
function NBT.inferListElementId(list) end

-- Converts an NBT node tree to plain Lua tables/values.
--
-- This removes id/tag/name metadata.
--
-- Example:
--   local plain = NBT.toLua(root)
--   print(plain.LevelName)
--
---@param node NBTNode
---@return any value
function NBT.toLua(node) end

-- Dumps an NBT tree as readable text.
--
-- Example:
--   print(NBT.dump(root))
--
---@param node NBTNode
---@param indent string|nil
---@return string text
function NBT.dump(node, indent) end

-- Returns a readable tag name for a tag id.
--
---@param id number
---@return string name
function NBT.tagName(id) end

-- Same as tagName. Kept as a convenience alias.
--
---@param id number
---@return string name
function NBT.prettyType(id) end

-- ============================================================================
-- Reader API
-- ============================================================================

---@class NBTReader
NBT.Reader = {}

-- Creates a binary reader.
--
-- Args:
--   data: binary string
--   endian: "be" or "le"
--   pos: optional starting byte position, default 1
--   long_as: "string", "number", or "table"
--
-- Example:
--   local r = NBT.Reader.new(data, "le")
--
---@param data string
---@param endian string|nil
---@param pos number|nil
---@param long_as string|nil
---@return NBTReader reader
function NBT.Reader.new(data, endian, pos, long_as) end

-- Returns remaining unread bytes.
--
---@return number count
function NBT.Reader:remaining() end

-- Returns current read position.
--
---@return number pos
function NBT.Reader:tell() end

-- Sets current read position.
--
---@param pos number
function NBT.Reader:seek(pos) end

-- Skips n bytes.
--
---@param n number
function NBT.Reader:skip(n) end

-- Throws if fewer than n bytes remain.
--
---@param n number
function NBT.Reader:need(n) end

-- Reads n raw bytes.
--
---@param n number
---@return string bytes
function NBT.Reader:readBytes(n) end

-- Peeks unsigned byte without advancing.
--
---@return number value
function NBT.Reader:peekU8() end

-- Reads unsigned 8-bit integer.
--
---@return number value
function NBT.Reader:readU8() end

-- Reads signed 8-bit integer.
--
---@return number value
function NBT.Reader:readI8() end

-- Reads unsigned 16-bit integer.
--
---@return number value
function NBT.Reader:readU16() end

-- Reads signed 16-bit integer.
--
---@return number value
function NBT.Reader:readI16() end

-- Reads unsigned 32-bit integer.
--
---@return number value
function NBT.Reader:readU32() end

-- Reads signed 32-bit integer.
--
---@return number value
function NBT.Reader:readI32() end

-- Reads signed 64-bit integer.
--
-- Return depends on long_as:
--   "string" -> decimal string
--   "number" -> number when safe, string when too large
--   "table"  -> { bytes = {...}, decimal = "..." }
--
---@return string|number|table value
function NBT.Reader:readI64() end

-- Reads 8 bytes for a signed long and returns them in big-endian order.
--
---@return number[] bytes
function NBT.Reader:readLongBytesBE() end

-- Reads 32-bit float.
--
---@return number value
function NBT.Reader:readFloat() end

-- Reads 64-bit double.
--
---@return number value
function NBT.Reader:readDouble() end

-- Reads NBT string.
--
-- NBT string format:
--   uint16 length
--   raw bytes
--
---@return string value
function NBT.Reader:readString() end

-- ============================================================================
-- Writer API
-- ============================================================================

---@class NBTWriter
NBT.Writer = {}

-- Creates a binary writer.
--
-- Args:
--   endian: "be" or "le"
--
-- Example:
--   local w = NBT.Writer.new("le")
--   w:writeI32(123)
--   local bytes = w:toString()
--
---@param endian string|nil
---@return NBTWriter writer
function NBT.Writer.new(endian) end

-- Writes raw bytes.
--
---@param s string
function NBT.Writer:writeBytes(s) end

-- Returns final binary string.
--
---@return string bytes
function NBT.Writer:toString() end

-- Returns current byte length.
--
---@return number len
function NBT.Writer:length() end

-- Writes unsigned 8-bit integer.
--
---@param n number
function NBT.Writer:writeU8(n) end

-- Writes signed 8-bit integer.
--
---@param n number
function NBT.Writer:writeI8(n) end

-- Writes unsigned 16-bit integer.
--
---@param n number
function NBT.Writer:writeU16(n) end

-- Writes signed 16-bit integer.
--
---@param n number
function NBT.Writer:writeI16(n) end

-- Writes unsigned 32-bit integer.
--
---@param n number
function NBT.Writer:writeU32(n) end

-- Writes signed 32-bit integer.
--
---@param n number
function NBT.Writer:writeI32(n) end

-- Writes signed 64-bit integer.
--
-- Value can be:
--   number
--   decimal string
--   { bytes = {b1,b2,b3,b4,b5,b6,b7,b8} }
--
---@param value string|number|table
function NBT.Writer:writeI64(value) end

-- Writes 32-bit float.
--
---@param value number
function NBT.Writer:writeFloat(value) end

-- Writes 64-bit double.
--
---@param value number
function NBT.Writer:writeDouble(value) end

-- Writes NBT string.
--
---@param value string
function NBT.Writer:writeString(value) end

-- ============================================================================
-- Numeric / byte helper API
-- ============================================================================

-- Copies an array of bytes/numbers.
--
---@param t table
---@return table out
function NBT.copyBytes(t) end

-- Reverses an array of bytes/numbers.
--
---@param t table
---@return table out
function NBT.reverseBytes(t) end

-- Returns true when all bytes are zero.
--
---@param bytes number[]
---@return boolean ok
function NBT.allZero(bytes) end

-- Converts unsigned big-endian bytes to a decimal string.
--
---@param bytes number[]
---@return string decimal
function NBT.unsignedBytesToDecimal(bytes) end

-- Converts two's-complement big-endian bytes into magnitude bytes.
--
---@param bytes number[]
---@return number[] magnitude
function NBT.twosComplementMagnitude(bytes) end

-- Packs 4 big-endian bytes into a Lua number.
--
---@param b1 number
---@param b2 number
---@param b3 number
---@param b4 number
---@return number value
function NBT.beBytesToU32(b1, b2, b3, b4) end

-- Converts signed i64 big-endian bytes to decimal string.
--
---@param bytes number[]
---@return string decimal
function NBT.signedLongDecimal(bytes) end

-- Converts signed i64 big-endian bytes to number when safe,
-- otherwise decimal string.
--
---@param bytes number[]
---@return number|string value
function NBT.longBytesToNumberOrString(bytes) end

-- Converts signed i64 value to 8 big-endian bytes.
--
---@param value string|number|table
---@return number[] bytes
function NBT.signedLongToBytesBE(value) end

-- Cleans integer decimal string/number.
--
-- Example:
--   NBT.cleanIntegerDecimalString("+000123", "test") -> "123"
--
---@param value string|number
---@param what string|nil
---@return string decimal
function NBT.cleanIntegerDecimalString(value, what) end

-- Compares absolute decimal values.
--
-- Returns:
--   -1 if a < b
--    0 if a == b
--    1 if a > b
--
---@param a string|number
---@param b string|number
---@return number result
function NBT.decimalCompareAbs(a, b) end

-- Divides decimal string by a small integer.
--
-- Returns quotient string and remainder number.
--
---@param dec string
---@param divisor number
---@return string quotient
---@return number remainder
function NBT.decimalDivModSmall(dec, divisor) end

-- Converts unsigned decimal string to fixed-width big-endian bytes.
--
---@param dec string|number
---@param width number
---@return number[] bytes
function NBT.decimalToUnsignedBytesBE(dec, width) end

-- Converts bytes to two's-complement bytes.
--
---@param bytes number[]
---@return number[] out
function NBT.twosComplementBytes(bytes) end

-- Returns sign bit of a number.
--
-- Returns 1 for negative numbers, otherwise 0.
--
---@param n number
---@return number sign
function NBT.numberSignBit(n) end

-- Floor log2 helper.
--
---@param x number
---@return number exp
function NBT.floorLog2(x) end

-- Converts Lua number to raw IEEE-754 float32 bits as u32.
--
---@param value number
---@return number u32
function NBT.floatToU32(value) end

-- Converts Lua number to IEEE-754 double bytes in big-endian order.
--
---@param value number
---@return number[] bytes
function NBT.doubleToBytesBE(value) end

-- Validation helper.
--
---@param n number
---@param what string|nil
function NBT.assertInteger(n, what) end

-- Validation helper.
--
---@param n number
---@param minv number
---@param maxv number
---@param what string|nil
function NBT.assertRange(n, minv, maxv, what) end

-- Throws if len is negative.
--
---@param len number
---@param what string
function NBT.checkLength(len, what) end

return NBT
