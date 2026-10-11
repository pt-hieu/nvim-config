return {
	'MeanderingProgrammer/render-markdown.nvim',
	ft = { 'markdown', 'mdx' },
	dependencies = { 'nvim-treesitter/nvim-treesitter', 'nvim-tree/nvim-web-devicons' },
	opts = {
		file_types = { 'markdown', 'mdx' },
		heading = { width = 'block', right_pad = 2 },
		code = { width = 'block', left_pad = 2, right_pad = 4 },
	},
}
