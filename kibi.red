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

	cursor: [1x1 1x1]
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
    	append out "^[[H"								;-- Go home
		
		mode: 0
		repeat y screen/y - 2 [
			repeat x screen/x [
				either y > length? lines [
					append output "~^[[0K^M^/"
				][
					;if mode <> new: render/y/x [
					;	mode: new
					;	append output 
					;]
					append output lines/y/x
				]
			]
		]
		append out "^[[39m^[[0K^M^/"
		
		append out "^[[0K^[[7m"
		append out form ["Current:" cursor/1 "Total lines:" length? lines]
		append out "^[0m^M^/"
		
		append out "^[[0K"
		append out status
		
		;@@ handle TABS
		append out rejoin [#"^[" cursor/2/x #";" cursor/2/y "H^[?25h"]
		; write out
	]
	
	read-key: function [][
		switch/default key: read-char [
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
		insert at lines/(cursor/y) cursor/x c
		
		if (cursor/1/x: cursor/1/x + 1) > (scroll/x + screen/x) [
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
						if (cursor/1/x: max 1 cursor/1/x - 1) < scroll/x [
							scroll/x: cursor/1/x
						]
					]
					right	[
						if (cursor/1/x: cursor/1/x + 1) > (scroll/x + screen/x) [
							scroll/x: scroll/x + 1
						] 
					]
					up		[
						if (cursor/1/y: max 1 cursor/1/y - 1) < scroll/y [
							scroll/y: cursor/1/y
						]
					]
					down	[
						if (cursor/1/y: cursor/1/y + 1) > (scroll/y + screen/y) [
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
	
	boot: function [][
		if args: system/options/args [load-file args]
		
		open-terminal
		get-window-size screen
		log ["screen: " screen]

		status: "HELP: Ctrl-S = save | Ctrl-Q = quit | Ctrl-F = find"
		launch
		close-terminal

	]
	
	boot
]
