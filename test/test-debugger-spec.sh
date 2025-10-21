#!/bin/bash

../bin/crystal build --debug --link-flags="-L/usr/local/opt/ruby/lib -L/usr/local/opt/llvm/lib -L/usr/local/opt/curl-openssl/lib "  --exclude-warnings spec/std --exclude-warnings spec/compiler -o ../.build/debug_spec -s -p -t ../spec/compiler/codegen/debug_spec.cr
