SHELL := /bin/bash

# ==========================
# Compiler & common options
# ==========================

CHPL_COMPILER = chpl

COMMONS_DIR = ./commons
DATA_STRUCT_DIR = ./DistBag-DFS

CHPL_COMMON_OPTS = --fast -M $(COMMONS_DIR) -M $(DATA_STRUCT_DIR)

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

PFSP_DIR = ./benchmarks/PFSP
PFSP_OPTS = -M $(PFSP_DIR) -M $(PFSP_DIR)/instances

main_pfsp.out: main_pfsp.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(PFSP_OPTS) $< -o $@

# ==================
# QAP
# ==================

QAP_DIR = ./benchmarks/QAP
QAP_SRC_DIR = $(QAP_DIR)/c_sources

QAP_SOURCES = objective.cpp bound_glb.cpp
QAP_OBJECTS = $(addprefix $(QAP_SRC_DIR)/, $(QAP_SOURCES:.cpp=.o))
QAP_LIB = libqap.a

QAP_OPTS = -M $(QAP_DIR) -M $(QAP_DIR)/instances

# ---- C++ compilation rule ----
$(QAP_SRC_DIR)/%.o: $(QAP_SRC_DIR)/%.cpp
	g++ -O3 -c $< -o $@

# ---- Static library ----
$(QAP_LIB): $(QAP_OBJECTS)
	ar rcs $@ $^

# ---- Chapel executable ----
main_qap.out: main_qap.chpl $(QAP_LIB)
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(QAP_OPTS) -snewRangeLiteralType $< $(QAP_LIB) -o $@

# ==================
# UTS
# ==================

UTS_DIR = ./benchmarks/UTS
UTS_SRC_DIR = $(UTS_DIR)/c_sources

# Default random number generator (RNG)
ifndef RNG
RNG=BRG
endif

ifeq ($(RNG), BRG)
RNG_SRC = $(UTS_SRC_DIR)/brg_sha1.c
RNG_DEF = -DBRG_RNG
endif

ifeq ($(RNG), ALFG)
RNG_SRC = $(UTS_SRC_DIR)/alfg.c
RNG_DEF = -DUTS_ALFG
endif

UTS_C_OPTS = --ccflags $(RNG_DEF)
UTS_OPTS = -M $(UTS_DIR) $(UTS_C_OPTS) $(RNG_SRC)

main_uts.out: main_uts.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(UTS_OPTS) $< -o $@

# ==================
# NQueens
# ==================

NQUEENS_DIR = ./benchmarks/NQueens
NQUEENS_OPTS = -M $(NQUEENS_DIR)

main_nqueens.out: main_nqueens.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(NQUEENS_OPTS) $< -o $@

# ==================
# Knapsack
# ==================

KNAPSACK_DIR = ./benchmarks/Knapsack
KNAPSACK_OPTS = -M $(KNAPSACK_DIR) -M $(KNAPSACK_DIR)/instances

main_knapsack.out: main_knapsack.chpl
	$(CHPL_COMPILER) $(CHPL_COMMON_OPTS) $(KNAPSACK_OPTS) $< -o $@

# ==========================
# Utilities
# ==========================

.PHONY: clean

clean:
	rm -f $(EXECUTABLES)
	rm -f $(EXECUTABLES:=_real)
	rm -f $(QAP_OBJECTS) $(QAP_LIB)
