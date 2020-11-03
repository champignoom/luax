An experimental fusion of ConTeXt and Lua
=====

This is an experimental syntax sugar for ConTeXt that potentially helps those who speak lua and try to avoid
re-learning basic programming concepts, such as assignment, linear structure, control flow, etc., disguised under
the exoteric syntaxes and definitions of \*TeX.
It could also avoid certain [pitfalls](https://mailman.ntg.nl/pipermail/ntg-context/2020/097020.html) due to the ad-hoc parser of \*TeX.

Syntax
======

The new syntax fuses TeX and Lua in a similar way that ReactJS fuses HTML and Javascript.
The Lua syntax is enhanced with one more synax: `\{text area}`, roughly meaning `context.delayed("text area")`.
Inside the text area, there are three special syntaxes:
- `\(lua code)`
- `\command(params1)[params2]{text3}(params4)...`, equivalent to `\(command(params1, {params2}, \{text3}, params4, ...))` or `tostring(command)` depending on its type
- `{..}`, creating a lua and TeX scope

The `\command` is now syntax sugar for lua expressions and is not processed by TeX

Only `\`, `{`, `}` has to be escaped when typeset as string. Ideally the concept of catcode should be completely transparent to the user as long as we have a decent functioning grammar.

The exact grammar as well as the transpilation rules are defined with LPeg in `luax.lua`.


Proof of Concept
-----
Save `luax.lua` and `simple_demo.cld` into the same directory, run `context simple_demo.cld`.

The demo is by no means efficient or complete, but should suffice to illustrate the idea.
- setuphead
  - before: `\setuphead[myhead][section][numberstyle=bold, textstyle=bold, before=\hairline\blank, after=\nowhitespace\hairline]`
  - after:  `myhead = section:copy{numberstyle='bold', textstyle='bold', before=\{\hairline\blank}, after=\{\nowhitespace\hairline}}`
- setupxtable
  - before: `\setupxtable[split=yes, header=repeat, offset=4pt]
  - after:  `\xtable.setup[split='yes', header='repeat', offset='4pt']
- startxtable
  - before: (a few dozens lines of code)
  - after:
```lua
\luax.xtable[
  head={
       align='middle', foregroundstyle='bold',
       {{nx=6, "Decline of wealth in Dutch florine (Dfl)"}},
       {foregroundstyle='bold', {width='1.2cm', 'Year'}, '1.000--2.000', '2.000--3.000', '3.000-5.000', '5.000-10.000', 'over 10.000'},
  },
  next={
       {{nx=6, align='middle', foregroundstyle='bold', "Decline of wealth in Dutch florine (Dfl) / Continued"}},
       {foregroundstyle='bold', {'Year', '1.000--2.000', '2.000--3.000', '3.000-5.000', '5.000-10.000', 'over 10.000'}},
  },
  body={
  	align='middle',
       {1675, 22, '~7', '~5', '~4', '~5'},
       {1724, '~4', '~4', '--', '~4', '~3'},
  },
]

\luax.xtable.setup[
  split='yes',
  header='repeat',
  offset='4pt',
]
```

