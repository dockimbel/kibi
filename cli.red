Red []

#system [
	kibi: context [
		#case [
			any [OS = 'MacOSX OS = 'FreeBSD] [
				#define TIOCGWINSZ		40087468h
				#define TERM_TCSADRAIN	1
				#define TERM_VTIME		18
				#define TERM_VMIN		17

				#define TERM_BRKINT		02h
				#define TERM_INPCK		10h
				#define TERM_ISTRIP		20h
				#define TERM_ICRNL		0100h
				#define TERM_IXON		0200h
				#define TERM_OPOST		01h
				#define TERM_CS8		0300h
				#define TERM_ISIG		80h
				#define TERM_ICANON		0100h
				#define TERM_ECHO		08h	
				#define TERM_IEXTEN		4000h

				termios!: alias struct! [
					c_iflag			[integer!]
					c_oflag			[integer!]
					c_cflag			[integer!]
					c_lflag			[integer!]
					c_cc1			[integer!]						;-- c_cc[20]
					c_cc2			[integer!]
					c_cc3			[integer!]
					c_cc4			[integer!]
					c_cc5			[integer!]
					c_ispeed		[integer!]
					c_ospeed		[integer!]
				]
			]
			true [													;-- Linux
				#define TIOCGWINSZ		5413h
				#define TERM_VTIME		6
				#define TERM_VMIN		7

				#define TERM_BRKINT		2
				#define TERM_INPCK		20
				#define TERM_ISTRIP		40
				#define TERM_ICRNL		400
				#define TERM_IXON		2000
				#define TERM_OPOST		1
				#define TERM_CS8		60
				#define TERM_ISIG		1
				#define TERM_ICANON		2
				#define TERM_ECHO		10
				#define TERM_IEXTEN		100000

				#either OS = 'Android [
					#define TERM_TCSADRAIN	5403h

					termios!: alias struct! [
						c_iflag			[integer!]
						c_oflag			[integer!]
						c_cflag			[integer!]
						c_lflag			[integer!]
						;c_line			[byte!]
						c_cc1			[integer!]					;-- c_cc[19]
						c_cc2			[integer!]
						c_cc3			[integer!]
						c_cc4			[integer!]
						c_cc5			[integer!]
					]
				][
					#define TERM_TCSADRAIN	1

					termios!: alias struct! [						;-- sizeof(termios) = 60
						c_iflag			[integer!]
						c_oflag			[integer!]
						c_cflag			[integer!]
						c_lflag			[integer!]
						c_line			[byte!]
						c_cc1			[byte!]						;-- c_cc[32]
						c_cc2			[byte!]
						c_cc3			[byte!]
						c_cc4			[integer!]
						c_cc5			[integer!]
						c_cc6			[integer!]
						c_cc7			[integer!]
						c_cc8			[integer!]
						c_cc9			[integer!]
						c_cc10			[integer!]
						pad				[integer!]					;-- for proper alignment
						c_ispeed		[integer!]
						c_ospeed		[integer!]
					]
				]
			]
		]

		winsize!: alias struct! [
			rowcol			[integer!]
			xypixel			[integer!]
		]

		#either OS = 'Android [
			tcgetattr: func [
				fd		[integer!]
				termios [termios!]
				return: [integer!]
			][
				ioctl fd 5401h as winsize! termios
			]
			tcsetattr: func [
				fd			[integer!]
				opt_actions [integer!]
				termios 	[termios!]
				return: 	[integer!]
			][
				ioctl fd opt_actions as winsize! termios
			]
		][
			#import [
			LIBC-file cdecl [
				tcgetattr: "tcgetattr" [
					fd		[integer!]
					termios [termios!]
					return: [integer!]
				]
				tcsetattr: "tcsetattr" [
					fd			[integer!]
					opt_actions [integer!]
					termios 	[termios!]
					return: 	[integer!]
				]
			]]
		]

		#import [
			LIBC-file cdecl [
				read: "read" [
					fd		[integer!]
					buf		[byte-ptr!]
					size	[integer!]
					return: [integer!]
				]
				ioctl: "ioctl" [
					fd		[integer!]
					request	[integer!]
					ws		[winsize!]
					return: [integer!]
				]
			]
		]


		;-- API begin

		saved-term: declare termios!

		read-char: func [
			return: [integer!]								;-- codepoint or -1
			/local
				c	[integer!]
				len [integer!]
				i	[integer!]
				s	[byte-ptr!]
		][
			s: as byte-ptr! "0000000000"
			if 1 <> read stdin s 1 [return -1]
			c: as-integer s/1
			case [
				c and 80h = 0	[return c]
				c and E0h = C0h [len: 2]
				c and F0h = E0h [len: 3]
				c and F8h = F0h [len: 4]
				true			[len: -1]
			]
			if any [len < 1 len > 4][return -1]

			i: 1
			while [i < len][
				if all [
					len >= (i + 1)
					1 <> read stdin s + i 1
				][
					return -1
				]
				i: i + 1
			]
			unicode/decode-utf8-char as c-string! s :len
		]

		query-cursor: func [
			p		[red-pair!]
			return: [logic!]								;-- FALSE: failed to retrieve it
			/local
				c [byte!]
				n [integer!]
		][
			write stdout "^[[6n" 4							;-- ask for cursor location
			if all [
				  esc = as byte! read-char
				 #"[" = as byte! read-char
			][
				while [true][
					c: as byte! read-char
					n: 0
					case [
						c = #";" [p/y: n n: 0]
						all [c = #"R" n <> 0 n < 1000][
							p/x: n
							return true
						]
						all [#"0" <= c c <= #"9"][
							n: n * 10 + (c - #"0")
						]
						true [
							return true
						]
					]
				]
			]
			false
		]

		get-window-size: func [
			win				[red-pair!]
			return:			[logic!]
			/local
				ws			[winsize!]
				saved_cols	[integer!]
				saved_rows	[integer!]
				ret			[integer!]
				s			[c-string!]
		][
			s: "000000000000000000000000000000"
			ws: declare winsize!

			ret: ioctl stdout TIOCGWINSZ ws
			win/y: ws/rowcol and FFFFh
			win/x: ws/rowcol >>> 16

			if any [ret = -1 zero? win/x] [
				win/x: 0
				win/y: 0
				if query-cursor win [			;-- get initial position
					write stdout "^[[999C^[[999B" 12
					if query-cursor win [					;-- move the right/bottom, get size
						sprintf s "^[[%d;%dH" win/y win/x	;-- restore position
						write stdout s length? s
						return true
					]
				]
				return false
			]
			true
		]

		init: func [
			/local
				term [termios!]
				cc	 [byte-ptr!]
				;so	 [sigaction!]
				mask [integer!]
		][
			;so: declare sigaction!						;-- install resizing signal trap
			;mask: (as-integer so) + 4
			;sigemptyset mask
			;so/sigaction: as-integer :on-resize		;@@
			;so/flags: 0
			;sigaction SIGWINCH so as sigaction! 0

			term: declare termios!
			tcgetattr stdin saved-term					;@@ check returned value

			copy-memory as byte-ptr! term as byte-ptr! saved-term size? term

			term/c_iflag: term/c_iflag and not (TERM_BRKINT or TERM_ICRNL or TERM_INPCK or TERM_ISTRIP or TERM_IXON)
			term/c_oflag: term/c_oflag and not TERM_OPOST
			term/c_cflag: term/c_cflag or TERM_CS8
			term/c_lflag: term/c_lflag and not (TERM_ECHO or TERM_ICANON or TERM_IEXTEN or TERM_ISIG)
			#case [
				any [OS = 'MacOSX OS = 'FreeBSD] [cc: (as byte-ptr! term) + (4 * size? integer!)]
				true [cc: (as byte-ptr! term) + (4 * size? integer!) + 1]
			]
			cc/TERM_VMIN:  as-byte 1
			cc/TERM_VTIME: as-byte 0

			tcsetattr stdin TERM_TCSADRAIN term
		]

		restore: does [
			tcsetattr stdin TERM_TCSADRAIN saved-term
		]
	]
]

open-terminal:  routine [][kibi/init]
close-terminal: routine [][kibi/restore]
read-byte:		routine [][integer/box kibi/read-char]

emit-buffer:	routine [buffer [binary!]][
	write stdout as-c-string binary/rs-head buffer binary/rs-length? buffer
]

get-window-size: routine [][
	kibi/get-window-size pair/make-at stack/arguments 0 0
]

