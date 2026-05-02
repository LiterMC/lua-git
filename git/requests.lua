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

local constants = require('git.constants')
local pktline = require('git.format.pktline')
local readPktLine, encodePktLine = pktline.read, pktline.encode

local BASE_REQUEST_HEADERS = {
	['User-Agent'] = constants.USER_AGENT,
	['Git-Protocol'] = 'version=2',
}

local function makeHeaders(headers)
	for k, v in pairs(BASE_REQUEST_HEADERS) do
		if headers[k] == nil then
			headers[k] = v
		end
	end
	return headers
end

local function doRequest(req, onSuccess)
	local url = assert(req.url)
	http.request(req)
	local resp
	while true do
		local event, u, r = os.pullEvent()
		if event == 'http_success' and u == url then
			resp = r
			break
		elseif event == 'http_failure' and u == url then
			error(r, 2)
		end
	end
	local ok, res = pcall(onSuccess, resp)
	resp.close()
	if not ok then
		error(res, 2)
	end
	return res
end

local function errorUnexpectedPktN(pktN, stacks)
	error(string.format('unexpected pkt-line (%04x)', pktN), stacks == 0 and 0 or ((stacks or 1) + 1))
end

-- https://git-scm.com/docs/protocol-v2#_capability_advertisement
local function requestCapabilities(gitUrl)
	expect(1, gitUrl, 'string')

	local service = 'git-upload-pack'
	local url = gitUrl .. '/info/refs?service=' .. service
	return doRequest(
		{ method = 'GET', url = url, headers = BASE_REQUEST_HEADERS, binary = true },
		function(res)
			local respHeaders = res.getResponseHeaders()
			local contentType = respHeaders['Content-Type']
			if contentType ~= 'application/x-git-upload-pack-advertisement' then
				error('unknown response content-type ' .. contentType)
			end

			local line, pktN

			line = readPktLine(res)
			if line ~= '# service=' .. service then
				error('server does not support git v2 service ' .. service)
			end
			line, pktN = readPktLine(res)
			if pktN ~= 0 then
				error('unexpected pkt-line' .. (line and (': ' .. line) or string.format(' (%04x)', pktN)))
			end
			line = readPktLine(res)
			if line ~= 'version 2' then
				error('server does not support git v2 protocol')
			end

			local capabilities = {}
			while true do
				local line, pktN = readPktLine(res)
				if not line then
					if pktN ~= 0 then
						errorUnexpectedPktN(pktN)
					end
					break
				end
				local key, value
				local i = line:find('=')
				if i then
					key, value = line:sub(1, i - 1), line:sub(i + 1)
				else
					key, value = line, true
				end
				if capabilities[key] then
					-- logDebug('Capability %s already exists! old=%s new=%s', key, capabilities[key], value)
				end
				capabilities[key] = value
			end
			return capabilities
		end
	)
end

-- https://git-scm.com/docs/protocol-v2#_command_request
local function requestCommand(gitUrl, command, capabilities, args, resProcessor)
	expect(1, gitUrl, 'string')
	expect(2, command, 'string')
	expect(3, capabilities, 'table')

	local acceptableContentType = 'application/x-git-upload-pack-result'

	local url = gitUrl .. '/git-upload-pack'
	local reqData = ''
	reqData = reqData .. encodePktLine('command='..command, true)
	for k, v in pairs(capabilities) do
		reqData = reqData .. encodePktLine(v == true and k or (k .. '=' .. v))
	end
	reqData = reqData .. '0001'
	for _, v in ipairs(args) do
		reqData = reqData .. encodePktLine(v, true)
	end
	reqData = reqData .. '0000'
	-- logDebug('reqData: %s', reqData)

	return doRequest(
		{
			method = 'POST',
			url = url,
			headers = makeHeaders({
				['Content-Type'] = 'application/x-git-upload-pack-request',
				['Accept'] = acceptableContentType,
			}),
			body = reqData,
			binary = true
		},
		function(res)
			local respHeaders = res.getResponseHeaders()
			local contentType = respHeaders['Content-Type']
			if contentType ~= acceptableContentType then
				error('unknown response content-type ' .. contentType)
			end
			return resProcessor(res)
		end
	)
end

return {
	makeHeaders = makeHeaders,
	doRequest = doRequest,
	requestCapabilities = requestCapabilities,
	requestCommand = requestCommand,
}
