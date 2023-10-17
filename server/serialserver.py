import select
import serial
import sys
import termios
import time
import tty


BAUD = 250000

LOGLEVEL = 1


def log(level, *args):
	if level <= LOGLEVEL:
		print(*args)



def adc(a, b, carry):
	r = a + b + carry
	return r % 256, r // 256



def cmd_start(cmd):
	log(3, "cmd_start(%d)" % cmd)
	ser.write(bytes([cmd]))
	echo = ser.read(1)[0]
	if echo != cmd:
		print("Echo mismatch - cmd=%s echo=%s" % (cmd, echo))
		sys.exit(1)


def cmd_address(addr):
	log(2, "cmd_address(%04x)" % addr)
	cmd_start(1)
	payload = bytes([addr % 256, addr // 256])
	ser.write(payload)
	echo = ser.read(2)
	if echo != payload:
		print("Echo mismatch - address command - payload=%s echo=%s" % (repr(payload), repr(echo)))
		sys.exit(1)


def cmd_loaddata(data):
	log(2, "cmd_loaddata")
	cmd_start(2)
	payload = bytes(data)
	log(4, "data: %s" % repr(payload))
	ser.write(payload)
	echo = ser.read(2)

	check2 = 0
	check3 = 0
	carry = 0
	for b in payload:
		check2, carry = adc(b, check2, carry)
		check3, carry = adc(check2, check3, carry)

	expected_echo = bytes([check2, check3])
	if echo != expected_echo:	
		print("Echo mismatch - loaddata command - expected=%s echo=%s" % (repr(expected_echo), repr(echo)))
		sys.exit(1)

def cmd_execute():
	log(2, "cmd_execute()")
	cmd_start(3)



def load_file(address, filename):
	log(1, "Reading file '%s'" % filename)
	with open(filename, "rb") as fp:
		data = fp.read()
		fp.close()

	log(1, "Loading %04x bytes to address %04x" % (len(data), address))
	cmd_address(address)
	for i in range(0, len(data), 256):
		block = data[i:i+256]
		if len(block) < 256:
			block = block + bytes(256-len(block))
		cmd_loaddata(block)


def go(address):
	log(1, "Go to %04x" % address)
	cmd_address(address)
	cmd_execute()


def serialconsole():
	log(1, "\n--- Serial console, ^C to quit ---\n")

	outfile = open("log.txt", "w")

	stdin = sys.stdin.fileno()
	tattr = termios.tcgetattr(stdin)
	ser.timeout = 0

	try:
		tty.setcbreak(stdin, termios.TCSANOW)

		while True:
			readyinputs = select.select([sys.stdin, ser], [], [], 1000)[0]
			if sys.stdin in readyinputs:
				b = sys.stdin.buffer.read(1)
				ser.write(b)
			if ser in readyinputs:
				buffer = ser.read()
				if buffer:
					for b in buffer:
						if b < 128:
							print(chr(b), end="", flush=True)
							outfile.write(chr(b))
						else:
							print("\\x%02x" % b, end="", flush=True)
							outfile.write("\\x%02x" % b)

	finally:
		termios.tcsetattr(stdin, termios.TCSANOW, tattr)

	outfile.close()


log(1, "Initialising link")
ser = serial.Serial("/dev/ttyUSB0", BAUD, 8, "N", 1)

time.sleep(0.1)
ser.write(bytes([0xff]))

log(1, "Waiting for client")
buffer = b""
while True:
	buffer = buffer+ser.read()
	log(2, "input buffer: %s" % repr(buffer))
	if buffer.endswith(b"boot0001"):
		break
	if len(buffer) > 10:
		buffer = buffer[-10:]

log(1, "Connected at %d baud" % BAUD)
log(1, "")


apps = [
	( 0x0200, 0x0206, "boottestcode" ),
	( 0x0700, 0x0700, "osapp" ),
	( 0x0200, 0x020c, "dormann" ),
	( 0x0200, 0x0206, "memtest" ),
	( 0x0200, 0x0206, "sdtest" ),
	( 0x0200, 0x0206, "viatest" ),
	( 0x0200, 0x0206, "cpuspeed" ),
	( 0x7000, 0x7000, "gibl" ),
	( 0x0200, 0x0206, "mandel" ),
	( 0x0200, 0x0206, "mandel2" ),
	( 0x0200, 0x0206, "mandelcolour" ),
	( 0x0200, 0x0203, "primesieve" ),
	( 0x0200, 0x0203, "primesieveverbose" ),
	( 0x0200, 0x0203, "primesieve2" ),
	( 0x0200, 0x0203, "life" ),
]

while True:
	print("Choose code to run:")
	for i, (load,execute,name) in enumerate(apps):
		print(i, name)
	j = int(input('?'))
	if j < len(apps):
		break

load, execute, name = apps[j]
load_file(load, "../bin/apps/%s.bin" % name)
go(execute)


serialconsole()

