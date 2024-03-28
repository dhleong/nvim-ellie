local default_config = {
	cmd = { "iex" },
	buffer_to_cmd = function(_)
		return require("ellie.config").cmd
	end,
	buffer_to_params = function(_)
		return nil
	end,
}

local M = {
	_config = vim.deepcopy(default_config),
}

function M.update(updated_config)
	M._config = vim.tbl_deep_extend("force", M._config, updated_config)
end

return setmetatable(M, {
	__index = function(_, k)
		return M._config[k]
	end,
})
