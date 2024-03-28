local function is_win()
	return jit.os:find("Windows")
end

local function get_path_separator()
	if is_win() then
		return "\\"
	end
	return "/"
end

local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	if is_win() then
		str = str:gsub("/", "\\")
	end
	return str:match("(.*" .. get_path_separator() .. ")")
end

local M = {}

function M.host()
	local host = vim.fn.hostname()
	local domain_start = vim.fn.stridx(host, ".")
	if domain_start ~= -1 then
		return host:sub(0, domain_start)
	end
	return host
end

---@param params ConnectionParams
function M.params_to_key(params)
	local host = params.host or M.host()
	return params.service .. "@" .. host
end

---@param params ConnectionParams|nil
function M.parse_params(params)
	local actual_params = params or require("ellie.config").buffer_to_params(vim.fn.bufnr("%"))
	if not actual_params then
		return nil
	end
	return M.params_to_key(actual_params)
end

function M.iex_path()
	local util_lua = script_path()
	local ellie = vim.fs.dirname(util_lua)
	local lua = vim.fs.dirname(ellie)
	local root = vim.fs.dirname(lua)
	return vim.fs.joinpath(root, ".iex.exs")
end

return M
