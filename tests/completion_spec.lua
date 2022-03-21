local helpers = require('tests.helpers')

local child = helpers.new_child_neovim()
local eq = assert.are.same

-- Helpers with child processes
--stylua: ignore start
local load_module = function(config) child.mini_load('completion', config) end
local unload_module = function() child.mini_unload('completion') end
local reload_module = function(config) unload_module(); load_module(config) end
local set_cursor = function(...) return child.set_cursor(...) end
local get_cursor = function(...) return child.get_cursor(...) end
local set_lines = function(...) return child.set_lines(...) end
local type_keys = function(...) return child.type_keys(...) end
local sleep = function(ms) vim.loop.sleep(ms); child.loop.update_time() end
--stylua: ignore end

-- Data =======================================================================

-- Unit tests =================================================================
describe('MiniCompletion.setup()', function()
  before_each(function()
    child.setup()
    load_module()
  end)

  it('creates side effects', function()
    -- Global variable
    assert.True(child.lua_get('_G.MiniCompletion ~= nil'))

    -- Autocommand group
    eq(child.fn.exists('#MiniCompletion'), 1)

    -- Highlight groups
    assert.truthy(child.cmd_capture('hi MiniCompletionActiveParameter'):find('gui=underline'))
  end)

  it('creates `config` field', function()
    assert.True(child.lua_get([[type(_G.MiniCompletion.config) == 'table']]))

    -- Check default values
    local assert_config = function(field, value)
      eq(child.lua_get('MiniCompletion.config.' .. field), value)
    end

    assert_config('delay.completion', 100)
    assert_config('delay.info', 100)
    assert_config('delay.signature', 50)
    assert_config('window_dimensions.info.height', 25)
    assert_config('window_dimensions.info.width', 80)
    assert_config('window_dimensions.signature.height', 25)
    assert_config('window_dimensions.signature.width', 80)
    assert_config('lsp_completion.source_func', 'completefunc')
    assert_config('lsp_completion.auto_setup', true)
    eq(child.lua_get('type(_G.MiniCompletion.config.lsp_completion.process_items)'), 'function')
    eq(child.lua_get('type(_G.MiniCompletion.config.fallback_action)'), 'function')
    assert_config('mappings.force_twostep', '<C-Space>')
    assert_config('mappings.force_fallback', '<A-Space>')
    assert_config('set_vim_settings', true)
  end)

  it('respects `config` argument', function()
    -- Check setting `MiniCompletion.config` fields
    reload_module({ delay = { completion = 300 } })
    eq(child.lua_get('MiniCompletion.config.delay.completion'), 300)
  end)

  it('validates `config` argument', function()
    unload_module()

    local assert_config_error = function(config, name, target_type)
      assert.error_matches(function()
        load_module(config)
      end, vim.pesc(name) .. '.*' .. vim.pesc(target_type))
    end

    assert_config_error('a', 'config', 'table')
    assert_config_error({ delay = 'a' }, 'delay', 'table')
    assert_config_error({ delay = { completion = 'a' } }, 'delay.completion', 'number')
    assert_config_error({ delay = { info = 'a' } }, 'delay.info', 'number')
    assert_config_error({ delay = { signature = 'a' } }, 'delay.signature', 'number')
    assert_config_error({ window_dimensions = 'a' }, 'window_dimensions', 'table')
    assert_config_error({ window_dimensions = { info = 'a' } }, 'window_dimensions.info', 'table')
    assert_config_error({ window_dimensions = { info = { height = 'a' } } }, 'window_dimensions.info.height', 'number')
    assert_config_error({ window_dimensions = { info = { width = 'a' } } }, 'window_dimensions.info.width', 'number')
    assert_config_error({ window_dimensions = { signature = 'a' } }, 'window_dimensions.signature', 'table')
    assert_config_error(
      { window_dimensions = { signature = { height = 'a' } } },
      'window_dimensions.signature.height',
      'number'
    )
    assert_config_error(
      { window_dimensions = { signature = { width = 'a' } } },
      'window_dimensions.signature.width',
      'number'
    )
    assert_config_error({ lsp_completion = 'a' }, 'lsp_completion', 'table')
    assert_config_error(
      { lsp_completion = { source_func = 'a' } },
      'lsp_completion.source_func',
      '"completefunc" or "omnifunc"'
    )
    assert_config_error({ lsp_completion = { auto_setup = 'a' } }, 'lsp_completion.auto_setup', 'boolean')
    assert_config_error({ lsp_completion = { process_items = 'a' } }, 'lsp_completion.process_items', 'function')
    assert_config_error({ fallback_action = 1 }, 'fallback_action', 'function or string')
    assert_config_error({ mappings = 'a' }, 'mappings', 'table')
    assert_config_error({ mappings = { force_twostep = 1 } }, 'mappings.force_twostep', 'string')
    assert_config_error({ mappings = { force_fallback = 1 } }, 'mappings.force_fallback', 'string')
    assert_config_error({ set_vim_settings = 1 }, 'set_vim_settings', 'boolean')
  end)

  it('properly handles `config.mappings`', function()
    local has_map = function(lhs)
      return child.cmd_capture('imap ' .. lhs):find('MiniCompletion') ~= nil
    end
    assert.True(has_map('<C-Space>'))

    unload_module()
    child.api.nvim_del_keymap('i', '<C-Space>')

    -- Supplying empty string should mean "don't create keymap"
    load_module({ mappings = { force_twostep = '' } })
    assert.False(has_map('<C-Space>'))
  end)

  it('uses `config.lsp_completion`', function()
    local validate = function(auto_setup, source_func)
      reload_module({ lsp_completion = { auto_setup = auto_setup, source_func = source_func } })
      local buf_id = child.api.nvim_create_buf(true, false)
      child.api.nvim_set_current_buf(buf_id)

      local omnifunc, completefunc
      if auto_setup == false then
        omnifunc, completefunc = '', ''
      else
        local val = 'v:lua.MiniCompletion.completefunc_lsp'
        omnifunc = source_func == 'omnifunc' and val or ''
        completefunc = source_func == 'completefunc' and val or ''
      end

      eq(child.api.nvim_buf_get_option(0, 'omnifunc'), omnifunc)
      eq(child.api.nvim_buf_get_option(0, 'completefunc'), completefunc)
    end

    validate(false)
    validate(true, 'omnifunc')
    validate(true, 'completefunc')
  end)

  it('uses `config.set_vim_settings`', function()
    reload_module({ set_vim_settings = true })
    assert.truthy(child.api.nvim_get_option('shortmess'):find('c'))
    eq(child.api.nvim_get_option('completeopt'), 'menuone,noinsert,noselect')
  end)
end)

-- Functional tests ===========================================================
describe('Auto-completion with LSP', function()
  it('respects `config.delay.completion`', function() end)
  it('makes debounce-style delay', function() end)
  it('respects vim.{g,b}.minicompletion_disable', function() end)
end)

describe('Auto-completion without LSP', function() end)

describe('Completion', function()
  it('respects `config.mappings', function() end)
end)

describe('Information window', function()
  it('respects `config.delay.info`', function() end)
  it('respects `config.window_dimensions.info`', function() end)
  it('makes debounce-style delay', function() end)
  it('respects vim.{g,b}.minicompletion_disable', function() end)
end)

describe('Signature help', function()
  it('respects `config.delay.signature`', function() end)
  it('respects `config.window_dimensions.signature`', function() end)
  it('makes debounce-style delay', function() end)
  it('respects vim.{g,b}.minicompletion_disable', function() end)
end)

child.stop()
