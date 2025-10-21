#!/bin/bash

crystal build --debug -s -p -t --threads 1 --emit=llvm-ir ./crweb.cr
