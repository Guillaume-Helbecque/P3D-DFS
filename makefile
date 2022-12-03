SHELL := /bin/bash

# ============================
# UTS random number generator
# ============================

# Default
ifndef RNG
RNG=BRG
endif

RNG_PATH = ./c_sources/rng

ifeq ($(RNG), BRG)
RNG_SRC = $(RNG_PATH)/brg_sha1.c
RNG_INCL= $(RNG_PATH)/brg_sha1.h
RNG_DEF = -DBRG_RNG
endif
ifeq ($(RNG), ALFG)
RNG_SRC = $(RNG_PATH)/alfg.c
RNG_INCL= $(RNG_PATH)/alfg.h
RNG_DEF = -DUTS_ALFG
endif

# ===================
# Compiler & options
# ===================

COMPILER = chpl

CHPL_MODULES_DIR = ./chpl_modules
CHPL_DATA_STRUCT_DIR = ./DistBag-DFS
CHPL_OPTS = --fast -M $(CHPL_MODULES_DIR) -M $(CHPL_DATA_STRUCT_DIR)
C_FILES = $(RNG_SRC) $(RNG_INCL)
C_OPTS = --ccflags $(RNG_DEF)

# ==================
# Build Chapel code
# ==================

all: main_pfsp.o main_uts.o main_nqueens.o

main_pfsp.o: main_pfsp.chpl
	$(COMPILER) $(CHPL_OPTS) main_pfsp.chpl -o main_pfsp.o

main_uts.o: main_uts.chpl
	$(COMPILER) $(CHPL_OPTS) $(C_OPTS) $(C_FILES) main_uts.chpl -o main_uts.o

main_nqueens.o: main_nqueens.chpl
	$(COMPILER) $(CHPL_OPTS) main_nqueens.chpl -o main_nqueens.o

.PHONY: clean
clean:
	rm main_*.o
	rm main_*.o_real
