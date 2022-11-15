SHELL := /bin/bash

# ============================
# UTS random number generator
# ============================

# Default
ifndef RNG
RNG=BRG
endif

RNG_PATH = ./src/rng

# ifeq ($(RNG), Devine)
# RNG_SRC = $(RNG_PATH)/devine_sha1.c
# RNG_INCL= $(RNG_PATH)/devine_sha1.h
# RNG_DEF = -DDEVINE_RNG
# endif
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

CHPL_MODULES_DIR = ./chplModules
CHPL_OPTS = --fast -M $(CHPL_MODULES_DIR) --ccflags $(RNG_DEF)
C_FILES = $(RNG_SRC) $(RNG_INCL)

COMPILE = $(COMPILER) $(CHPL_OPTS) $(C_FILES)

# ==================
# Build Chapel code
# ==================

chapel: main.chpl
	$(COMPILE) main.chpl -o main.o

.PHONY: clean
clean:
	rm main.o
	rm main.o_real
