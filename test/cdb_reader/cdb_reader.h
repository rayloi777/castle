/*
 * CastleDB C Reader
 * 
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
 * SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
 * IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef CDB_READER_H
#define CDB_READER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define CDB_VERSION "1.0.0"

typedef enum {
    CDB_TID          = 0,
    CDB_TSTRING      = 1,
    CDB_TBOOL        = 2,
    CDB_TINT         = 3,
    CDB_TFLOAT       = 4,
    CDB_TENUM        = 5,
    CDB_TREF         = 6,
    CDB_TIMAGE       = 7,
    CDB_TLIST        = 8,
    CDB_TCUSTOM      = 9,
    CDB_TFLAGS       = 10,
    CDB_TCOLOR       = 11,
    CDB_TLAYER       = 12,
    CDB_TFILE        = 13,
    CDB_TTILEPOS     = 14,
    CDB_TTILELAYER   = 15,
    CDB_TDYNAMIC     = 16,
    CDB_TPROPERTIES  = 17,
    CDB_TGRADIENT    = 18,
    CDB_TCURVE       = 19,
    CDB_TGUID        = 20,
    CDB_TPOLYMORPH   = 21
} CDBColumnType;

typedef enum {
    CDB_OK                    = 0,
    CDB_ERROR_FILE_NOT_FOUND  = -1,
    CDB_ERROR_FILE_READ       = -2,
    CDB_ERROR_JSON_PARSE      = -3,
    CDB_ERROR_JSON_INVALID    = -4,
    CDB_ERROR_INVALID_CDB     = -5,
    CDB_ERROR_SHEET_NOT_FOUND  = -6,
    CDB_ERROR_COLUMN_NOT_FOUND = -7,
    CDB_ERROR_ROW_NOT_FOUND    = -8,
    CDB_ERROR_TYPE_MISMATCH   = -9,
    CDB_ERROR_OUT_OF_MEMORY   = -10
} CDBError;

typedef struct CDB CDB;
typedef struct CDBSheet CDBSheet;
typedef struct CDBColumn CDBColumn;
typedef struct CDBRow CDBRow;

typedef struct {
    CDBColumnType type;
    char *type_str;
    char **enum_values;
    int enum_count;
    char *ref_sheet;
    int is_optional;
} CDBColumnInfo;

typedef struct {
    char *name;
    char **values;
    int count;
} CDBFlags;

CDB *cdb_open(const char *filepath);
void cdb_close(CDB *cdb);
CDBError cdb_get_error(CDB *cdb);
const char *cdb_error_string(CDBError error);

int cdb_get_sheet_count(CDB *cdb);
CDBSheet *cdb_get_sheet(CDB *cdb, int index);
CDBSheet *cdb_get_sheet_by_name(CDB *cdb, const char *name);
const char *cdb_sheet_get_name(CDBSheet *sheet);

int cdb_column_count(CDBSheet *sheet);
CDBColumn *cdb_get_column(CDBSheet *sheet, int index);
CDBColumn *cdb_get_column_by_name(CDBSheet *sheet, const char *name);
const char *cdb_column_get_name(CDBColumn *column);
const char *cdb_column_get_type_str(CDBColumn *column);
CDBColumnType cdb_column_get_type(CDBColumn *column);
int cdb_column_is_optional(CDBColumn *column);
int cdb_column_get_enum_count(CDBColumn *column);
const char *cdb_column_get_enum_value(CDBColumn *column, int index);
const char *cdb_column_get_ref_sheet(CDBColumn *column);
const char **cdb_column_get_enum_values_ptr(CDBColumn *column);

int cdb_row_count(CDBSheet *sheet);
CDBRow *cdb_get_row(CDBSheet *sheet, int index);

const char *cdb_value_get_string(CDBRow *row, int column);
int cdb_value_get_int(CDBRow *row, int column);
double cdb_value_get_float(CDBRow *row, int column);
int cdb_value_get_bool(CDBRow *row, int column);
int cdb_value_is_null(CDBRow *row, int column);
const char *cdb_value_get_raw(CDBRow *row, int column);
int cdb_value_get_type(CDBRow *row, int column);

int cdb_value_get_flags_count(CDBRow *row, int column);
const char *cdb_value_get_flag(CDBRow *row, int column, int index);
int cdb_value_has_flag(CDBRow *row, int column, const char *flag);

const char *cdb_get_type_name(CDBColumnType type);
int cdb_get_type_by_name(const char *name);

#ifdef __cplusplus
}
#endif

#endif /* CDB_READER_H */
