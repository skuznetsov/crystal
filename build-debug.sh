#!/bin/bash

export LLVM_CONFIG=/opt/homebrew/opt/llvm/bin/llvm-config
export CRYSTAL_ROOT=.
export CRYSTAL_HAS_WRAPPER=true 

make clean
cp ./test-bin/Backup/* ./test-bin/
CRYSTAL_DUMP_TYPE_ID=1 make -f Makefile.debug clean crystal interpreter=1 debug=1 stats=1 > ./compile.debug.log
