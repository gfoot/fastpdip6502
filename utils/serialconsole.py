import select
import serial
import sys
import termios
import tty

ser = serial.Serial("/dev/ttyUSB0", 125000, 8, "N", 1, timeout=0)

stdin = sys.stdin.fileno()
tattr = termios.tcgetattr(stdin)

try:
	tty.setcbreak(stdin, termios.TCSANOW)

	while True:
		readyinputs = select.select([sys.stdin, ser], [], [], 1000)[0]
		if sys.stdin in readyinputs:
			b = sys.stdin.buffer.read(1)
			#print(ord(b))
			ser.write(b)
		if ser in readyinputs:
			buffer = ser.read()
			if buffer:
				for b in buffer:
					if b < 128:
						print(chr(b), end="", flush=True)
					else:
						print("\\%02x" % b, end="", flush=True)

finally:
    termios.tcsetattr(stdin, termios.TCSANOW, tattr)
