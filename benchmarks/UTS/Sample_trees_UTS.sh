#-----------------------------------------------------------------------------#
# Sample UTS Workloads:
#
#  This file contains sample workloads for UTS, along with the tree statistics
#  for verifying correct output from the benchmark. This file is intended to
#  be used in shell scripts or from the shell so that UTS can be run by:
#
#   $ source sample_trees_UTS.sh
#   $ ./main_uts.o --mode=distributed $T1 -nl 2
#
#-----------------------------------------------------------------------------#

# ================
# Binomial trees
# ================

#
export T1 = "--t 0 --b 2000 --m 2 --q 0.499995    --r 38"

#
export T2 = "--t 0 --b 2000 --m 2 --q 0.499995    --r 30"

#
export T3 = "--t 0 --b 2000 --m 2 --q 0.499995    --r 55"

#
export T4 = "--t 0 --b 2000 --m 2 --q 0.499999995 --r 0"

#
export T5 = "--t 0 --b 2000 --m 2 --q 0.4999975   --r 559"

#
export T6 = "--t 0 --b 2000 --m 2 --q 0.499999    --r 559"
