#!/bin/bash

LLVM_PATH=/opt/homebrew/Cellar/llvm/19.1.7_1/bin/

make clean
cp ./test-bin/Backup/* ./test-bin/
CRYSTAL_ROOT=. CRYSTAL_HAS_WRAPPER=true LLVM_CONFIG=$LLVM_PATH/llvm-config  make -f Makefile.debug_no_output
cp ./.build/* ./test-bin/
make clean
CRYSTAL_ROOT=. CRYSTAL_HAS_WRAPPER=true LLVM_CONFIG=$LLVM_PATH/llvm-config  make -f Makefile.debug_no_output
cp ./.build/* ./test-bin/
