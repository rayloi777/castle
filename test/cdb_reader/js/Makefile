# CastleDB QuickJS Extension Makefile

# QuickJS paths (adjust as needed)
QUICKJS_DIR ?= /usr/local/include/quickjs
QUICKJS_LIB ?= /usr/local/lib

CC = gcc
CFLAGS = -Wall -Wextra -pedantic -std=c99 -O2 -fPIC
LDFLAGS = -shared

# Directories
CDB_DIR = ..
BUILD_DIR = build

# Output
MODULE_NAME = cdb
MODULE_FILE = $(MODULE_NAME).so

# Sources
CDB_READER_SRC = $(CDB_DIR)/cdb_reader.c
QUICKJS_SRC = cdb_quickjs.c

# Include paths
INCLUDES = -I$(CDB_DIR) -I$(QUICKJS_DIR)

# Libraries
LIBS = -lquickjs

.PHONY: all clean test

all: $(BUILD_DIR)/$(MODULE_FILE)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/$(MODULE_FILE): $(QUICKJS_SRC) $(CDB_READER_SRC)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) $(INCLUDES) $(LDFLAGS) -o $@ $(QUICKJS_SRC) $(CDB_READER_SRC) $(LIBS)

clean:
	rm -rf $(BUILD_DIR)

test: all
	@echo "QuickJS module built: $(BUILD_DIR)/$(MODULE_FILE)"
	@echo "To test with QuickJS, run:"
	@echo "  qjs --addon $(BUILD_DIR)/$(MODULE_FILE) test_cdb.js"
	@echo ""
	@echo "Or use the cdb_module.js wrapper:"
	@echo "  qjs -e \"var CDB = require('./cdb_module.js').CDB; var db = CDB.open('../item.cdb'); print(db.getSheetNames()); db.close();\""

install: all
	mkdir -p $(QUICKJS_LIB)/addons
	cp $(BUILD_DIR)/$(MODULE_FILE) $(QUICKJS_LIB)/addons/
	cp cdb_module.js $(QUICKJS_LIB)/addons/cdb.js
	@echo "Installed to $(QUICKJS_LIB)/addons/"
