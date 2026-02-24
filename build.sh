#!/bin/bash
ca65 --cpu 6502 -o main.o main.asm -g -l main.list && ld65 -C ~/smallprogs/cc65/cfg/nes.cfg main.o --dbgfile game.dbg -o game.nes && echo Built on $(date)