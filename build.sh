#!/bin/bash
ca65 --cpu 6502 -o main.o main.asm -l main.list && ld65 -C ~/smallprogs/cc65/cfg/nes.cfg main.o -o game.nes && echo Built on $(date)