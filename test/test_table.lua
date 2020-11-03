luax = require('luax')
luax.run_luax()
--[[luax

luax.xtable.setup{
  split='yes',
  header='repeat',
  offset='4pt',
}

luax.text\{
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
}

]]
