# A-ONE EEPROM

The A-ONE SERIAL interface features an EPROM/EEPROM/SRAM on location `$C800-$CFFF`. In order to load the program into the EEPROM, it is necessary to wait 10ms per byte while writing. The best way to program the chip is a block copy from SRAM into the EEPROM.

Using the WozMon to enter a program by loading it into memory by pasting, the original code for location `$C800-$CFFF` needs to be offset so it will successfuly into memory. The `Makefile` allows the generation of the `*.woz` file with the offset.

In order to program the chip three utilities are available:
- **memfill** ; fill the memory with a 8 or 16-bit pattern
- **eeerase** ; erase the EEPROM by setting all values to `$FF`
- **eeprog**  ; program the EEPROM by copying from SRAM to EEPROM

# FILES

The `tools/a1tool.py` is a python help application and NEEDED by the `Makefile`. Also `wozmon.s` contains the info on the Apple-1 Woz Monitor, and the `apple1.cfg` contains the memory map for the linker.

