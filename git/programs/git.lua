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

package.path = package.path .. ';../../?;../../?.lua;../../?/init.lua'

local expect = require('cc.expect')

local commands = require('git.commands')
local help = require('git.commands.help')
local console = require('git.console')

local function main(subCommand, ...)
	if subCommand == nil then
		return help.execute()
	end
	local subCmd = commands[subCommand]
	if not subCmd then
		printError(string.format('Command %q does not exists, use `git help` for help', subCmd))
		return
	end
	return subCmd.execute(...)
end

console.run(main, ...)
