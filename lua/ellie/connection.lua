local IGNORE_CALL = "IGNORE_CALL"

local M = {}

local function termopen(command, opts)
	if vim.fn.has("nvim-0.12") == 1 then
		return vim.fn.jobstart(
			command,
			vim.tbl_extend("error", opts, {
				term = true,
			})
		)
	else
		---@diagnostic disable-next-line: deprecated
		return vim.fn.termopen(command, opts)
	end
end

function M.new(key, reference_bufnr)
	local instance = setmetatable({
		key = key,
		_reference_bufnr = reference_bufnr or vim.fn.bufnr("%"),
		_job_id = nil,
		_state = nil,
		_pending_line = "",
		_pending_output_buffer = {},
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
	local suffix, _ = string.gsub(vim.fn.reltimestr(vim.fn.reltime()), "[.]", "_")
	local session_name = "ellie_" .. suffix
	local command = vim.iter({
		Config.buffer_to_cmd(self._reference_bufnr) or Config.cmd,
		{ "--dot-iex", iex_path },
		{ "--sname", session_name },
		{ "--remsh", self.key },
	})
		:flatten()
		:totable()

	vim.cmd([[-tabnew]])
	self._bufnr = vim.fn.bufnr("%")
	self._job_id = termopen(command, {
		stdin = "pipe",
		on_stdout = function(...)
			self:_on_output(...)
		end,
		on_exit = function()
			self:_on_exit()
		end,
	})
	vim.bo.bufhidden = "hide"
	vim.cmd.hide()
end

---@param lines string[]
function M:_on_output(_, lines)
	for i, line in ipairs(lines) do
		if i == 1 then
			line = self._pending_line .. line
		end
		self._pending_line = line

		local prompt_match = line:match("<~ellie:(.+)~> ")

		if self._last_sent then
			if vim.endswith(line, self._last_sent) then
				self._last_sent = nil
			end
		elseif prompt_match then
			local is_repl_header = not self._state
			self._state = prompt_match

			if is_repl_header then
				-- NOTE: There's some preamble before the first prompt that we are just
				-- igoring in this block. It might be useful for debugging to parse the
				-- versions, but for now... let's ignore.
				self._pending_output_buffer = {}
			else
				self:_submit_output_buffer()
			end
		elseif i < #lines then
			self._pending_output_buffer[#self._pending_output_buffer + 1] = vim.trim(line)
		end
	end
end

function M:_on_exit()
	require("ellie.connections").set(self.key, nil)
	self._job_id = nil
	self._bufnr = nil
end

function M:_submit_output_buffer()
	local buffer = self._pending_output_buffer
	self._pending_output_buffer = {}

	if #self._response_queue > 0 then
		local handler = table.remove(self._response_queue, 0)
		if handler and handler ~= IGNORE_CALL then
			handler(buffer)
		else
			print("OUTPUT:", vim.inspect(buffer))
		end
	end
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

	-- NOTE: Apparently, appending nil to a list in lua just... doesn't?
	-- Or, it sorta does, but doesn't affect the #length. So instead we use a sentinel
	-- value to represent queue items that should ignore the response
	self._response_queue[#self._response_queue + 1] = on_response or IGNORE_CALL

	vim.fn.chansend(self._job_id, to_send)
end

function M:stop()
	assert(self._job_id, "Not started")
	vim.fn.jobstop(self._job_id)
end

return M
