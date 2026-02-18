return {
  'FluxxField/smart-motion.nvim',
  enabled = true,
  opts = {
    presets = {
      words = {
        w = { exclude_keys = 'w' },
        b = { exclude_keys = 'b' },
        e = { exclude_keys = 'e' },
        ge = { exclude_keys = 'g' },
      }, -- w, b, e, ge
      lines = {
        j = { exclude_keys = 'j' },
        k = { exclude_keys = 'k' },
      }, -- j, k
      search = true, -- s, f, F, t, T, ;, ,, gs
      delete = true, -- d + any motion, dt, dT, rdw, rdl
      yank = true, -- y + any motion, yt, yT, ryw, ryl
      change = true, -- c + any motion, ct, cT
      paste = true, -- p/P + any motion
      treesitter = {
        [']]'] = { exclude_keys = ']' },
        ['[['] = { exclude_keys = '[' },
        [']c'] = { exclude_keys = 'c' },
        ['[c'] = { exclude_keys = 'c' },
        [']b'] = { exclude_keys = 'b' },
        ['[b'] = { exclude_keys = 'b' },
        ['af'] = { exclude_keys = 'f' },
        ['if'] = { exclude_keys = 'f' },
        ['ac'] = { exclude_keys = 'c' },
        ['ic'] = { exclude_keys = 'c' },
        ['aa'] = { exclude_keys = 'a' },
        ['ia'] = { exclude_keys = 'a' },
        ['fn'] = { exclude_keys = 'n' },
        ['saa'] = { exclude_keys = 'a' },
      }, -- ]], [[, ]c, [c, ]b, [b, af, if, ac, ic, aa, ia, fn, saa
      diagnostics = {
        [']d'] = { exclude_keys = 'd' },
        ['[d'] = { exclude_keys = 'd' },
        [']e'] = { exclude_keys = 'e' },
        ['[e'] = { exclude_keys = 'e' },
      }, -- ]d, [d, ]e, [e
      git = {
        [']g'] = { exclude_keys = 'g' },
        ['[g'] = { exclude_keys = 'g' },
      }, -- ]g, [g
      quickfix = {
        [']q'] = { exclude_keys = 'q' },
        ['[q'] = { exclude_keys = 'q' },
        [']l'] = { exclude_keys = 'l' },
        ['[l'] = { exclude_keys = 'l' },
      }, -- ]q, [q, ]l, [l
      marks = true, -- g', gm
      misc = true, -- . g. g0 g1-g9 gp gP gA-gZ gmd gmy (repeat, history, pins, global pins)
    },
  },
}
