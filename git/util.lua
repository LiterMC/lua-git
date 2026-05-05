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

local expect = require('cc.expect')

local function yieldFor(event, ...)
	local data
	repeat
		data = table.pack(coroutine.yield(event, ...))
		if data[1] == 'terminate' then
			error('Terminated', 0)
		end
	until data[1] == event
	return table.unpack(data, 2, data.n)
end

local YIELD_READ_SYM = {}

local function newYieldReader(initData)
	expect(1, initData, 'string', 'nil')

	local buffer = initData or '' -- nil means EOF

	local reader = {}

	function reader.read(count)
		if buffer == nil then
			return nil
		end

		if count == 0 then
			return ''
		end

		if count == nil then
			if #buffer >= 1 then
				local b = buffer:byte(1)
				buffer = buffer:sub(2)
				return b
			end
			local d
			repeat
				d = yieldFor(YIELD_READ_SYM)
				if not d then
					buffer = nil
					return nil
				end
			until #d > 0
			buffer = d:sub(2)
			return d:byte(1)
		end

		while #buffer < count do
			local d = yieldFor(YIELD_READ_SYM)
			if not d then
				local r = buffer
				buffer = nil
				return r
			end
			buffer = buffer .. d
		end
		local r = buffer:sub(1, count)
		buffer = buffer:sub(count + 1)
		return r
	end

	function reader.readAll()
		local buf = ''
		while true do
			local d = yieldFor(YIELD_READ_SYM)
			if not d then
				break
			end
			buf = buf .. d
		end
		return buf
	end

	return reader
end

local function resumeYieldReader(thread, data)
	expect(1, thread, 'thread')
	expect(2, data, 'string')

	if coroutine.status(thread) == 'dead' then
		return
	end
	data = {YIELD_READ_SYM, data}
	while true do
		local res = table.pack(coroutine.resume(thread, table.unpack(data, 1, data.n)))
		if not res[1] then
			error(res[2], 0)
		end
		if res[2] == YIELD_READ_SYM then
			return
		end
		if coroutine.status(thread) == 'dead' then
			return
		end
		data = table.pack(coroutine.yield(table.unpack(res, 2, res.n)))
		if data[1] == 'terminate' then
			error('Terminated', 0)
		end
	end
end

local function newCounterWriter()
	local writer = {}
	local count = 0

	function writer.write(data)
		if type(data) == 'number' then
			count = count + 1
		else
			count = count + #data
		end
	end

	function writer.get()
		return count
	end

	function writer.getAndReset()
		local v = count
		count = 0
		return v
	end

	return writer
end

local function newTeeReader(rawReader, writer)
	if not writer.write then
		expect(2, writer, 'writer')
	end

	local reader = {}

	if rawReader.read then
		function reader.read(count)
			local d = rawReader.read(count)
			if d then
				writer.write(d)
			end
			return d
		end
	end

	if rawReader.readAll then
		function reader.readAll()
			local d = rawReader.readAll()
			writer.write(d)
			return d
		end
	end

	return reader
end

local function newMultiWriter(...)
	local writers = {...}
	if type(writers[1]) ~= 'table' or not writers[1].write then
		expect(1, writers[1], 'writer')
	end

	for i, w in ipairs(writers) do
		if type(w) ~= 'table' or not w.write then
			expect(i, w, 'writer')
		end
	end

	local writer = {}

	function writer.write(data)
		for _, w in ipairs(writers) do
			w.write(data)
		end
	end

	return writer
end

local function mustRead(reader, count, errMessage)
	local data = reader.read(count)
	if not data or count and #data < count then
		error(errMessage or 'EOF', 2)
	end
	return data
end

return {
	waitForAny = waitForAny,
	newYieldReader = newYieldReader,
	resumeYieldReader = resumeYieldReader,
	newCounterWriter = newCounterWriter,
	newTeeReader = newTeeReader,
	newMultiWriter = newMultiWriter,
	mustRead = mustRead,
}
