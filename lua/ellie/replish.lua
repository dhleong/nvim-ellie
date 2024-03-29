local History = {
	---@type string[]|nil
	_saved = nil,
}

function History._get_active()
	local old = {}
	local limit = vim.fn.histnr("@")
	if limit > 0 then
		for i = 1, limit do
			table.insert(old, vim.fn.histget("@", i))
		end
	end
	return old
end

function History._set_active(entries)
	vim.fn.histdel("@")

	for _, entry in ipairs(entries) do
		vim.fn.histadd("@", entry)
	end
end

function History.make_active(entries)
	History.save()
	History._set_active(entries)
end

function History.save()
	if not History._saved then
		History._saved = History._get_active()
	end
end

function History.restore()
	if History._saved then
		History._set_active(History._saved)
		History._saved = nil
	end
end

local function perform_input()
	return vim.fn.input(">")
end

local function input_with_history(entries)
	History.make_active(entries)

	local ok, input = pcall(perform_input)

	History.restore()

	return ok and input ~= "", input
end

local M = {
	_input_history = {},
}

function M._insert_history(input)
	for i, candidate in ipairs(M._input_history) do
		if candidate == input then
			table.remove(M._input_history, i)
			break
		end
	end
	M._input_history[#M._input_history + 1] = input
end

function M.prompt()
	local ok, input = input_with_history(M._input_history)
	if ok then
		M._insert_history(input)
	end
	return ok, input
end

return M
