#!/bin/bash

../.build/crystal build --debug -s -p -t --emit=llvm-ll ./crweb.cr
### crystal build --debug -s -p -t -emit=asm ./crweb.cr
