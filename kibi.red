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
	
	digits: charset "012345789"
	
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
		append out "^[[H"								;-- Go home
log mold lines
		mode: 0
		rows: length? lines
		repeat y screen/y - 2 [
			either y > rows [
				append out "~^[[0K"
			][
				cols: either line: lines/:y [length? line][screen/x]
				repeat x cols [
					;if mode <> new: render/:y/:x [
					;	mode: new
					;	append output 
					;]
					append out either x <= length? line [line/:x][#" "]
				]
			]
			append out "^[[39m^[[0K^M^/"
		]
		
		append out "^[[0K^[[7m"
		append out form reduce ["Cursor:" source "Total lines:" length? lines]
		append out "^[[0m^M^/"
		
		append out "^[[0K"
		append out status
		
		;@@ handle TABS
		append out rejoin ["^[[" cursor/y #";" cursor/x "H^[[?25h"]
		;log to string! out
		emit-buffer out
	]
	
	read-key: function [][
		log mold key: read-byte
		switch/default key [
			3	[none]									;-- Ctrl-C
			4	[none]									;-- Ctrl-D
			6	['find]									;-- Ctrl-F
			8	['delete]								;-- Ctrl-H
			9   ['tab]
			12	['load]									;-- Ctrl-L
			13	['enter]								;-- Enter
			17	['quit]									;-- Ctrl-Q
			19	['save]									;-- Ctrl-S
			21	['undo]									;-- Ctrl-U
			27  [
			log "reading key2 key3:"
			log key2: read-byte
				if negative? key2 [return key]
			log key3: read-byte
				if negative? key3 [return key]
				
				either key2 = #"[" [
					either find digits key3 [
						if negative? key: read-byte [return escape]
						if key = #"~" [
							return select [
								#"3" delete
								#"5" page-up
								#"6" page-down
							] key3
						]
					][
						return select [
							#"A" up
							#"B" down
							#"C" right
							#"D" left
							#"H" home
							#"F" end
						] key3
					]
				][
					if key2 = #"O" [select [#"H" home #"F" end] key3]
				]
			]
			127 ['backspace]
			
		][make char! key]
	]
	
	insert-char: function [c [char!]][
		if cursor/y > length? lines [append lines make string! 100]
		
		either cursor/x >= length? line: lines/(cursor/y) [
			append line c
		][
			insert next at line cursor/x c
		]
		cursor/x: cursor/x + 1
		
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
log mold c
				switch c [
					enter	[
						cursor/x: 1
						cursor/y: cursor/y + 1
						insert at lines cursor/y make string! 100
					]
					quit	[exit]
					load	[]
					save	[]
					find	[]
					back	[]
					delete	[]
					tab		[]
					left	[
						if (cursor/x: max 1 cursor/x - 1) < scroll/x [
							scroll/x: cursor/1/x
						]
					]
					right	[
						if all [
							cursor/x <= length? lines/(cursor/y)
							(cursor/x: cursor/x + 1) > (scroll/x + screen/x)
						][
							scroll/x: scroll/x + 1
						] 
					]
					up		[
						if (cursor/y: max 1 cursor/y - 1) < scroll/y [
							scroll/y: source/y
						]
						cursor/x: min cursor/x length? lines/(cursor/y)
					]
					down	[
						if all [
							cursor/y < length? lines
							(cursor/y: cursor/y + 1) > (scroll/y + screen/y)
						][
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
