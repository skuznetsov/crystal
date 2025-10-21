#!/bin/bash

../.build/crystal build --release --no-debug --emit=llvm-ir -s -p -t  ./debug_tests.cr
