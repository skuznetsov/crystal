#!/bin/bash

make clean
CRYSTAL_ROOT=. CRYSTAL_HAS_WRAPPER=true make progress=1 release=1
