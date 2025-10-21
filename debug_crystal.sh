#!/bin/bash

lldb -- .build/crystal build --debug --threads 1 -s -p --prelude src/prelude.cr test/debug_tests.cr
