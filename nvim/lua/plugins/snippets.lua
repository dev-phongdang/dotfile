return {
  'L3MON4D3/LuaSnip',
  config = function()
    local ls = require('luasnip')
    local s, t, i = ls.snippet, ls.text_node, ls.insert_node

    -- A Go test scaffold: type `tst` then expand
    ls.add_snippets('go', {
      s('tst', {
        t({ 'func Test', '' }), i(1, 'Name'),
        t({ '(t *testing.T) {', '\tt.Parallel()', '\t' }), i(2, '// arrange'),
        t({ '', '}' }),
      }),
    })

    -- A Python pytest scaffold: type `tst` then expand
    ls.add_snippets('python', {
      s('tst', {
        t({ 'def test_' }), i(1, 'name'),
        t({ '() -> None:', '    ' }), i(2, '...'),
      }),
    })
  end,
}
