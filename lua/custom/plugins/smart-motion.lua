return {
  'FluxxField/smart-motion.nvim',
  enabled = true,
  opts = {
    presets = {
      words = true, -- w, b, e, ge
      lines = true, -- j, k
      search = true, -- s, f, F, t, T, ;, ,, gs
      delete = true, -- d + any motion, dt, dT, rdw, rdl
      yank = true, -- y + any motion, yt, yT, ryw, ryl
      change = true, -- c + any motion, ct, cT
      paste = true, -- p/P + any motion
      treesitter = true, -- ]], [[, ]c, [c, ]b, [b, af, if, ac, ic, aa, ia, fn, saa
      diagnostics = true, -- ]d, [d, ]e, [e
      git = true, -- ]g, [g
      quickfix = true, -- ]q, [q, ]l, [l
      marks = true, -- g', gm
      misc = true, -- . g. g0 g1-g9 gp gP gA-gZ gmd gmy (repeat, history, pins, global pins)
    },
  },
}
