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

# Tree size: 4996490, Number of leaves: 2499245 (50.02%), Tree depth: 3472
export T1="--t 0 --b 2000 --m 2 --q 0.499995    --r 38"

# Tree size: 51747898, Number of leaves: 25874949 (50.0019%), Tree depth: 16604
export T2="--t 0 --b 2000 --m 2 --q 0.499995    --r 30"

# Tree size: 514989316, Number of leaves: 257495658 (50.0002%), Tree depth: 53013
export T3="--t 0 --b 2000 --m 2 --q 0.499995    --r 55"

# Tree size: 10612052302, Number of leaves: 5306027151 (50.0%), Tree depth: 216370
export T4="--t 0 --b 2000 --m 2 --q 0.499999995 --r 0"

# Tree size: 52990562042, Number of leaves: 26495282021 (50.0%), Tree depth: 448401
export T5="--t 0 --b 2000 --m 2 --q 0.4999975   --r 559"

# Tree size: 94795626942, Number of leaves: 47397814471 (50.0%), Tree depth: 596616
export T6="--t 0 --b 2000 --m 2 --q 0.499999    --r 559"
