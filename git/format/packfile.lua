-- lua-git - Git cli implementation for CC: Tweaked
-- Copyright (C) 2026  Kevin Z <zyxkad@gmail.com>
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.
--- END HEADER

local zlib = require('compress.zlib')

local console = require('git.console')
local gitUtil = require('git.util')
local mustRead = gitUtil.mustRead

local bor, band = bit32.bor, bit32.band
local blshift, brshift = bit32.lshift, bit32.rshift

local function bytes2uint32(a, b, c, d)
	return bor(blshift(a, 24), blshift(b, 16), blshift(c, 8), d)
end

local PACK_MAGIC_HEADER = 'PACK'

local OBJ_INVALID = 0
local OBJ_COMMIT = 1
local OBJ_TREE = 2
local OBJ_BLOB = 3
local OBJ_TAG = 4
local OBJ_OFS_DELTA = 6
local OBJ_REF_DELTA = 7

local function read(reader, hashMethod)
	local digest = hashMethod.newDigest()
	local hashSize = digest.size
	reader = gitUtil.newTeeReader(reader, digest)

	-- parse packfile header
	local magicHeader = mustRead(reader, 4)
	if magicHeader ~= PACK_MAGIC_HEADER then
		error(string.format('packfile: unexpected header %q', magicHeader))
	end
	local packVersion = bytes2uint32(mustRead(reader, 4):byte(1, 4))
	local packObjCount = bytes2uint32(mustRead(reader, 4):byte(1, 4))
	local receivedCount = 0
	local receivedObjects = {}

	local recvLogFmt = 'Receiving objects: %d%% (%d/%d)\r'
	local recvCsl = console.newSubConsole()

	local function logProg()
		recvCsl.write(recvLogFmt:format(receivedCount / packObjCount * 100, receivedCount, packObjCount))
	end

	-- parse objects
	for _ = 1, packObjCount do
		local objType, uncompressedObjSize
		local refObjId = nil
		do
			local b = mustRead(reader)
			objType = band(brshift(b, 4), 0x07)
			uncompressedObjSize = band(b, 0x0f)
			local sizeBits = 4
			while band(b, 0x80) ~= 0 do
				b = mustRead(reader)
				uncompressedObjSize = bor(uncompressedObjSize, blshift(band(b, 0x7f), sizeBits))
				sizeBits = sizeBits + 7
			end
		end
		if objType == OBJ_INVALID or objType == 5 then
			error(string.format('packfile: invalid object type (%d)', objType))
		elseif objType == OBJ_OFS_DELTA then
			error('packfile: TODO OBJ_OFS_DELTA')
		elseif objType == OBJ_REF_DELTA then
			refObjId = mustRead(reader, hashSize)
		end
		local zr = zlib.newReader(reader)
		local uncompressedObj = zr.readAll()
		if #uncompressedObj ~= uncompressedObjSize then
			error(string.format('packfile: object size mismatch. expect %d, got %d', uncompressedObjSize, #uncompressedObj))
		end
		receivedCount = receivedCount + 1
		logProg()
		receivedObjects[receivedCount] = {
			type = objType,
			data = uncompressedObj,
			refObjId = refObjId,
		}
	end

	local fileHash = digest.sum()
	local checkHash = mustRead(reader, hashSize)
	if checkHash ~= fileHash then
		printError(checkHash:gsub('.', function(b) return string.format('%02x', b:byte(1)) end))
		printError(fileHash:gsub('.', function(b) return string.format('%02x', b:byte(1)) end))
		error('packfile: invalid checksum')
	end

	recvCsl.write(string.format('Receiving objects: %d%% (%d/%d), done.\n', receivedCount / packObjCount * 100, receivedCount, packObjCount))

	return {
		version = packVersion,
		objects = receivedObjects,
	}
end

return {
	OBJ_INVALID = OBJ_INVALID,
	OBJ_COMMIT = OBJ_COMMIT,
	OBJ_TREE = OBJ_TREE,
	OBJ_BLOB = OBJ_BLOB,
	OBJ_TAG = OBJ_TAG,
	OBJ_OFS_DELTA = OBJ_OFS_DELTA,
	OBJ_REF_DELTA = OBJ_REF_DELTA,
	read = read,
}
