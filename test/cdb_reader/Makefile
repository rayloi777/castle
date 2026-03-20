# CastleDB C Reader Makefile

CC = gcc
AR = ar
CFLAGS = -Wall -Wextra -pedantic -std=c99 -O2
ARFLAGS = rcs

SRC_DIR = .
BUILD_DIR = build
EXAMPLE_DIR = example

LIB_NAME = cdb_reader
LIB_FILE = lib$(LIB_NAME).a

SOURCES = cdb_reader.c
HEADERS = cdb_reader.h jsmn.h

.PHONY: all clean install example

all: $(BUILD_DIR)/$(LIB_FILE)

$(BUILD_DIR)/$(LIB_FILE): $(SOURCES) $(HEADERS)
	@mkdir -p $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $(SRC_DIR)/cdb_reader.c -o $(BUILD_DIR)/cdb_reader.o
	$(AR) $(ARFLAGS) $@ $(BUILD_DIR)/cdb_reader.o

example: $(BUILD_DIR)/$(LIB_FILE)
	@mkdir -p $(BUILD_DIR)/example
	$(CC) $(CFLAGS) -I$(SRC_DIR) $(EXAMPLE_DIR)/main.c $(BUILD_DIR)/$(LIB_FILE) -o $(BUILD_DIR)/example/cdb_example

clean:
	rm -rf $(BUILD_DIR)

install: $(BUILD_DIR)/$(LIB_FILE)
	@mkdir -p include
	cp $(HEADERS) include/
	cp $(BUILD_DIR)/$(LIB_FILE) lib/

test: example
	$(BUILD_DIR)/example/cdb_example ../item.cdb
