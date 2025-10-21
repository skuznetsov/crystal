#!/bin/bash

make clean
cp ./test-bin/Backup/* ./test-bin/
CRYSTAL_ROOT=. CRYSTAL_HAS_WRAPPER=true make -f Makefile.debug
cp ./.build/* ./test-bin/
make clean
CRYSTAL_ROOT=. CRYSTAL_HAS_WRAPPER=true make
