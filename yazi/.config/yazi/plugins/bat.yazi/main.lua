local M = {}

-- Global "diff mode". When on, files with git changes preview as a delta diff
-- (green add / red delete / deleted lines) instead of the bat file view. Shared
-- between the entry (key toggle) and peek via the plugin's sync state.
local toggle_diff = ya.sync(function(st)
	st.diff = not st.diff
	return st.diff
end)
local diff_on = ya.sync(function(st)
	return st.diff or false
end)

-- Line ranges ("<from>:<to>") changed vs HEAD, for bat's --highlight-line so the
-- full line background is tinted. Empty when not a git repo, on an unborn HEAD,
-- or with no changes (untracked files produce no diff here).
local function changed_ranges(url)
	local out = Command("git")
		:cwd(url.parent and tostring(url.parent) or ".")
		:arg({ "--no-optional-locks", "diff", "--no-color", "-U0", "HEAD", "--", tostring(url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	local ranges = {}
	if not out then
		return ranges
	end
	-- Hunk header: @@ -old,n +new,m @@  (the ",n"/",m" are omitted when 1)
	for from, count in out.stdout:gmatch("@@ %-%d+,?%d* %+(%d+),?(%d*) @@") do
		local f = tonumber(from)
		local c = tonumber(count) or 1
		if f and c > 0 then
			ranges[#ranges + 1] = f .. ":" .. (f + c - 1)
		end
	end
	return ranges
end

-- bat file view: syntax highlight + git change markers, a vertical rule, and a
-- tinted background on changed lines (custom theme's brighter lineHighlight).
local function peek_bat(job)
	local start = job.skip + 1
	-- `grid` draws a top + bottom border row, so leave room for 2 fewer lines.
	local limit = math.max(1, job.area.h - 2)

	local args = {
		"--color=always",
		"--style=numbers,changes,grid",
		"--theme=Monokai Extended Origin",
		"--paging=never",
		"--terminal-width=" .. job.area.w,
		"--line-range=" .. start .. ":" .. (start + limit - 1),
	}
	for _, r in ipairs(changed_ranges(job.file.url)) do
		args[#args + 1] = "--highlight-line=" .. r
	end
	args[#args + 1] = tostring(job.file.url)

	local output, err = Command("bat"):arg(args):stdout(Command.PIPED):stderr(Command.PIPED):output()
	if not output then
		return ya.preview_widget(job, ui.Text(string.format("bat error: %s", err)):area(job.area))
	end
	ya.preview_widget(job, ui.Text.parse(output.stdout):area(job.area))
end

-- delta diff view (vs HEAD). Diffs reflow, so render the whole thing and slice
-- for scrolling. Falls back to the bat view when there's no diff (clean file or
-- untracked).
local function peek_diff(job)
	local url = job.file.url
	local out = Command("sh")
		:arg({
			"-c",
			'cd "$1" && git --no-optional-locks diff HEAD -- "$2" | delta --paging=never '
				.. '--24-bit-color=always --line-numbers --file-style=omit --width="$3" '
				.. '--syntax-theme="Monokai Extended Origin"',
			"sh",
			url.parent and tostring(url.parent) or ".",
			tostring(url),
			tostring(job.area.w),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not out or out.stdout == "" then
		return peek_bat(job) -- no diff (clean/untracked) → show the file
	end

	-- Drop non-SGR escapes (delta emits erase-to-EOL) that ui.Text can't parse.
	local text = out.stdout:gsub("\27%[%d*K", "")

	local lines, n = {}, 0
	for line in (text .. "\n"):gmatch("(.-)\n") do
		n = n + 1
		lines[n] = line
	end

	local from = job.skip + 1
	local last_top = math.max(1, n - job.area.h + 1)
	if from > last_top then
		if job.skip ~= last_top - 1 then
			ya.emit("peek", { last_top - 1, only_if = url })
		end
		from = last_top
	end

	local sliced = {}
	for i = from, math.min(from + job.area.h - 1, n) do
		sliced[#sliced + 1] = lines[i]
	end
	ya.preview_widget(job, ui.Text.parse(table.concat(sliced, "\n")):area(job.area))
end

function M:peek(job)
	if diff_on() then
		peek_diff(job)
	else
		peek_bat(job)
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	-- Scroll exactly `job.units` lines (keymap binds J/K to seek 1 / seek -1)
	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + job.units),
		only_if = job.file.url,
	})
end

-- Toggle diff mode (bound to a key) and re-render the preview from the top.
function M:entry()
	toggle_diff()
	ya.emit("peek", { 0, force = true })
end

return M
