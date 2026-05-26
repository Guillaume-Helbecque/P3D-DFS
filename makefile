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
QAP_HDR_DIR = $(QAP_DIR)/c_headers

QAP_SOURCES = $(wildcard $(QAP_SRC_DIR)/*.cpp)
QAP_OBJECTS = $(QAP_SOURCES:.cpp=.o)
QAP_LIB = libqap.a

EIGEN_VERSION := $(shell cat $(QAP_HDR_DIR)/EIGEN_VERSION)
EIGEN_DIR = $(QAP_HDR_DIR)/eigen-$(EIGEN_VERSION)/
EIGEN_URL = https://gitlab.com/libeigen/eigen/-/archive/$(EIGEN_VERSION)/eigen-$(EIGEN_VERSION).tar.gz

QAP_CXX_FLAGS = -O3 -std=c++17 -march=native -DEIGEN_NO_DEBUG -I$(EIGEN_DIR)

QAP_OPTS = -M $(QAP_DIR) -M $(QAP_DIR)/instances

download-eigen:
	@echo "Checking Eigen version $(EIGEN_VERSION)..."
	@if [ -d "$(EIGEN_DIR)" ]; then \
		echo "Eigen already present at $(EIGEN_DIR), skipping."; \
		exit 0; \
	fi; \
	set -e; \
	TMP_DIR="$(QAP_HDR_DIR)/.eigen_tmp"; \
	TMP_TAR="$$TMP_DIR/eigen.tar.gz"; \
	mkdir -p "$$TMP_DIR"; \
	echo "Downloading Eigen from $(EIGEN_URL)..."; \
	if ! wget -q --show-progress -O "$$TMP_TAR" "$(EIGEN_URL)"; then \
		echo "ERROR: Failed to download Eigen version $(EIGEN_VERSION)"; \
		rm -rf "$$TMP_DIR"; \
		exit 1; \
	fi; \
	echo "Extracting..."; \
	tar -xzf "$$TMP_TAR" -C "$$TMP_DIR"; \
	echo "Installing headers..."; \
	mkdir -p "$(EIGEN_DIR)"; \
	cp -r "$$TMP_DIR/eigen-$(EIGEN_VERSION)/Eigen" "$(EIGEN_DIR)/"; \
	rm -rf "$$TMP_DIR"; \
	echo "Eigen $(EIGEN_VERSION) installed."

clean-eigen:
	@rm -rf "$(QAP_HDR_DIR)"/eigen-*

$(QAP_SRC_DIR)/%.o: $(QAP_SRC_DIR)/%.cpp
	g++ $(QAP_CXX_FLAGS) -c $< -o $@

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

.PHONY: clean download-eigen clean-eigen

clean:
	@rm -f $(EXECUTABLES)
	@rm -f $(EXECUTABLES:=_real)
	@rm -f $(QAP_OBJECTS) $(QAP_LIB)
