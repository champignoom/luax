An experimental fusion of ConTeXt and Lua
=====

This is an experimental syntax sugar for ConTeXt built upon the Lua interface of ConText. It aims at further facilitates those who speak lua to avoid
re-learning basic programming concepts, such as assignment, linear structure, control flow, etc., disguised under
the exotic syntaxes and definitions of \*TeX.
It could also avoid certain [pitfalls](https://mailman.ntg.nl/pipermail/ntg-context/2020/097020.html) due to the ad-hoc parsers of \*TeX.

Nevertheless, the syntax convensions of ConTeXt are preserved as much as possible.

Syntax
======

The syntax sugar fuses TeX and Lua in a similar way that [JSX](https://reactjs.org/docs/introducing-jsx.html) fuses HTML and Javascript.
The Lua syntax is enhanced with one more synax: `\{text area}`, roughly meaning `context.delayed("text area")`.
Inside the text area, there are three special syntaxes:
- `\(lua code)`
- `\command(params1)[params2]{text3}(params4)...`, equivalent to `\(command(params1, {params2}, \{text3}, params4, ...))` or `tostring(command)` depending on its type
- `{..}`, creating a lua and TeX scope

The `\command` is now syntax sugar for lua expressions and is not processed by TeX

Only `\`, `{`, `}` has to be escaped when typeset as string. Ideally the concept of catcode should be completely transparent to the user as long as we have a decent functioning grammar.

The exact grammar defined with LPeg as well as the desugaring rules are in `luax.lua`.


Proof of Concept
-----
Save `luax.lua` and `simple_demo.cld` into the same directory, run `context simple_demo.cld`.

The demo is by no means efficient or complete, but should suffice to illustrate the idea.
- setuphead
  - before: `\setuphead[myhead][section][numberstyle=bold, textstyle=bold, before=\hairline\blank, after=\nowhitespace\hairline]`
  - after:  `myhead = section:copy{numberstyle='bold', textstyle='bold', before=[[\hairline\blank]], after=[[\nowhitespace\hairline]]}`
- setupxtable
  - before: `\setupxtable[split=yes, header=repeat, offset=4pt]`
  - after:  `\xtable.setup[split='yes', header='repeat', offset='4pt']`
- startxtable
  - before: (see [ConTeXt an excursion](http://www.pragma-ade.com/general/manuals/ma-cb-en.pdf), section 13.3: Extreme tables)

    ```tex
    \setupxtable[split=yes,header=repeat,offset=4pt]
    \startxtable
     \startxtablehead[align=middle,foregroundstyle=bold]
      \startxrow
       \startxcell[nx=6]  Decline of wealth in Dutch florine (Dfl)  \stopxcell
      \stopxrow
      \startxrow[foregroundstyle=bold]
       \startxcell[width=1.2cm] Year \stopxcell
       \startxcell 1.000--2.000  \stopxcell
       \startxcell 2.000--3.000  \stopxcell
       \startxcell 3.000--5.000  \stopxcell
       \startxcell 5.000--10.000 \stopxcell
       \startxcell   over 10.000 \stopxcell
    
       % .... 50+ more lines
    ```

  - after:

    ```lua
    { \(local header = {'1.000--2.000', '2.000--3.000', '3.000-5.000', '5.000-10.000', 'over 10.000'})
      \xtable[split='yes', header='repeat', offset='4pt'][
        head={
             align='middle', foregroundstyle='bold',
             {{nx=6, "Decline of wealth in Dutch florine (Dfl)"}},
             {foregroundstyle='bold', {width='1.2cm', 'Year'}, table.unpack(legend)},
        },
        next={
             {{nx=6, align='middle', foregroundstyle='bold', "Decline of wealth in Dutch florine (Dfl) / Continued"}},
             {foregroundstyle='bold', {'Year', table.unpack(legend)}},
        },
        body={
             align='middle',
             {1675, \{\luax.math{22}}, '~7', '~5', '~4', '~5'},
             {1724, '~4', '~4', '--', '~4', '~3'},
        },
      ]
    }
    ```

