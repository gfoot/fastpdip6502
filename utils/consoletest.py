import select
import sys
import termios
import tty

stdin = sys.stdin.fileno()
tattr = termios.tcgetattr(stdin)

try:
	tty.setcbreak(stdin, termios.TCSANOW)

	while True:
		if sys.stdin in select.select([sys.stdin], [], [], 1000)[0]:
			b = sys.stdin.buffer.read(1)
			b = ord(b)
			if b < 128:
				print(chr(b), end="", flush=True)
			else:
				print("\\%02x" % b, end="", flush=True)

finally:
    termios.tcsetattr(stdin, termios.TCSANOW, tattr)
