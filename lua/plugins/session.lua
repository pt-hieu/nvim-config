-- Auto session management
return {
	'rmagatti/auto-session',
	lazy = false, -- Must load at startup for auto-restore
	opts = {
		auto_save = true,
		auto_restore = true,
		suppressed_dirs = { '~/', '~/.config', '/tmp' },
		session_lens = {
			load_on_setup = true,
			theme_conf = { border = true },
			previewer = false,
		},
	},
}
