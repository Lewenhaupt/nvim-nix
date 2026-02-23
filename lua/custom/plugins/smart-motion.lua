return {
  'FluxxField/smart-motion.nvim',
  enabled = true,
  opts = {
    presets = {
      words = false, -- w, b, e, ge
      lines = false, -- j, k
      search = false, -- s, f, F, t, T, ;, ,, gs
      delete = true, -- d + any motion, dt, dT, rdw, rdl
      yank = true, -- y + any motion, yt, yT, ryw, ryl
      change = true, -- c + any motion, ct, cT
      paste = false, -- p/P + any motion
      treesitter = false, -- ]], [[, ]c, [c, ]b, [b, af, if, ac, ic, aa, ia, fn, saa
      diagnostics = false, -- ]d, [d, ]e, [e
      git = false, -- ]g, [g
      quickfix = false, -- ]q, [q, ]l, [l
      marks = false, -- g', gm
      misc = false, -- . g. g0 g1-g9 gp gP gA-gZ gmd gmy (repeat, history, pins, global pins)
    },
  },
}
