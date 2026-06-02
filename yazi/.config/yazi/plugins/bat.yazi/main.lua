local M = {}

function M:peek(job)
	local start = job.skip + 1
	local limit = job.area.h

	local output, err = Command("bat")
		:arg({
			"--color=always",
			"--style=numbers",
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
