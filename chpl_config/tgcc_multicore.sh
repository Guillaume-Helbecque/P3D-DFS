#!/bin/bash

# Configuration of Chapel for multi-core experiments on the Irene cluster of
# the TGCC/CEA (https://hpc.cea.fr/tgcc-public/en/html/tgcc-public.html).

# Load modules
module load c/gnu/14.2.0
module load cmake/3.29.6

export HERE=$PWD

export CHPL_VERSION=$(cat CHPL_VERSION)
export CHPL_HOME="$PWD/../../chapel-${CHPL_VERSION}MC"

# Download Chapel if not found
if [ ! -d "$CHPL_HOME" ]; then
  # NOTE: we cannot direct download from the web on this cluster. We thus assume
  # that the Chapel archive is already uncompressed.

  # wget -c https://github.com/chapel-lang/chapel/releases/download/$CHPL_VERSION/chapel-${CHPL_VERSION}.tar.gz -O - | tar xz
  mv $PWD/../../chapel-$CHPL_VERSION $CHPL_HOME
fi

CHPL_BIN_SUBDIR=`"$CHPL_HOME"/util/chplenv/chpl_bin_subdir.py`
export PATH="$PATH":"$CHPL_HOME/bin/$CHPL_BIN_SUBDIR:$CHPL_HOME/util"

export CHPL_COMM="none"
export CHPL_HOST_PLATFORM="linux64"
export CHPL_HOST_COMPILER="gnu"
export CHPL_LLVM="none"
export CHPL_RT_NUM_THREADS_PER_LOCALE=1 #$SLURM_CPUS_PER_TASK

cd $CHPL_HOME
make -j4 #16 $SLURM_CPUS_PER_TASK
cd $HERE/..
