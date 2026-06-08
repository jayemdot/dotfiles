-- git.yazi (vendored + patched): git status signs in the file list and dimmed
-- ignored entries. Configured in theme.toml [git].
require("git"):setup {
	order = 1500,
}

-- Show the repo's git branch after the path in the header — like the zsh
-- prompt's vcs_info (` (branch)` in yellow). Reads .git/HEAD directly.
local function head_branch(path)
	local f = io.open(path)
	if not f then
		return nil
	end
	local s = f:read(512) or ""
	f:close()
	return s:match("ref: refs/heads/([^\r\n]+)") or s:match("^(%x%x%x%x%x%x%x)")
end

local function git_branch(cwd)
	local dir = cwd
	while dir do
		local base = tostring(dir)
		local b = head_branch(base .. "/.git/HEAD")
		if b then
			return b
		end
		-- Worktree/submodule: .git is a file `gitdir: <path>`
		local gf = io.open(base .. "/.git")
		if gf then
			local l = gf:read(1024) or ""
			gf:close()
			local gd = l:match("gitdir:%s*([^\r\n]+)")
			if gd then
				gd = gd:sub(1, 1) == "/" and gd or base .. "/" .. gd
				b = head_branch(gd .. "/HEAD")
				if b then
					return b
				end
			end
		end
		dir = dir.parent
	end
end

Header:children_add(function(self)
	local branch = git_branch(self._current.cwd)
	if not branch then
		return ""
	end
	return ui.Span(" (" .. branch .. ")"):style(ui.Style():fg("yellow"))
end, 1100, Header.LEFT)
