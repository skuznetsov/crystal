#!/bin/bash

DUMP=1 
../.build/crystal build --debug -s -p -t --emit=llvm-ir ./crweb.cr
###../.build/crystal build --debug -s -p -t --emit=asm ./crweb.cr
