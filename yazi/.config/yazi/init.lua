-- git.yazi: show git status as signs in the file list.
-- Plugin is installed via `ya pkg install` (pinned in package.toml).
require("git"):setup {
	order = 1500,
}
