#!/bin/python
import serial
import time
 

time_stamp_prev = 0

ser = serial.Serial(  \
	port="/dev/tty.Bluetooth-Incoming-Port", \
	baudrate=38400, \
	parity=serial.PARITY_NONE, \
	stopbits=serial.STOPBITS_ONE, \
	bytesize=serial.EIGHTBITS )

while True:
	if ser.inWaiting() > 0:
		print ser.readline();
		time_stamp_curr = time.time()
		time_between_packets = time_stamp_curr - time_stamp_prev
		time_stamp_prev = time_stamp_curr
