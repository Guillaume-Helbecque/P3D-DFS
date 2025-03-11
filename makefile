SHELL := /bin/bash

# ==========================
# Compiler & common options
# ==========================

COMPILER = chpl
CHPL_COMMONS_DIR = ./commons
CHPL_DATA_STRUCT_DIR = ./DistBag-DFS

CHPL_COMMON_OPTS = --fast -M $(CHPL_COMMONS_DIR) -M $(CHPL_DATA_STRUCT_DIR)

# ==========================
# Build Chapel codes
# ==========================

all: main_pfsp.out main_pfsp_bin.ou main_uts.out main_nqueens.out main_knapsack.out

# ==========
# PFSP
# ==========

CHPL_PFSP_MODULES_DIR = ./benchmarks/PFSP
CHPL_PFSP_OPTS = -M $(CHPL_PFSP_MODULES_DIR) -M $(CHPL_PFSP_MODULES_DIR)/instances

main_pfsp.out: main_pfsp.chpl
	$(COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_PFSP_OPTS) main_pfsp.chpl -o main_pfsp.out

# ==========
# PFSP_bin
# ==========

CHPL_PFSP_BIN_MODULES_DIR = ./benchmarks/PFSP_bin
CHPL_PFSP_BIN_OPTS = -M $(CHPL_PFSP_BIN_MODULES_DIR) -M $(CHPL_PFSP_BIN_MODULES_DIR)/instances

main_pfsp_bin.out: main_pfsp_bin.chpl
	$(COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_PFSP_BIN_OPTS) main_pfsp_bin.chpl -o main_pfsp_bin.out

# ==========
# UTS
# ==========

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
	$(COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_UTS_OPTS) main_uts.chpl -o main_uts.out

# ==========
# NQueens
# ==========

CHPL_NQUEENS_MODULES_DIR = ./benchmarks/NQueens
CHPL_NQUEENS_OPTS = -M $(CHPL_NQUEENS_MODULES_DIR)

main_nqueens.out: main_nqueens.chpl
	$(COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_NQUEENS_OPTS) main_nqueens.chpl -o main_nqueens.out

# ==========
# Knapsack
# ==========

CHPL_KNAPSACK_MODULES_DIR = ./benchmarks/Knapsack
CHPL_KNAPSACK_OPTS = -M $(CHPL_KNAPSACK_MODULES_DIR) -M $(CHPL_KNAPSACK_MODULES_DIR)/instances

main_knapsack.out: main_knapsack.chpl
	$(COMPILER) $(CHPL_COMMON_OPTS) $(CHPL_KNAPSACK_OPTS) main_knapsack.chpl -o main_knapsack.out

# ==========================
# Utilities
# ==========================

.PHONY: clean

clean:
	rm -f main_*.out
	rm -f main_*.out_real
