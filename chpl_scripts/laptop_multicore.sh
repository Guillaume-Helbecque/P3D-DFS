#!/bin/bash

# Chapel environment script for multi-core experiments on laptop

export CHPL_VERSION="1.28.0"
export CHPL_HOME=~/chapel-${CHPL_VERSION}

export CHPL_LLVM=none

CHPL_BIN_SUBDIR=`"$CHPL_HOME"/util/chplenv/chpl_bin_subdir.py`
export PATH="$PATH":"$CHPL_HOME/bin/$CHPL_BIN_SUBDIR"

export MANPATH="$MANPATH":"$CHPL_HOME"/man

export CHPL_HOST_PLATFORM=`$CHPL_HOME/util/chplenv/chpl_platform.py`
export CHPL_HOST_COMPILER=gnu # gnu or clang
export CHPL_TARGET_ARCH=native

NUM_T_LOCALE=$(cat /proc/cpuinfo | grep processor | wc -l) # hyperthreading
export CHPL_RT_NUM_THREADS_PER_LOCALE=$NUM_T_LOCALE
export CHPL_TASKS=qthreads # qthreads or fifo

echo -e \#\#\# QThreads set for $CHPL_RT_NUM_THREADS_PER_LOCALE threads \#\#\#.

export here=$(pwd)

echo $here

cd $CHPL_HOME
make -j ${NUM_T_LOCALE}

echo -e \#\#\# Building runtime ${CHPL_VERSION} QTHREADS. \#\#\#

cd $here
