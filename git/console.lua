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

local console = {}

local rawTerm = term

local lines = {
	{"", "", ""}
}
local cursorX, cursorY = 1, 1
local cursorYOffset = 0
local fgColor, bgColor = rawTerm.getTextColor(), rawTerm.getBackgroundColor()

function console.getRawTerm()
	if rawTerm == term then
		return term.current()
	end
	return rawTerm
end

local function getRawCursorPos(cursorX, cursorY)
	local w, h = rawTerm.getSize()

	local blitOffset, ry = 0, h

	local i, h2 = 0, h
	local linesN = #lines
	while i < h2 and i < linesN do
		local line = lines[linesN - i]
		local lineText = line[1]
		local wraps = math.max(math.ceil(#lineText / w) - 1, 0)
		i = i + 1
		h2 = h2 - wraps
		blitOffset = math.max(h2 - i, 0)
		if linesN - i == cursorY then
			ry = h2 - i
		end
	end

	return (cursorX - 1) % w + 1, cursorYOffset + ry - blitOffset + math.ceil(cursorX / w) - 1
end

function console.getCursorPos()
	return cursorX, cursorY
end

function console.setCursorPos(x, y)
	y = math.min(math.max(y, 1), #lines)
	x = math.min(math.max(x, 1), #lines[y][1] + 1)
	cursorX, cursorY = x, y
	rawTerm.setCursorPos(getRawCursorPos(x, y))
end

function console.getSize()
	return rawTerm.getSize()
end

function console.getCursorBlink()
	return rawTerm.getCursorBlink()
end

function console.setCursorBlink(blink)
	rawTerm.setCursorBlink(blink)
end

function console.getPaletteColor(color)
	return rawTerm.getPaletteColor(color)
end

console.getPaletteColour = console.getPaletteColor

function console.setPaletteColor(...)
	rawTerm.setPaletteColor(...)
end

console.setPaletteColour = console.setPaletteColor

function console.getTextColor()
	return fgColor
end

console.getTextColour = console.getTextColor

function console.setTextColor(color)
	fgColor = color
end

console.setTextColour = console.setTextColor

function console.getBackgroundColor()
	return bgColor
end

console.getBackgroundColour = console.getBackgroundColor

function console.setBackgroundColor(color)
	bgColor = color
end

console.setBackgroundColour = console.setBackgroundColor

function console.isColor()
	return true
end

console.isColour = console.isColor

local function redraw()
	local w, h = rawTerm.getSize()

	local blits = {}
	local blitOffset, ry = 0, h

	local i, h2 = 0, h
	local linesN = #lines
	while i < h2 and i < linesN do
		local line = lines[linesN - i]
		local lineText, lineFg, lineBg = line[1], line[2], line[3]
		local wraps = math.max(math.ceil(#lineText / w) - 1, 0)
		for j = wraps, 1, -1 do
			blits[h2 - i - j] = {lineText:sub(1, w), lineFg:sub(1, w), lineBg:sub(1, w)}
			lineText, lineFg, lineBg = lineText:sub(w + 1), lineFg:sub(w + 1), lineBg:sub(w + 1)
		end
		blits[h2 - i] = {
			lineText .. string.rep(' ', w - #lineText),
			lineFg .. colors.toBlit(fgColor):rep(w - #lineText),
			lineBg .. colors.toBlit(bgColor):rep(w - #lineText),
		}
		i = i + 1
		h2 = h2 - wraps
		blitOffset = math.max(h2 - i, 0)
		if linesN - i == cursorY then
			ry = h2 - i
		end
	end

	for y = 1, h do
		local line = blits[blitOffset + y]
		if line then
			if cursorYOffset > 0 then
				local y2 = cursorYOffset + y
				local excess = y2 - h
				if excess > 0 then
					rawTerm.scroll(excess)
					cursorYOffset = cursorYOffset - excess
					y2 = h
				end
				rawTerm.setCursorPos(1, y2)
			else
				rawTerm.setCursorPos(1, y)
			end
			rawTerm.blit(line[1], line[2], line[3])
		end
	end

	local rawX = (cursorX - 1) % w + 1
	local rawY = cursorYOffset + ry - blitOffset + math.ceil(cursorX / w) - 1
	rawTerm.setCursorPos(rawX, rawY)
end

function console.clear()
	lines = {
		{"", "", ""}
	}
	cursorX, cursorY = 1, 1
	rawTerm.clear()
	rawTerm.setCursorPos(1, 1)
end

function console.clearLine(delayRedraw)
	local line = lines[cursorY]
	line[1] = ""
	line[2] = ""
	line[3] = ""
	cursorX = 1

	if not delayRedraw then
		redraw()
	end
end

function console.blit(text, fgColors, bgColors)
	expect(1, text, 'string')
	expect(2, fgColors, 'string')
	expect(3, bgColors, 'string')
	if #text ~= #fgColors or #text ~= #bgColors then
		error('text, fgColors, and bgColors have different length', 2)
	end

	local line = lines[cursorY]

	while #text > 0 do
		local cr = text:match('^\r+')
		if cr then
			text = text:sub(#cr + 1)
			fgColors = fgColors:sub(#cr + 1)
			bgColors = bgColors:sub(#cr + 1)
			cursorX = 1
		end
		local lf = text:match('^\n+')
		if lf then
			local count = #lf
			text = text:sub(count + 1)
			fgColors = fgColors:sub(count + 1)
			bgColors = bgColors:sub(count + 1)
			local oldCursorY = cursorY
			cursorY = cursorY + count
			cursorX = 1
			for i = oldCursorY + 1, cursorY do
				lines[i] = {"", "", ""}
			end
			line = lines[cursorY]
		end
		local str = text:match('^[^\r\n]+')
		if str then
			local len = #str
			text = text:sub(len + 1)
			local strFgColors = fgColors:sub(1, len)
			fgColors = fgColors:sub(len + 1)
			local strBgColors = bgColors:sub(1, len)
			bgColors = bgColors:sub(len + 1)
			local oldCursorX = cursorX
			cursorX = cursorX + len

			local lineText, lineFg, lineBg = line[1], line[2], line[3]
			line[1] = lineText:sub(1, oldCursorX - 1) .. str .. lineText:sub(cursorX)
			line[2] = lineFg:sub(1, oldCursorX - 1) .. strFgColors .. lineFg:sub(cursorX)
			line[3] = lineBg:sub(1, oldCursorX - 1) .. strBgColors .. lineBg:sub(cursorX)
		end
	end

	redraw()
end

function console.write(text)
	expect(1, text, 'string')

	local newLineCount = 0
	local line = lines[cursorY]
	while #text > 0 do
		local cr = text:match('^\r+')
		if cr then
			text = text:sub(#cr + 1)
			cursorX = 1
		end
		local lf = text:match('^\n+')
		if lf then
			local count = #lf
			text = text:sub(count + 1)
			cursorX = 1
			local oldCursorY = cursorY
			cursorY = cursorY + count
			newLineCount = newLineCount + count
			for i = oldCursorY + 1, cursorY do
				lines[i] = {"", "", ""}
			end
			line = lines[cursorY]
		end
		local str = text:match('^[^\r\n]+')
		if str then
			local len = #str
			text = text:sub(len + 1)
			local oldCursorX = cursorX
			cursorX = cursorX + len

			local lineText, lineFg, lineBg = line[1], line[2], line[3]
			line[1] = lineText:sub(1, oldCursorX - 1) .. str .. lineText:sub(cursorX)
			line[2] = lineFg:sub(1, oldCursorX - 1) .. colors.toBlit(fgColor):rep(len) .. lineFg:sub(cursorX)
			line[3] = lineBg:sub(1, oldCursorX - 1) .. colors.toBlit(bgColor):rep(len) .. lineBg:sub(cursorX)
		end
	end

	redraw()
	return newLineCount
end

function console.print(...)
	local newLineCount = 0
	for i = 1, select('#', ...) do
		local s = tostring(select(i, ...))
		if i ~= 1 then
			console.write('\t')
		end
		newLineCount = newLineCount + console.write(s)
	end
	newLineCount = newLineCount + console.write('\n')
	return newLineCount
end

function console.printf(format, ...)
	expect(1, format, 'string')
	return console.print(string.format(format, ...))
end

function console.newSubConsole(prefix)
	prefix = prefix or ''

	local subConsole = {}

	local cursorX, cursorY = nil, nil
	local atBeginning = true

	function subConsole.getCursorPos()
		return cursorX, cursorY
	end

	function subConsole.setCursorPos(x, y)
		cursorX, cursorY = x, y
	end

	function subConsole.clearLine(delayRedraw)
		if cursorY then
			local ccx, ccy = console.getCursorPos()
			console.setCursorPos(1, cursorY)
			console.clearLine(delayRedraw)
			cursorX, cursorY = console.getCursorPos()
			console.setCursorPos(ccx, ccy)
		end
	end

	function subConsole.write(text)
		expect(1, text, 'string')

		local ccx, ccy = console.getCursorPos()
		if cursorY then
			console.setCursorPos(cursorX, cursorY)
		end

		while #text > 0 do
			local cr = text:match('^\r+')
			if cr then
				text = text:sub(#cr + 1)
				if not atBeginning then
					console.write('\r')
					atBeginning = true
				end
			end

			if #text == 0 then
				break
			end
			if atBeginning then
				if not cursorY then
					cursorX, cursorY = ccx, ccy
					console.write('\n')
					ccx, ccy = console.getCursorPos()
					console.setCursorPos(cursorX, cursorY)
				end
				console.write(prefix)
				atBeginning = false
			end

			local lf = text:match('^\n')
			if lf then
				text = text:sub(2)
				console.setCursorPos(ccx, ccy)
				cursorX, cursorY = nil, nil
				atBeginning = true
			end
			local str = text:match('^[^\r\n]+')
			if str then
				text = text:sub(#str + 1)
				console.write(str)
			end
		end

		if cursorY then
			cursorX, cursorY = console.getCursorPos()
		end
		console.setCursorPos(ccx, ccy)
	end

	return subConsole
end

function console.run(func, ...)
	local oldTerm = term.redirect(console)
	rawTerm = oldTerm
	cursorYOffset = select(2, oldTerm.getCursorPos()) - 1

	local _Gprint, _Gwrite = _G.print, _G.write
	_G.print, _G.write = console.print, console.write

	local res = table.pack(pcall(func, ...))

	_G.print, _G.write = _Gprint, _Gwrite
	term.redirect(oldTerm)
	rawTerm = term
	if #lines[cursorY][1] ~= 0 then
		_G.write('\n')
	end

	if not res[1] then
		error(res[2], 0)
	end
	return table.unpack(res, 2, res.n)
end

return console
