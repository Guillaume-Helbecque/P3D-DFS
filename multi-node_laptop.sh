export CHPL_VERSION="distbag-1.26.0"
export CHPL_HOME=~/chapel-${CHPL_VERSION}

export CHPL_LLVM=none

CHPL_BIN_SUBDIR=`"$CHPL_HOME"/util/chplenv/chpl_bin_subdir.py`
export PATH="$PATH":"$CHPL_HOME/bin/$CHPL_BIN_SUBDIR"

export MANPATH="$MANPATH":"$CHPL_HOME"/man

export CHPL_HOST_PLATFORM=`$CHPL_HOME/util/chplenv/chpl_platform.py`
export CHPL_HOST_COMPILER=gnu # gnu or clang
export CHPL_TARGET_ARCH=native
export CHPL_TARGET_CPU=native

NUM_T_LOCALE=$(cat /proc/cpuinfo | grep processor | wc -l) # hyperthreading
export CHPL_RT_NUM_THREADS_PER_LOCALE=$NUM_T_LOCALE
export CHPL_TASKS=qthreads # qthreads or fifo

export CHPL_COMM=gasnet
export CHPL_COMM_SUBSTRATE=udp
export GASNET_SPAWNFN=L

cd $CHPL_HOME
make

chpl -o hello6-taskpar-dist $CHPL_HOME/examples/hello6-taskpar-dist.chpl
./hello6-taskpar-dist -nl 2
