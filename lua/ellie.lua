local M = {}

---@alias ConnectionParams {service: string, host: string|nil}
---@param params ConnectionParams|nil
function M.connection(params)
	local key = require("ellie.util").parse_params(params)
	if not key then
		error("ellie: Unable to determine connection params")
	end

	local Connections = require("ellie.connections")
	local existing = Connections.get(key)
	if existing then
		return existing
	end

	local Connection = require("ellie.connection")
	local new_connection = Connection.new(key)
	Connections.set(key, new_connection)
	return new_connection
end

---@param params ConnectionParams|nil
function M.recompile(params)
	local connection = M.connection(params)
	connection:send("recompile")
end

---@param params ConnectionParams|nil
function M.reload_module(params, module_name)
	local connection = M.connection(params)
	connection:send("r " .. module_name)
end

return M
