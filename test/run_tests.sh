#!/bin/bash

../.build/crystal build --debug --error-trace -s -p -t --emit=llvm-ir ./debug_tests.cr
