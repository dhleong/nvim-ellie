local M = {}

function M.new(key, reference_bufnr)
	local instance = setmetatable({
		key = key,
		_reference_bufnr = reference_bufnr or vim.fn.bufnr("%"),
		_job_id = nil,
		_state = nil,
		_response_queue = {},
	}, {
		__index = M,
	})

	instance:_start()

	return instance
end

function M:_start()
	assert(self._job_id == nil, "Already started")
	local Config = require("ellie.config")

	local iex_path = require("ellie.util").iex_path()
	local command = vim.tbl_flatten({
		Config.buffer_to_cmd(self._reference_bufnr) or Config.cmd,
		{ "--dot-iex", iex_path },
	})

	print("RUNNING", vim.inspect(command))

	vim.cmd([[-tabnew]])
	self._bufnr = vim.fn.bufnr("%")
	self._job_id = vim.fn.termopen(command, {
		stdin = "pipe",
		on_stdout = function(...)
			self:_on_output(...)
		end,
		on_exit = function(...)
			self:_on_exit(...)
		end,
	})
	vim.bo.bufhidden = "hide"
	vim.cmd.hide()
end

---@param lines string[]
function M:_on_output(_, lines)
	-- TODO: we might not receive whole lines at a time. A full line should have a blank
	-- string after it (?)
	local buffer = {}
	for _, line in ipairs(lines) do
		local prompt_match = line:match("<~ellie:(.+)~> ")
		if prompt_match then
			self._state = prompt_match
		elseif line == self._last_sent then
			self._last_sent = nil
		elseif not self._state then
		-- NOTE: There's some preamble before the first prompt that we are just
		-- igoring in this block. It might be useful for debugging to parse the
		-- versions, but for now... let's ignore.
		else
			buffer[#buffer + 1] = vim.trim(line)
		end
	end

	if #self._response_queue then
		local handler = table.remove(self._response_queue, 0)
		if handler then
			handler(buffer)
		elseif #buffer then
			print("OUTPUT:", vim.inspect(buffer))
		end
	end
end

function M:_on_exit()
	require("ellie.connections").set(self.key, nil)
	self._job_id = nil
	self._bufnr = nil
end

function M:hide()
	local bufnr = self._bufnr
	if bufnr then
		for _, winnr in ipairs(vim.fn.win_findbuf(self._bufnr)) do
			vim.api.nvim_win_hide(winnr)
		end
	end
end

function M:show()
	assert(self._bufnr, "Not started")
	vim.cmd.split()
	vim.cmd.buffer(self._bufnr)
end

function M:send(input)
	self:call(input, nil)
end

function M:call(input, on_response)
	assert(self._job_id, "Not started")

	local to_send = input .. "\r"
	self._last_sent = to_send
	self._response_queue[#self._response_queue + 1] = on_response
	vim.fn.chansend(self._job_id, to_send)
end

function M:stop()
	assert(self._job_id, "Not started")
	vim.fn.jobstop(self._job_id)
end

return M
