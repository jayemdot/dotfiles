local M = {}

function M:peek(job)
	local start = job.skip + 1
	-- `grid` draws a top + bottom border row, so leave room for 2 fewer lines.
	local limit = math.max(1, job.area.h - 2)

	local output, err = Command("bat")
		:arg({
			"--color=always",
			-- `changes` adds bat's git diff markers (+/~/-) in the gutter;
			-- `grid` draws the vertical rule between line numbers and code.
			-- bat finds the repo from the file's absolute path.
			"--style=numbers,changes,grid",
			"--theme=Monokai Extended Origin",
			"--paging=never",
			"--terminal-width=" .. job.area.w,
			"--line-range=" .. start .. ":" .. (start + limit - 1),
			tostring(job.file.url),
		})
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	if not output then
		return ya.preview_widget(job, ui.Text(string.format("bat error: %s", err)):area(job.area))
	end

	ya.preview_widget(job, ui.Text.parse(output.stdout):area(job.area))
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
