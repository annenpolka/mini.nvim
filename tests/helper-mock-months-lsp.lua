local months = {}

--stylua: ignore start
months.names = {
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'
}

months.data = {
  January   = { documentation = 'Month #01' },
  February  = { documentation = 'Month #02' },
  March     = { documentation = 'Month #03' },
  April     = { documentation = 'Month #04' },
  May       = { documentation = 'Month #05' },
  June      = { documentation = 'Month #06' },
  July      = { documentation = 'Month #07' },
  August    = { documentation = 'Month #08' },
  September = { documentation = 'Month #09' },
  October   = { documentation = 'Month #10' },
  November  = { documentation = 'Month #11' },
  December  = { documentation = 'Month #12' },
}
--stylua: ignore end

months.requests = {
  ['textDocument/completion'] = function(params)
    local items = {}
    for i, month in ipairs(months.names) do
      table.insert(items, { label = month, kind = 1, sortText = ('%03d'):format(i) })
    end

    return { { result = { items = items } } }
  end,

  ['completionItem/resolve'] = function(params)
    params.documentation = { kind = 'markdown', value = months.data[params.label].documentation }
    return { { result = params } }
  end,

  ['textDocument/signatureHelp'] = function(params)
    local n_line, n_col = params.position.line, params.position.character
    local line = vim.api.nvim_buf_get_lines(0, n_line, n_line + 1, false)[1]
    line = line:sub(1, n_col)

    local after_open_paren = line:match('%(.*$') or line
    local after_close_paren = line:match('%).*$') or line

    -- Stop showing signature help after closing bracket
    if after_close_paren:len() < after_open_paren:len() then
      return { {} }
    end

    -- Compute active parameter id by counting number of ',' from latest '('
    local _, active_param_id = after_open_paren:gsub('%,', '%,')

    -- What is displayed in signature help
    local label = 'function(param1, param2, param3)'
    local documentation = '\nFunction for testing `signatureHelp`'

    -- Extent of parameters (used for highlighting)
    local parameters = { { label = { 9, 15 } }, { label = { 17, 23 } }, { label = { 25, 31 } } }

    -- Construct output
    local signature = {
      activeParameter = active_param_id,
      documentation = { kind = 'markdown', value = documentation },
      label = label,
      parameters = parameters,
    }
    return { { result = { signatures = { signature } } } }
  end,
}

-- Replace builtin functions with custom testable ones ========================
vim.lsp.buf_request_all = function(bufnr, method, params, callback)
  local requests = months.requests[method]
  if requests == nil then
    return
  end
  callback(requests(params))
end

vim.lsp.buf_get_clients = function(bufnr)
  return {
    {
      resolved_capabilities = { completion = true, signature_help = true },
      server_capabilities = {
        completionProvider = { triggerCharacters = { '.' } },
        signatureHelpProvider = { triggerCharacters = { '(', ',' } },
      },
    },
  }
end
