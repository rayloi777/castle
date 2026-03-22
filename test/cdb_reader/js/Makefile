# CastleDB QuickJS Extension Makefile

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -O2 -fPIC
CFLAGS += -DQJS_BUILD_LIBC -DWITH_EVAL

# Directories
CDB_DIR = ..
BUILD_DIR = build

# Output
TEST_EXE = test_cdb

# Sources
CDB_READER_SRC = $(CDB_DIR)/cdb_reader.c
QUICKJS_SRC = quickjs-amalgam.c
TEST_SRC = test_cdb_main.c

# Include paths
INCLUDES = -I$(CDB_DIR) -I.

# Libraries
LIBS = -lm

.PHONY: all clean test_exe

all: test_exe

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(TEST_EXE): $(CDB_READER_SRC) $(TEST_SRC) $(QUICKJS_SRC)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $(QUICKJS_SRC) $(CDB_READER_SRC) $(TEST_SRC) $(LIBS)

clean:
	rm -rf $(BUILD_DIR)

test_exe: $(BUILD_DIR)/$(TEST_EXE)
	@echo "Running test..."
	$(BUILD_DIR)/$(TEST_EXE) ../../item.cdb