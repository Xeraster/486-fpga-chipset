#!bin/bash

yosys -p 'synth_ice40 -top top -json main.json' main.v
nextpnr-ice40 --hx4k --json main.json --pcf main.pcf --asc main.asc --pcf-allow-unconstrained --package tq144
icepack main.asc main.bin
