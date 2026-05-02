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

local requests = require('git.requests')
local requestCommand = requests.requestCommand

local pktline = require('git.format.pktline')
local readPktLine = pktline.read

local function errorUnexpectedPktN(pktN, stacks)
	error(string.format('unexpected pkt-line (%04x)', pktN), stacks == 0 and 0 or ((stacks or 1) + 1))
end

-- https://git-scm.com/docs/protocol-v2#_ls_refs
local function commandLsRefs(gitUrl, capabilities, ...)
	expect(1, gitUrl, 'string')
	expect(2, capabilities, 'table')

	local args = {
		'symrefs',
		'peel',
		-- 'unborn',
	}
	for _, prefix in ipairs({...}) do
		args[#args + 1] = 'ref-prefix ' .. prefix
	end
	return requestCommand(gitUrl, 'ls-refs', capabilities, args, function(res)
		local refs = {}
		local line, pktN
		while true do
			line, pktN = readPktLine(res)
			if not line then
				if pktN ~= 0 then
					errorUnexpectedPktN(pktN)
				end
				break
			end
			local i = line:find(' ')
			if not i then
				error(string.format('malformed ref line %q', line))
			end
			local objid, refname
			local attrs = {}
			objid, line = line:sub(1, i - 1), line:sub(i + 1)
			i = line:find(' ')
			if not i then
				refname = line
			else
				refname, line = line:sub(1, i - 1), line:sub(i + 1)
				while true do
					i = line:find(' ')
					if not i then
						break
					end
					attr, line = line:sub(1, i - 1), line:sub(i + 1)
					i = attr:find(':')
					if not i then
						error(string.format('malformed ref-attribute %q', attr))
					end
					local k, v = attr:sub(1, i - 1), attr:sub(i + 1)
					attrs[k] = v
				end
				i = line:find(':')
				if not i then
					error(string.format('malformed ref-attribute %q', attr))
				end
				local k, v = line:sub(1, i - 1), line:sub(i + 1)
				attrs[k] = v
			end
			refs[refname] = {
				objid = objid,
				attrs = attrs,
			}
		end
		return refs
	end)
end

return {
	request = commandLsRefs,
}
