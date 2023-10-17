import serial
import sys

ser = serial.Serial("/dev/ttyUSB0", 250000, 8, "N", 1)

while True:
	buffer = ser.read()
	for b in buffer:
		if b < 128:
			print(chr(b), end="", flush=True)
		else:
			print("\\%02x" % b, end="", flush=True)

