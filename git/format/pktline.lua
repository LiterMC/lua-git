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

local errPrefix = 'ERR '

local function read(r, isBinary)
	expect(2, isBinary, 'boolean', 'nil')

	local lenStr = r.read(4)
	if not lenStr or #lenStr ~= 4 then
		error('not enough data for pkt-line header', 2)
	end
	local len = tonumber(lenStr, 16)
	if not len then
		error(string.format('malformed pkt-line length %q', lenStr), 2)
	end
	if len < 4 then
		return nil, len
	end
	if len == 4 then
		error('malformed pkt-line length 0004', 2)
	end
	local line = r.read(len - 4)
	if not line or #line ~= len - 4 then
		error('not enough pkt-line data. expect ' .. (len - 4) .. ' got ' .. (line and #line), 2)
	end
	if not isBinary and line:sub(-1) == '\n' then
		line = line:sub(1, -2)
	end
	if line:sub(1, #errPrefix) == errPrefix then
		error('remote: ' .. line:sub(#errPrefix + 1), 2)
	end
	return line
end

local function encode(data, newLine)
	if type(data) ~= 'string' or #data == 0 then
		expect(1, data, 'non-empty-string')
	end
	expect(2, newLine, 'boolean', 'nil')

	local len = 4 + #data + (newLine and 1 or 0)
	return string.format('%04x', len) .. data .. (newLine and '\n' or '')
end

local function errorUnexpectedPktN(pktN, stacks)
	error(string.format('unexpected pkt-line (%04x)', pktN), stacks == 0 and 0 or ((stacks or 1) + 1))
end

return {
	read = read,
	encode = encode,
}
