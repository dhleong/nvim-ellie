local M = {
	_connections = {},
}

function M.get(key)
	return M._connections[key]
end

function M.set(key, connection)
	M._connections[key] = connection
end

return M
