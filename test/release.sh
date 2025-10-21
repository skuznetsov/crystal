#!/bin/bash

../.build/crystal build --release --no-debug -s -p -t --emit=llvm-ir ./crweb.cr
