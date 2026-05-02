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

local completion = require('cc.completion')

local gitCommands = require('git.commands')

local subCmdList = {}
do
	for cmd, data in pairs(gitCommands) do
		if not data.run then
			cmd = cmd .. ' '
		end
		subCmdList[#subCmdList + 1] = cmd
	end
	table.sort(subCmdList)
end

local function completionGit(shell, argN, partial, args)
	if argN == 1 then
		return completion.choice(partial, subCmdList)
	end
	local subCmd = gitCommands[args[2]]
	if not subCmd then
		return nil
	end
	return subCmd.completion and subCmd.completion(shell, argN - 2, partial, {table.unpack(args, 3)})
end

local function register()
	local gitPath = shell.resolveProgram('git')
	if not gitPath then
		error('program `git` not found', 0)
	end
	shell.setCompletionFunction(gitPath, completionGit)
end

return {
	register = register,
}
