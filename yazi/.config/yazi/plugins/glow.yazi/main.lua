local M = {}

-- glow can't render a line range (it renders the whole doc), so re-running it on
-- every scroll froze the UI while J/K was held. Cache the rendered lines in the
-- plugin's sync state (module upvalues don't survive across peeks in the preview
-- worker), and slice inside the sync closure so each scroll only ships what is
-- needed across. Keyed by file + mtime + width.
local set_cache = ya.sync(function(st, sig, lines, blocks)
	st.sig, st.lines, st.blocks = sig, lines, blocks
end)

-- Returns nil on a cache miss, else { lines, from, clamp, img }:
--   from  = index of the first visible line (after clamping an over-scroll)
--   clamp = skip to re-emit when over-scrolled (nil otherwise)
--   lines = rendered lines from `from` on — twice the height, so text below a
--           picture can still fill the pane after the image block is dropped
--   img   = the first image block with any line on screen, or nil
local get_window = ya.sync(function(st, sig, skip, height)
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

	local lines = {}
	for i = from, math.min(from + 2 * height - 1, n) do
		lines[#lines + 1] = st.lines[i]
	end

	local img
	for _, b in ipairs(st.blocks) do
		if b.first > from + height - 1 then
			break
		elseif b.last >= from then
			img = b
			break
		end
	end
	return { lines = lines, from = from, clamp = clamp, img = img }
end)

local IMAGE_EXT = {
	png = true, jpg = true, jpeg = true, gif = true, webp = true,
	bmp = true, tif = true, tiff = true, avif = true, heic = true,
}

-- glow can't draw pictures: it prints an image as "Image: alt → /abs/path",
-- wraps the path over several lines, and tags each of those lines with an
-- OSC 8 hyperlink whose target is the original `src` and whose params carry a
-- per-image id. Group consecutive lines carrying the same link into one block.
---@return { first: integer, last: integer, url: string }[]
local function image_blocks(lines)
	local blocks, cur = {}, nil
	for i, line in ipairs(lines) do
		local key, url
		for params, uri in line:gmatch("\27%]8;([^;]*);([^\27\7]*)") do
			local ext = uri:match("%.(%w+)$")
			if uri ~= "" and ext and IMAGE_EXT[ext:lower()] then
				key, url = params .. ";" .. uri, uri
				break
			end
		end
		if key and cur and cur.key == key and cur.last == i - 1 then
			cur.last = i
		elseif key then
			cur = { key = key, first = i, last = i, url = url }
			blocks[#blocks + 1] = cur
		else
			cur = nil
		end
	end
	for _, b in ipairs(blocks) do
		b.key = nil
	end
	return blocks
end

-- Resolve an image `src` like a Markdown renderer: relative to the file's
-- directory. Remote images aren't fetched (nil).
local function resolve(file_url, src)
	if src:match("^%a[%w+.-]*://") then
		return nil
	end
	src = src:gsub("%%(%x%x)", function(h)
		return string.char(tonumber(h, 16))
	end)
	if src:sub(1, 1) == "~" then
		src = os.getenv("HOME") .. src:sub(2)
	elseif src:sub(1, 1) ~= "/" then
		src = tostring(file_url.parent) .. "/" .. src
	end
	return Url(src)
end

-- The caption line reads "Image: <alt> → /abs/path…" (glow closes the alt's
-- hyperlink before " →"). Keep only "Image: <alt>"; with an empty alt glow
-- prints just the path, so show a plain "Image".
local function clean_caption(line)
	local cut = line:find(" →", 1, true)
	if cut then
		return line:sub(1, cut - 1) .. "\27[m"
	end
	return (line:match("^(%s*)") or "") .. "\27[38;5;243mImage\27[m"
end

local function join(lines, from, to)
	local out = {}
	for i = from, math.min(to, #lines) do
		out[#out + 1] = lines[i]
	end
	return table.concat(out, "\n")
end

function M:peek(job)
	local cha = job.file.cha
	local sig = string.format("%s@%s@%d", tostring(job.file.url), tostring(cha and cha.mtime or 0), job.area.w)

	local w = get_window(sig, job.skip, job.area.h)
	if w == nil then
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
		set_cache(sig, lines, image_blocks(lines))
		w = get_window(sig, job.skip, job.area.h)
	end

	-- Re-emit only when over-scrolled (clamp changes the skip), avoiding a loop.
	if w.clamp then
		ya.emit("peek", { w.clamp, only_if = job.file.url })
	end

	-- Show the first picture on screen right under its caption line (the
	-- wrapped path lines are dropped; at the top edge if the caption has
	-- scrolled off), with the text after it below. yazi shows one image at a
	-- time (a new one erases the last), so scrolling on (J) brings the next in.
	local area = job.area
	if w.img then
		local above = math.max(0, w.img.first - w.from + 1) -- visible lines down to the caption
		local room = area.h - above
		local url = resolve(job.file.url, w.img.url)
		if url and room >= 4 and fs.cha(url) then
			if above > 0 then
				w.lines[above] = clean_caption(w.lines[above])
			end
			local shown = ya.image_show(url, ui.Rect {
				x = area.x,
				y = area.y + above,
				w = area.w,
				h = math.min(room, math.max(6, math.floor(area.h * 0.6))),
			})
			if shown then
				local below_y = area.y + above + shown.h
				local below_h = math.max(0, area.y + area.h - below_y)
				local after = w.img.last - w.from + 2 -- first line after the image block
				return ya.preview_widget(job, {
					ui.Text.parse(join(w.lines, 1, above)):area(ui.Rect { x = area.x, y = area.y, w = area.w, h = above }),
					ui.Text.parse(join(w.lines, after, after + below_h - 1))
						:area(ui.Rect { x = area.x, y = below_y, w = area.w, h = below_h }),
				})
			end
		end
	end

	-- Text only. ui.Clear first: a picture shown by an earlier peek of this file
	-- would otherwise stay on screen.
	ya.preview_widget(job, { ui.Clear(area), ui.Text.parse(join(w.lines, 1, area.h)):area(area) })
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
