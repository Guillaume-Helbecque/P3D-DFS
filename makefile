SHELL := /bin/bash

# ==========================
# Compiler & common options
# ==========================

CHPL_COMPILER = chpl
CHPL_COMMONS_DIR = ./commons
CHPL_DATA_STRUCT_DIR = ./DistBag-DFS

CHPL_COMMON_OPTS = --fast -M $(CHPL_COMMONS_DIR) -M $(CHPL_DATA_STRUCT_DIR)

# ==========================
# Build Chapel codes
# ==========================

MAIN_FILES = $(wildcard main_*.chpl)
EXECUTABLES = $(MAIN_FILES:.chpl=.out)

all: $(EXECUTABLES)

# ==================
# Generic
# ==================

main_%.out: main_%.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $< -o $@

# ==================
# PFSP
# ==================

CHPL_PFSP_MODULES_DIR = ./benchmarks/PFSP
CHPL_PFSP_OPTS = -M $(CHPL_PFSP_MODULES_DIR) -M $(CHPL_PFSP_MODULES_DIR)/instances

main_pfsp.out: main_pfsp.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_PFSP_OPTS) $< -o $@

# ==================
# Qubit allocation
# ==================

CHPL_QUBIT_ALLOC_MODULES_DIR = ./benchmarks/QubitAllocation
CHPL_QUBIT_ALLOC_OPTS = -M $(CHPL_QUBIT_ALLOC_MODULES_DIR) -M $(CHPL_QUBIT_ALLOC_MODULES_DIR)/instances

main_qubitAlloc.out: main_qubitAlloc.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_QUBIT_ALLOC_OPTS) $< -o $@

# ==================
# UTS
# ==================

CHPL_UTS_MODULES_DIR = ./benchmarks/UTS

# Default random number generator (RNG)
ifndef RNG
RNG=BRG
endif

RNG_SRC_DIR  = $(CHPL_UTS_MODULES_DIR)/c_sources
RNG_INCL_DIR = $(CHPL_UTS_MODULES_DIR)/c_headers

ifeq ($(RNG), BRG)
RNG_SRC = $(RNG_SRC_DIR)/brg_sha1.c
RNG_INCL= $(RNG_INCL_DIR)/brg_sha1.h
RNG_DEF = -DBRG_RNG
endif
ifeq ($(RNG), ALFG)
RNG_SRC = $(RNG_SRC_DIR)/alfg.c
RNG_INCL= $(RNG_INCL_DIR)/alfg.h
RNG_DEF = -DUTS_ALFG
endif

C_FILES = $(RNG_SRC) $(RNG_INCL)
C_OPTS = --ccflags $(RNG_DEF)

CHPL_UTS_OPTS = -M $(CHPL_UTS_MODULES_DIR) $(C_OPTS) $(C_FILES)

main_uts.out: main_uts.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_UTS_OPTS) $< -o $@

# ==================
# NQueens
# ==================

CHPL_NQUEENS_MODULES_DIR = ./benchmarks/NQueens
CHPL_NQUEENS_OPTS = -M $(CHPL_NQUEENS_MODULES_DIR)

main_nqueens.out: main_nqueens.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_NQUEENS_OPTS) $< -o $@

# ==================
# Knapsack
# ==================

CHPL_KNAPSACK_MODULES_DIR = ./benchmarks/Knapsack
CHPL_KNAPSACK_OPTS = -M $(CHPL_KNAPSACK_MODULES_DIR) -M $(CHPL_KNAPSACK_MODULES_DIR)/instances

main_knapsack.out: main_knapsack.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_KNAPSACK_OPTS) $< -o $@

# ==========================
# Utilities
# ==========================

.PHONY: clean

clean:
	rm -f $(EXECUTABLES)
	rm -f $(EXECUTABLES:=_real)
