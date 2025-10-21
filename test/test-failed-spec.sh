#!/bin/bash

### ../.build/crystal build -D i_know_what_im_doing --debug --link-flags="-L/usr/local/opt/ruby/lib -L/usr/local/opt/llvm/lib -L/usr/local/opt/curl-openssl/lib "  --exclude-warnings spec/std --exclude-warnings spec/compiler -o ../.build/test_failed_spec -s -p -t ../spec/compiler/codegen/no_return_spec.cr ../spec/compiler/codegen/uninitialized_spec.cr
../.build/crystal build -D i_know_what_im_doing -D preview_mt --threads 1 --debug --link-flags="-L/usr/local/opt/ruby/lib -L/usr/local/opt/llvm/lib -L/usr/local/opt/curl-openssl/lib "  --exclude-warnings spec/std --exclude-warnings spec/compiler -o ../.build/test_failed_spec -s -p -t ../spec/std/http/web_socket_spec.cr

