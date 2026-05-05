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

local sha1 = require('hash.sha1')

local console = require('git.console')
local requests = require('git.requests')
local requestCommand = requests.requestCommand

local packfile = require('git.format.packfile')
local pktline = require('git.format.pktline')
local readPktLine = pktline.read

local gitUtil = require('git.util')
local resumeYieldReader = gitUtil.resumeYieldReader

local function errorUnexpectedPktN(pktN, stacks)
	error(string.format('unexpected pkt-line (%04x)', pktN), stacks == 0 and 0 or ((stacks or 1) + 1))
end

-- https://git-scm.com/docs/protocol-v2#_fetch
local function commandFetch(gitUrl, capabilities, kwargs)
	expect(1, gitUrl, 'string')
	expect(2, capabilities, 'table')
	expect(3, kwargs, 'table')

	console.setCursorBlink(true)

	local hashMethod = sha1

	-- TODO: support other request / response sections

	local args = {}
	for _, want in ipairs(kwargs.wants) do
		args[#args + 1] = 'want ' .. want
	end
	args[#args + 1] = 'done'

	local packdata = nil

	local packfileDataProcessor = coroutine.create(function()
		local reader = gitUtil.newYieldReader()
		packdata = packfile.read(reader, hashMethod)
	end)
	coroutine.resume(packfileDataProcessor)

	local remoteConsole = console.newSubConsole('rmt: ')
	local processors = {}

	do
		local packfileChannels = {}
		packfileChannels[0x01] = function(data)
			resumeYieldReader(packfileDataProcessor, data)
		end
		packfileChannels[0x02] = remoteConsole.write
		packfileChannels[0x03] = function(data)
			error('remote: ' .. data, 0)
		end

		processors['packfile'] = function(data)
			local channel = data:byte(1)
			local handler = packfileChannels[channel]
			if not handler then
				error(string.format('unexpected packfile message in channel (%d)', channel))
			end
			return handler(data:sub(2))
		end
	end

	requestCommand(gitUrl, 'fetch', capabilities, args, function(res)
		local pktline, pktN
		local isEOF = false
		while not isEOF do
			pktline, pktN = readPktLine(res)
			if not pktline then
				errorUnexpectedPktN(pktN)
			end
			local processor = processors[pktline]
			if not processor then
				error(string.format('unknown pkt section: %s', pktline))
			end
			while true do
				pktline, pktN = readPktLine(res, true)
				if not pktline then
					isEOF = pktN == 0
					if not isEOF and pktN ~= 1 then
						errorUnexpectedPktN(pktN)
					end
					break
				end
				processor(pktline)
			end
		end
	end)

	if coroutine.status(packfileDataProcessor) == 'suspended' then
		coroutine.resume(packfileDataProcessor, nil) -- send EOF signal
	end
	return packdata
end

return {
	request = commandFetch,
}
