local M = {}

function M.guess_current(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
	for _, line in ipairs(lines) do
		local m = string.match(line, "defmodule ([a-zA-Z.]+)")
		if m then
			return m
		end
	end

	return nil
end

return M
