--[[
context = {
	["starttext"] = function()end,
	["stoptext"] = function()end,
}
--]]

local lpeg = require("lpeg")
local C = lpeg.C
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local V = lpeg.V
local Cb = lpeg.Cb
local Cc = lpeg.Cc
local Cg = lpeg.Cg
local Ct = lpeg.Ct
local Cp = lpeg.Cp
local Cmt = lpeg.Cmt

local module = {}

local allowed_nonalpha_cmd = "{}\\"
local nonalpha_cmd_name = {
	["{"] = "curly_bracket_left",
	["}"] = "curly_bracket_right",
	["\\"] = "backslash",
}

module.grammar = P{
	V"AbstractLua" * Cp(),
	AbstractLua = Ct(V"AbstractLuaElement"^0),
	AbstractLuaElement = Ct(
		  Cc"string"         * V"LuaString"
		+ Cc"comment"        * V"LuaComment"
		+ Cc"round_bracket"  * C("(") * V"AbstractLua" * C(")")
		+ Cc"square_bracket" * C("[") * V"AbstractLua" * C("]")
		+ Cc"curly_bracket"  * C("{") * V"AbstractLua" * C("}")
		+ Cc"textseq"        * "\\{" * V"TextSeq" * "}"
		+ Cc"other"          * (C((1-S[[()[]{}'"\-]])^1) + C('-'))
	),

	LuaString = C(
		  --[["single_quote" *]] P"'" * (V"NonNewline" - "'" + (P"\\" * 1))^0 * "'"
		+ --[["double_quote" *]] P'"' * (V"NonNewline" - '"' + (P'\\' * 1))^0 * '"'
		+ --[["long"         *]] V"LuaLongString"
	),
	NonNewline = (1 - S"\r\n\f"),

	-- http://www.inf.puc-rio.br/~roberto/lpeg/
	-- section "Lua's long strings"
	LuaLongStringEquals = P"="^0,
	LuaLongStringOpen = "[" * Cg(V"LuaLongStringEquals", "init") * "[",
	LuaLongStringClose = "]" * C(V"LuaLongStringEquals") * "]",
	LuaLongStringCloseEqTest = Cmt(V"LuaLongStringClose" * Cb("init"), function (s, i, a, b) return a == b end),
	LuaLongString = (V"LuaLongStringOpen" * C((P(1) - V"LuaLongStringCloseEqTest")^0) * V"LuaLongStringClose" / 1),

	LuaComment = C("--" * (
		  --[[Cc"long"  *]] V"LuaLongString"
		+ --[[Cc"short" *]] V"NonNewline"^0
	)),

	TextSeq = Ct(V"TextSeqElement"^0),
	TextSeqElement = Ct(
		  Cc"puretext"     * C((1-S"{}\\")^1)
		+ Cc"group"        * "{" * V"TextSeq" * "}"
		+ Cc"comment"      * "\\%" * C(V"NonNewline"^0) * P"\n"^-1
		+ Cc"nonalpha_cmd" * "\\" * C(S(allowed_nonalpha_cmd))
		+ Cc"cmd"          * V"TextCmd"
		+ Cc"lua"          * "\\(" * V"AbstractLua" * ")"
	),
	TextCmd = Ct("\\" * Cg(V"TextCmdName", "name") * Cg(Ct(V"TextCmdParam"^0), "params") * P"|"^-1),
	TextCmdName = C(V"Identifier" * ("." * V"Identifier")^0),
	TextCmdParam = Ct(
		  Cc"round_bracket"  * "(" * V"AbstractLua" * ")"
		+ Cc"square_bracket" * "[" * V"AbstractLua" * "]"
		+ Cc"curly_bracket"  * "{" * V"TextSeq" * "}"
	),

	Identifier = V"AlphaUnderscore" * (V"AlphaUnderscore" + R"09")^0,
	AlphaUnderscore = R("AZ", "az") + P('_'),
}

local function print_keys(x)
	if type(x)~='table' then return end
	for k,_ in pairs(x) do print('$', k) end
	print('--')
end

local function print_ast(captures)
	local function impossible(rule, label)
		error(("%s: impossible capture label: %s"):format(rule, label))
	end

	local f_abstract_lua
	local f_textseq

	function f_abstract_lua(captures, indent)
		for _,v in ipairs(captures) do
			if v[1]=="comment" or v[1]=="string" or v[1]=="other" then
				print(("%s%s(%d)"):format(indent, v[1], #v[2]))
			elseif v[1]:sub(-7) == "bracket" then
				print(indent .. v[1])
				f_abstract_lua(v[3], indent.."  ")
			elseif v[1] == "textseq" then
				print(("%s%s[%s]"):format(indent, v[1], #v[2]))
				f_text_seq(v[2], indent.."  ")
			else
				impossible("AbstractLua", v[1])
			end
		end
	end

	function f_text_seq(captures, indent)
		for _,v in ipairs(captures) do
			if v[1]=="puretext" then
				print(("%s%s(%d)"):format(indent, v[1], #v[2]))
			elseif v[1]=="group" then
				print(indent .. v[1])
				f_text_seq(v[2], indent.."  ")
			elseif v[1]=="comment" then
				print(("%s%s(%d)"):format(indent, v[1], #v[2]))
			elseif v[1]=="nonalpha_cmd" then
				print(("%s%s: \\%s"):format(indent, v[1], v[2]))
			elseif v[1]=="cmd" then
				print(("%s%s: %s"):format(indent, v[1], v[2].name))
				for j,w in ipairs(v[2].params) do
					print((" %sparam %d: %s"):format(indent, j, w[1]))
					if w[1]=="round_bracket" or w[1]=="square_bracket" then
						f_abstract_lua(w[2], indent.."  ")
					elseif w[1]=="curly_bracket" then
						f_text_seq(w[2], indent.."  ")
					else
						impossible("TextCmdParam", w[1])
					end
				end
			elseif v[1]=="lua" then
				print(("%s%s[%d]"):format(indent, v[1], #v[2]))
				f_abstract_lua(v[2], indent.."  ")
			else
				impossible("TextSeq", v[1])
			end
		end
	end

	f_abstract_lua(captures, '')
end

local function parse(s)
	local captures, pos = module.grammar:match(s)
	if pos==#s+1 then
		return captures
	else
		print('>>>>> luax parser failed at char ' .. pos)
		os.exit(1)
	end
end

local function transpile(captures)
	local f_abstract_lua
	local f_text_seq

	local function f_enter_text_seq(captures, buf)
		buf[#buf+1] = "(function()"
		f_text_seq(captures, buf)
		buf[#buf+1] = " end)"
	end

	function f_abstract_lua(captures, buf)
		for _,v in ipairs(captures) do
			if v[1]=="comment" or v[1]=="string" or v[1]=="other" then
				buf[#buf+1] = v[2]
			elseif v[1]:sub(-7) == "bracket" then
				buf[#buf+1] = v[2]
				f_abstract_lua(v[3], buf)
				buf[#buf+1] = v[4]
			elseif v[1] == "textseq" then
				f_enter_text_seq(v[2], buf)
			else
				impossible("AbstractLua", v[1])
			end
		end
	end

	local function get_max_consecutive_eq(s)
		local result = 0
		for w in s:gmatch("=+") do
			if w:len() > result then result = w:len() end
		end
		return result
	end

	function f_text_seq(captures, buf)
		for _,v in ipairs(captures) do
			if v[1]=="puretext" then
				local eqs = ('='):rep(get_max_consecutive_eq(v[2])+1)
				buf[#buf+1] = ('luax._feed_pure_text[%s['):format(eqs)
				buf[#buf+1] = v[2]
				buf[#buf+1] = (']%s]; '):format(eqs)
			elseif v[1]=="group" then
				buf[#buf+1] = "do luax.start_text_group()\n"
				f_text_seq(v[2], buf)
				buf[#buf+1] = "luax.stop_text_group() end\n"
			elseif v[1]=="comment" then
				-- do nothing
			elseif v[1]=="nonalpha_cmd" then
				buf[#buf+1] = ('luax.nonalpha_cmd.%s()\n'):format(nonalpha_cmd_name[v[2]])
			elseif v[1]=="cmd" then
				buf[#buf+1] = "luax._call_cmd("
				buf[#buf+1] = v[2].name
				for j,w in ipairs(v[2].params) do
					buf[#buf+1] = ", "
					if w[1]=="round_bracket" then
						f_abstract_lua(w[2], buf)
					elseif w[1]=="square_bracket" then
						buf[#buf+1] = "{"
						f_abstract_lua(w[2], buf)
						buf[#buf+1] = "}"
					elseif w[1]=="curly_bracket" then
						f_enter_text_seq(w[2], buf)
					else
						impossible("TextCmdParam", w[1])
					end
				end
				buf[#buf+1] = ")\n"
			elseif v[1]=="lua" then
				f_abstract_lua(v[2], buf)
				buf[#buf+1] = "\n"
			else
				impossible("TextSeq", v[1])
			end
		end
	end

	local buf = {}
	f_abstract_lua(captures, buf)
	return table.concat(buf)
end

function module.run_luax()
	local this_path = debug.getinfo(2).source:match("@(.*)")
	print('this_path', this_path)

	local f = io.open(this_path)
	local mark
	local done
	local luax_lines = {}
	while true do
		local l = f:read("*line")
		if l==nil then break end

		if done then
			print('garbage after marker comment: ' .. l)
			os.exit(1)
		end

		if mark == nil then
			if l:sub(1,3)=="--[" and l:sub(-5)=="[luax" then
				mark = l:sub(4, -6)
			end
		else
			if l:sub(-2-#mark) == "]"..mark.."]" then
				done = true
			else
				luax_lines[#luax_lines+1] = l
			end
		end
	end

	if not done then
		print('luax code not found')
		os.exit(1)
	end

	local luax_source = table.concat(luax_lines, '\n')
	local luax_ast = parse(luax_source)
	print('>>>>>>>>>>>>>> AST >>>>>>>>>>>>>>>')
	print_ast(luax_ast)
	print('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<')

	local transpiled = transpile(luax_ast)
	print('>>>>>>>>>>>>>> transpiled >>>>>>>>>>>>>>>>>')
	print(transpiled)
	print('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<')
	local compiled = load(transpiled)
	if not compiled then
		print(('failed to compile %s'):format(this_path))
		os.exit(1)
	end

	compiled()
end

function module.start_text_group()
	context("{")
end

function module.stop_text_group()
	 context("}")
end

function module.text(f)
	-- TODO: catcode
	-- ./tex/texmf-context/tex/context/base/mkiv/catc-ctx.mkiv
	context.starttext()
	f()
	context.stoptext()
end

function module._feed_pure_text(s)
	assert(type(s)=='string');
	-- FIXME: catcode
	-- extra parenthesis for passing only one argument
	context((s:gsub("[%%$|]","\\%1")))
end

local function shift_args(n, ...)
	local m = select("#", ...)
	if n>m then
		return nil, shift_args(n-1, ...)
	elseif n==m then
		return ...
	else
		error("too much arguments")
	end
end

module.xtable = {
	setup = context.setupxtable,
}
setmetatable(module.xtable, {
	__call = function(f, ...)
		local args, table = shift_args(2, ...)
		args = args or {}

		local function do_tag(tag_name, tag_args, content_callback)
			local configs = {}
			for k,v in pairs(tag_args) do
				if type(k)~='number' then
					configs[k] = v
				end
			end

			local content = {}
			for i,v in ipairs(tag_args) do
				content[#content+1] = v
			end

			--if tag_name=='xcell' then print(configs.nx) end

			context['start'..tag_name](configs)
			for i, v in ipairs(content) do
				content_callback(v)
			end
			context['stop'..tag_name]()
		end

		local function do_section(section_name)
			do_tag('xtable'..section_name, table[section_name], function(row_args)
				do_tag('xrow', row_args, function(cell_args)
					if type(cell_args)~='table' then
						context.startxcell()
						module._call_cmd(cell_args)
						context.stopxcell()
					else
						do_tag('xcell', cell_args, function(x) module._call_cmd(x) end)
					end
				end)
			end)
		end

		context.startxtable(args)
		do_section('head')
		do_section('next')
		do_section('body')
		context.stopxtable()
	end
})

function module._call_cmd(f, ...)
	if type(f)=='number' then
		if select("#", ...) ~= 0 then
			error("no arguments allowed for number")
		end
		module._feed_pure_text(tostring(f))
	elseif type(f)=='string' then
		if select("#", ...) ~= 0 then
			error("no arguments allowed for string")
		end
		module._feed_pure_text(f)
	elseif type(f)=='function' or (getmetatable(f)~=nil and getmetatable(f).__call~=nil) then
		f(...)
	elseif getmetatable(f)~=nil and getmetatable(f).__tostring~=nil then
		if select("#", ...) ~= 0 then
			error("no arguments allowed for custom type")
		end
		module._feed_pure_text(tostring(f))
	else
		print_keys(f)
		error(("cannot format %s of type %s"):format(f, type(f)))
	end
end

module.nonalpha_cmd = {
	curly_bracket_left = function() context("\\{") end,
	curly_bracket_right = function() context("\\}") end,
	backslash = function() context("\\textbackslash") end,
}

function module.math(math_body)
	context.startimath()
	module._call_cmd(math_body)
	context.stopimath()
end

local function new_section_name()
	local section_name_cnt=0
	section_name_cnt = section_name_cnt + 1
	return tostring(section_name_cnt):gsub(".", function(c) return string.char(string.byte(c) - string.byte('0') + string.byte('a')) end)
end

local section_metatable
section_metatable = {
	__call = function(section, ...)
		context[section.name](...)
	end,

	__index = {
		copy = function(self, new_setup)
			new_setup = new_setup or {}

			local new_section = {name = 'section' .. new_section_name()}
			context.definehead({new_section.name}, {self.name})
			context.setuphead({new_section.name}, new_setup)

			setmetatable(new_section, section_metatable)
			return new_section
		end,
	},
}

module.section = {name='section'}
setmetatable(module.section, section_metatable)

function module.hairline() context("\\hairline") end
function module.blank() context("\\blank") end
function module.nowhitespace() context("\\nowhitespace") end

context.setuphead({'section'}, {expansion='yes'})     -- context[=[\setuphead[chapter][expansion=yes]]=]

return module
