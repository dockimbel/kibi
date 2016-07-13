Red [
	Title:   "Kibi"
	Author:  "Nenad Rakocevic, Xie Qingtian"
	File: 	 %kibi.r
	Tabs:	 4
	Rights:  "Copyright (C) 2016 Nenad Rakocevic, Xie Qingtian. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

#include %cli.red

kibi: context [
	lines:	make block! 1000
	render:	make block! 1000

	source: 1x1											;-- position in text (col, row)
	cursor: 1x1											;-- relative to screen (col, row)
	scroll: 1x1
	screen: 0x0											;-- row x columns
	output: make binary! 200 * 150
	status: ""											;-- status message
	
	colors: object [
		comment: 
		comment-multi: 36								;-- cyan
		keyword1:	   33								;-- yellow
		keyword2:	   32								;-- green
		string:		   35								;-- magenta
		number:		   31								;-- red
		match:		   34								;-- blue
		default:	   37								;-- white
	]
	
	syntax-data: [
		keywords: [
			[
				"switch" "if" "while" "for" "break" "continue" "return" "else"
				"struct" "union" "typedef" "static" "enum" "class"
			][
				"int" "long" "double" "float" "char" "unsigned" "signed" "void"
			]
		]
		comment: 		"//"
		comment-multi:	["/*" "*/"]
		string:			#"^""
		string-multi:	#[none]
	]
	
	refresh: function [][
		clear out: output
		
		append out "^[[?25l"							;-- Hide cursor
		append out "^[[H^[[39m"							;-- Go home
log mold lines		
		mode: 0
		repeat y screen/y - 2 [
			either y > length? lines [
				append out "~^[[0K^M^/"
			][
				max-x: either line: lines/y [length? line][screen/x]
				repeat x max-x [				
					;if mode <> new: render/:y/:x [
					;	mode: new
					;	append output 
					;]
					log ["char:" line/:x]
					append out line/:x
				]
				append out CRLF
			]
		]
		append out "^[[39m^[[0K^M^/"
		
		;append out "^[[0K^[[7m"
		;append out form reduce ["Current:" source "Total lines:" length? lines]
		;append out "^[0m^M^/"
		
		;append out "^[[0K"
		;append out status
		
		;@@ handle TABS
		;append out rejoin [#"^[" cursor/x #";" cursor/y "H^[?25h"]
		log to string! out
		emit-buffer out
	]
	
	read-key: function [][
		log mold key: read-char	
		switch/default key [
			3	[none]									;-- Ctrl-C
			4	[none]									;-- Ctrl-D
			6	['find]									;-- Ctrl-F
			8	['delete]								;-- Ctrl-H
			9   ['tab]
			12	['load]									;-- Ctrl-L
			17	['quit]									;-- Ctrl-Q
			19	['save]									;-- Ctrl-S
			21	['undo]									;-- Ctrl-U
			127 ['backspace]
			
		][make char! key]
	]
	
	insert-char: function [c [char!]][
		if cursor/y > length? lines [append lines make string! 100]
		
		either cursor/x >= length? line: lines/(cursor/y) [
			append line c
		][
			insert at line cursor/x c
		]
		
		if (source/x: source/x + 1) > (scroll/x + screen/x) [
			scroll/x: scroll/x + 1
		]
	]
	
	load-file: function [args [string!]][
		
	]
	
	launch: function [][
		append lines make string! 100
		append render make vector! [integer! 8 100]
		
		forever [
			either char? c: read-key [insert-char c][
				switch c [
					enter	[]
					quit	[exit]
					load	[]
					save	[]
					find	[]
					back	[]
					delete	[]
					tab		[]
					left	[
						if (source/x: max 1 source/x - 1) < scroll/x [
							scroll/x: cursor/1/x
						]
					]
					right	[
						if (source/x: source/x + 1) > (scroll/x + screen/x) [
							scroll/x: scroll/x + 1
						] 
					]
					up		[
						if (source/y: max 1 source/y - 1) < scroll/y [
							scroll/y: source/y
						]
					]
					down	[
						if (source/y: source/y + 1) > (scroll/y + screen/y) [
							scroll/y: scroll/y + 1
						] 
					]
					page-up []
					page-down []
					clear	[]
				]
			]
			refresh
		]
	]
	
	log: func [msg][write/append %kibi.log form reduce [reduce msg lf]]
	
	boot: function [/extern screen status][
		if args: system/options/args [load-file args]
		
		screen: get-window-size
		log ["screen: " screen]
		
		open-terminal

		status: "HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find"
		launch
		close-terminal

	]
	
	boot
]
