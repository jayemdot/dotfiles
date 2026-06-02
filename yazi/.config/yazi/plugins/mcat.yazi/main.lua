local M = {}

function M:peek(job)
	local output, err = Command("mcat")
		:arg({
			"-c", -- force ANSI formatting on (stdout is piped)
			"-f", -- --md-image none: text only, no image-protocol escapes
			"--silent", -- no loading bars in the output
			"--theme=monokai",
			"--sc", -- bounding box (columns x rows); auto height renders the whole doc
			job.area.w .. "xauto",
			tostring(job.file.url),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return ya.preview_widget(job, ui.Text(string.format("mcat error: %s", err)):area(job.area))
	end

	-- mcat reflows markdown, so there's no bat-style --line-range. Render the
	-- whole doc once, then slice `job.skip`..+height ourselves for scrolling.
	local lines, n = {}, 0
	for line in (output.stdout .. "\n"):gmatch("(.-)\n") do
		n = n + 1
		lines[n] = line
	end

	local from = job.skip + 1
	-- Clamp so over-scrolling can't blank the pane. Re-emit only when the skip
	-- actually changes, to avoid a peek loop on short/empty files.
	local last_top = math.max(1, n - job.area.h + 1)
	if from > last_top then
		if job.skip ~= last_top - 1 then
			ya.emit("peek", { last_top - 1, only_if = job.file.url })
		end
		from = last_top
	end

	local sliced = {}
	for i = from, math.min(from + job.area.h - 1, n) do
		sliced[#sliced + 1] = lines[i]
	end

	ya.preview_widget(job, ui.Text.parse(table.concat(sliced, "\n")):area(job.area))
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
