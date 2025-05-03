I'm fairly certain this is the latest iteration of this as seen in [this video](https://www.youtube.com/watch?v=9npggP93ksg).

There is special chipset-level handling for making the v9958 graphics card work. There curently is no wait state insertion for generic SLPC bus i/o cycles which I plan to change.

a significantly improved and more reliable version of the 8 bit slpc 486 chipset verilog. Uses tighter timing, better verilog practices and hopefully better v9958 performance. Currently untested but the previous stuff on here was terrible and wasn't even the "working" version anyway.

The latest changes are for getting spi roms to work for bios instead of parallel roms only. The bios.bin file is kind of a placeholder and isn't part of the fpga chipset code, although the build script inserts it into the same spi rom that the fpgagets its data from.
