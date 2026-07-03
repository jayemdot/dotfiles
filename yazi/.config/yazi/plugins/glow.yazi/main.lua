local M = {}

-- glow can't render a line range (it renders the whole doc), so re-running it on
-- every scroll froze the UI while J/K was held. Cache the rendered lines in the
-- plugin's sync state (module upvalues don't survive across peeks in the preview
-- worker), and slice inside the sync closure so each scroll only ships one
-- screenful across. Keyed by file + mtime + width.
local set_cache = ya.sync(function(st, sig, lines)
	st.sig, st.lines = sig, lines
end)

-- Returns the sliced text + the skip to clamp to (nil if no clamp), or nil on a
-- cache miss.
local slice_cache = ya.sync(function(st, sig, skip, height)
	if st.sig ~= sig then
		return nil
	end

	local n = #st.lines
	local from = skip + 1
	local last_top = math.max(1, n - height + 1)
	local clamp = from > last_top and last_top - 1 or nil
	if clamp then
		from = last_top
	end

	local out = {}
	for i = from, math.min(from + height - 1, n) do
		out[#out + 1] = st.lines[i]
	end
	return table.concat(out, "\n"), clamp
end)

function M:peek(job)
	local cha = job.file.cha
	local sig = string.format("%s@%s@%d", tostring(job.file.url), tostring(cha and cha.mtime or 0), job.area.w)

	local text, clamp = slice_cache(sig, job.skip, job.area.h)
	if text == nil then
		-- Cache miss: render once with glow, store it, then slice.
		-- CLICOLOR_FORCE=1: glow drops color (incl. code syntax highlighting)
		-- when stdout isn't a TTY, as here. $1 = width, $2 = file.
		local output, err = Command("sh")
			:arg({
				"-c",
				'CLICOLOR_FORCE=1 glow -s dark -w "$1" "$2"',
				"sh",
				tostring(job.area.w),
				tostring(job.file.url),
			})
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:output()

		if not output then
			return ya.preview_widget(job, ui.Text(string.format("glow error: %s", err)):area(job.area))
		end

		local lines, n = {}, 0
		for line in (output.stdout .. "\n"):gmatch("(.-)\n") do
			n = n + 1
			lines[n] = line
		end
		set_cache(sig, lines)
		text, clamp = slice_cache(sig, job.skip, job.area.h)
	end

	-- Re-emit only when over-scrolled (clamp changes the skip), avoiding a loop.
	if clamp then
		ya.emit("peek", { clamp, only_if = job.file.url })
	end

	ya.preview_widget(job, ui.Text.parse(text or ""):area(job.area))
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

return M
