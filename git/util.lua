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

local YIELD_READ_SYM = {}

local function newYieldReader(initData)
	local buffer = initData -- nil means EOF

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
				d = coroutine.yield(YIELD_READ_SYM)
				if not d then
					buffer = nil
					return nil
				end
			until #d > 0
			buffer = d:sub(2)
			return d:byte(1)
		end

		while #buffer < count do
			local d = coroutine.yield(YIELD_READ_SYM)
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
			local d = coroutine.yield(YIELD_READ_SYM)
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
	if coroutine.status(thread) == 'dead' then
		return
	end
	data = {data}
	while true do
		res = table.pack(coroutine.resume(thread, table.unpack(data, 1, data.n)))
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
	end
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

local function mustRead(reader, count, errMessage)
	local data = reader.read(count)
	if not data or count and #data < count then
		error(errMessage or 'EOF', 2)
	end
	return data
end

return {
	newYieldReader = newYieldReader,
	resumeYieldReader = resumeYieldReader,
	newTeeReader = newTeeReader,
	mustRead = mustRead,
}
