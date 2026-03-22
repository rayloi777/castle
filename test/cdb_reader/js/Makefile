# CastleDB QuickJS Extension Makefile

# QuickJS paths
QUICKJS_DIR ?= /opt/homebrew/include/quickjs
QUICKJS_LIB_DIR ?= /opt/homebrew/opt/quickjs/lib/quickjs

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -O2 -fPIC
LDFLAGS_SHARED = -shared -undefined dynamic_lookup
LDFLAGS_EXE = 

# Directories
CDB_DIR = ..
BUILD_DIR = build

# Output
MODULE_NAME = cdb
MODULE_FILE = $(MODULE_NAME).so
TEST_EXE = test_cdb

# Sources
CDB_READER_SRC = $(CDB_DIR)/cdb_reader.c
QUICKJS_SRC = cdb_quickjs.c
TEST_SRC = test_cdb_main.c

# Include paths
INCLUDES = -I$(CDB_DIR) -I$(QUICKJS_DIR)

# Libraries
LIBS_SHARED = -lm
LIBS_EXE = -L$(QUICKJS_LIB_DIR) -lquickjs -lm

.PHONY: all clean test test_exe

all: $(BUILD_DIR)/$(MODULE_FILE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(MODULE_FILE): $(QUICKJS_SRC) $(CDB_READER_SRC)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS_SHARED) -o $@ $(QUICKJS_SRC) $(CDB_READER_SRC) $(LIBS_SHARED)

$(BUILD_DIR)/$(TEST_EXE): $(CDB_READER_SRC) $(TEST_SRC)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) -o $@ $(CDB_READER_SRC) $(TEST_SRC) $(LIBS_EXE)

clean:
	rm -rf $(BUILD_DIR)

test: all
	@echo "QuickJS addon built: $(BUILD_DIR)/$(MODULE_FILE)"
	@echo "Note: Standard qjs doesn't support --addon"
	@echo "Run 'make test_exe' to build a standalone test executable"

test_exe: $(BUILD_DIR)/$(TEST_EXE)
	@echo "Running standalone test..."
	$(BUILD_DIR)/$(TEST_EXE) ../../item.cdb

install: all
	mkdir -p /opt/homebrew/lib/addons
	cp $(BUILD_DIR)/$(MODULE_FILE) /opt/homebrew/lib/addons/
	cp cdb_module.js /opt/homebrew/lib/addons/cdb.js
	@echo "Installed to /opt/homebrew/lib/addons/"