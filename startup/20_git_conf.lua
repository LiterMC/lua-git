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

--[[- Register the git command completions

]]

package.path = package.path .. ';/modules/?;/modules/?.lua;/modules/?/init.lua'

local function registerShellPath()
	local gitPath = package.searchpath('git.programs.git', package.path)
	if not gitPath then
		printError('failed to register git shell path: package "git.programs.git" not found')
		return
	end
	shell.setPath(shell.path() .. ':' .. fs.getDir(gitPath))
end

local function registerCompletion()
	local ok, gitCompletion = pcall(require, 'git.completion.git')
	if not ok then
		printError(gitCompletion)
		return
	end
	local res
	ok, res = pcall(gitCompletion.register)
	if not ok then
		printError('failed to register completion for `git`:', res)
	end
end

do
	registerShellPath()
	registerCompletion()
end
