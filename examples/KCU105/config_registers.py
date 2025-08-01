import serial
import time

#========= UART =============

SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 115200
TIMEOUT = 0.1

#============================

#====== BASE ADDRESSES ======

MAIN_BASE_ADDR_10G = 0x0000
TEST_BASE_ADDR_10G = 0x2000
MAIN_BASE_ADDR_1G = 0x4000
TEST_BASE_ADDR_1G = 0x6000

#============================

#====== MAIN REGISTER 1G ======

#MAC Address: 00:0A:35:03:3E:F1

LOCAL_MAC_ADDR_LSB = 0x35033EF1
LOCAL_MAC_ADDR_MSB = 0x0000000A

#IP Address: 192.168.1.105

LOCAL_IP_ADDR = 0xC0A80169
CONFIG_DONE = 0x00000001

#==============================

#====== TEST REGISTER 1G ======

REG_GEN_CONFIG = 0xFF040000
GEN_NB_BYTES_LSB = 0x0000FFFF
GEN_NB_BYTES_MSB = 0x00000000
LB_GEN_DEST_IP_ADDR = 0xC0A80105

#==============================

MAIN_DICTIONARY_1G = {
	0x4: LOCAL_MAC_ADDR_LSB,
	0x8: LOCAL_MAC_ADDR_MSB,
	0xC: LOCAL_IP_ADDR,
	0x38: CONFIG_DONE
}

TEST_DICTIONARY_1G = {
	0x4: REG_GEN_CONFIG,
	0x8: GEN_NB_BYTES_LSB,
	0xC: GEN_NB_BYTES_MSB,
	0X2C: LB_GEN_DEST_IP_ADDR
}

ser = serial.Serial(port=SERIAL_PORT, baudrate=BAUD_RATE, timeout=TIMEOUT)

for key, value in MAIN_DICTIONARY_1G.items():
	cmd = f'W{(MAIN_BASE_ADDR_1G+key):04X}-{value:08X}\r'
	ser.write(cmd.encode())
	time.sleep(0.01)

for key, value in TEST_DICTIONARY_1G.items():
	cmd = f'W{(TEST_BASE_ADDR_1G+key):04X}-{value:08X}\r'
	ser.write(cmd.encode())
	time.sleep(0.01)

ser.close()