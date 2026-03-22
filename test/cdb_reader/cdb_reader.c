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

#include "cdb_reader.h"
#include "jsmn/jsmn.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define CDB_INITIAL_TOKEN_COUNT 4096
#define CDB_MAX_STRING_LENGTH 4096

struct CDBColumn {
    char *name;
    CDBColumnType type;
    char *type_str;
    char **enum_values;
    int enum_count;
    char *ref_sheet;
    int is_optional;
    int *line_indices;
    int line_count;
};

struct CDBSheet {
    char *name;
    CDBColumn *columns;
    int column_count;
    char ***lines;
    int line_count;
};

struct CDBRow {
    CDBSheet *sheet;
    int row_index;
};

struct CDB {
    CDBError error;
    char *json_data;
    int json_length;
    jsmn_parser parser;
    jsmntok_t *tokens;
    int token_count;
    int token_capacity;
    CDBSheet *sheets;
    int sheet_count;
};

static const char *type_names[] = {
    "TId", "TString", "TBool", "TInt", "TFloat",
    "TEnum", "TRef", "TImage", "TList", "TCustom",
    "TFlags", "TColor", "TLayer", "TFile", "TTilePos",
    "TTileLayer", "TDynamic", "TProperties", "TGradient", "TCurve",
    "TGuid", "TPolymorph"
};

static const char *error_strings[] = {
    "OK",
    "File not found",
    "File read error",
    "JSON parse error",
    "Invalid JSON",
    "Invalid CDB file",
    "Sheet not found",
    "Column not found",
    "Row not found",
    "Type mismatch",
    "Out of memory"
};

const char *cdb_error_string(CDBError error) {
    if (error >= CDB_ERROR_FILE_NOT_FOUND && error <= CDB_ERROR_OUT_OF_MEMORY) {
        return error_strings[-error];
    }
    return "Unknown error";
}

static int parse_type_string(const char *type_str, CDBColumnType *type, char **extra) {
    char buffer[256];
    char *colon_pos;
    size_t len = strlen(type_str);
    
    if (len >= sizeof(buffer)) return -1;
    strcpy(buffer, type_str);
    
    *type = (CDBColumnType)atoi(buffer);
    
    colon_pos = strchr(buffer, ':');
    if (colon_pos && extra) {
        *colon_pos = '\0';
        *extra = strdup(colon_pos + 1);
    }
    
    return 0;
}

static int parse_enum_values(const char *enum_str, char ***values, int *count) {
    char buffer[1024];
    char *token;
    char *saveptr;
    int capacity = 4;
    int cnt = 0;
    
    *values = (char**)malloc(sizeof(char*) * capacity);
    if (!*values) return -1;
    
    strncpy(buffer, enum_str, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    
    token = strtok_r(buffer, ",", &saveptr);
    while (token) {
        while (*token == ' ' || *token == '\t') token++;
        
        if (cnt >= capacity) {
            capacity *= 2;
            char **new_values = (char**)realloc(*values, sizeof(char*) * capacity);
            if (!new_values) {
                for (int i = 0; i < cnt; i++) free((*values)[i]);
                free(*values);
                return -1;
            }
            *values = new_values;
        }
        
        (*values)[cnt] = strdup(token);
        cnt++;
        token = strtok_r(NULL, ",", &saveptr);
    }
    
    *count = cnt;
    return 0;
}

static char *copy_token_string(const char *json, jsmntok_t *tok) {
    if (!tok || tok->start < 0 || tok->end < 0 || tok->end <= tok->start) return NULL;
    if (tok->end - tok->start >= CDB_MAX_STRING_LENGTH) return NULL;
    
    char *result = (char*)malloc(tok->end - tok->start + 1);
    if (!result) return NULL;
    
    memcpy(result, json + tok->start, tok->end - tok->start);
    result[tok->end - tok->start] = '\0';
    
    return result;
}

static int is_string_true(const char *str) {
    return strcmp(str, "true") == 0 || strcmp(str, "1") == 0;
}

static int ensure_token_capacity(CDB *cdb, int needed) {
    if (needed < cdb->token_capacity) return 0;
    
    int new_capacity = cdb->token_capacity == 0 ? CDB_INITIAL_TOKEN_COUNT : cdb->token_capacity * 2;
    while (new_capacity < needed) new_capacity *= 2;
    
    jsmntok_t *new_tokens = (jsmntok_t*)realloc(cdb->tokens, sizeof(jsmntok_t) * new_capacity);
    if (!new_tokens) return -1;
    
    cdb->tokens = new_tokens;
    cdb->token_capacity = new_capacity;
    return 0;
}

static int skip_to_end(int idx, jsmntok_t *tokens) {
    jsmntok_t *tok = &tokens[idx];
    if (tok->type == JSMN_OBJECT) {
        int end = idx + 1;
        for (int i = 0; i < tok->size; i++) {
            end++; // skip key
            if (tokens[end].type == JSMN_OBJECT || tokens[end].type == JSMN_ARRAY) {
                end = skip_to_end(end, tokens); // recursed, already past value
            } else {
                end++; // skip primitive value
            }
        }
        return end;
    } else if (tok->type == JSMN_ARRAY) {
        int end = idx + 1;
        for (int i = 0; i < tok->size; i++) {
            if (tokens[end].type == JSMN_OBJECT || tokens[end].type == JSMN_ARRAY) {
                end = skip_to_end(end, tokens);
            } else {
                end++;
            }
        }
        return end;
    }
    return idx + 1;
}

static int find_key_in_object(CDB *cdb, int obj_idx, const char *key) {
    jsmntok_t *obj = &cdb->tokens[obj_idx];
    if (obj->type != JSMN_OBJECT) return -1;
    
    int idx = obj_idx + 1;
    for (int i = 0; i < obj->size; i++) {
        if (cdb->tokens[idx].type == JSMN_STRING) {
            char *tok_str = copy_token_string(cdb->json_data, &cdb->tokens[idx]);
            if (tok_str && strcmp(tok_str, key) == 0) {
                free(tok_str);
                return idx + 1;
            }
            if (tok_str) free(tok_str);
        }
        idx++;
        if (idx >= cdb->token_count) break;
        if (cdb->tokens[idx].type == JSMN_OBJECT || cdb->tokens[idx].type == JSMN_ARRAY) {
            idx = skip_to_end(idx, cdb->tokens);
        } else {
            idx++;
        }
    }
    return -1;
}

static int parse_columns(CDB *cdb, CDBSheet *sheet, int columns_idx) {
    jsmntok_t *columns_tok = &cdb->tokens[columns_idx];
    if (columns_tok->type != JSMN_ARRAY) return -1;
    
    sheet->column_count = columns_tok->size;
    sheet->columns = (CDBColumn*)calloc(sheet->column_count, sizeof(CDBColumn));
    if (!sheet->columns) return -1;
    
    int idx = columns_idx + 1;
    for (int c = 0; c < sheet->column_count; c++) {
        jsmntok_t *col_tok = &cdb->tokens[idx];
        if (col_tok->type != JSMN_OBJECT) {
            idx = skip_to_end(idx, cdb->tokens);
            continue;
        }
        
        CDBColumn *col = &sheet->columns[c];
        col->line_count = 0;
        col->line_indices = NULL;
        
        int name_val_idx = find_key_in_object(cdb, idx, "name");
        if (name_val_idx >= 0) {
            col->name = copy_token_string(cdb->json_data, &cdb->tokens[name_val_idx]);
        }
        
        int type_val_idx = find_key_in_object(cdb, idx, "typeStr");
        if (type_val_idx >= 0) {
            col->type_str = copy_token_string(cdb->json_data, &cdb->tokens[type_val_idx]);
            if (col->type_str) {
                char *extra = NULL;
                parse_type_string(col->type_str, &col->type, &extra);
                
                if (extra) {
                    if (col->type == CDB_TENUM || col->type == CDB_TFLAGS) {
                        parse_enum_values(extra, &col->enum_values, &col->enum_count);
                    } else if (col->type == CDB_TREF) {
                        col->ref_sheet = strdup(extra);
                    }
                    free(extra);
                }
            }
        }
        
        int opt_val_idx = find_key_in_object(cdb, idx, "opt");
        if (opt_val_idx >= 0) {
            char *opt_str = copy_token_string(cdb->json_data, &cdb->tokens[opt_val_idx]);
            if (opt_str) {
                col->is_optional = is_string_true(opt_str);
                free(opt_str);
            }
        }
        
        idx = skip_to_end(idx, cdb->tokens);
    }
    
    return 0;
}

static int parse_lines(CDB *cdb, CDBSheet *sheet, int lines_idx) {
    jsmntok_t *lines_tok = &cdb->tokens[lines_idx];
    if (lines_tok->type != JSMN_ARRAY) return -1;
    
    sheet->line_count = lines_tok->size;
    if (sheet->line_count == 0) return 0;
    
    for (int c = 0; c < sheet->column_count; c++) {
        sheet->columns[c].line_indices = (int*)malloc(sizeof(int) * sheet->line_count);
        if (!sheet->columns[c].line_indices) return -1;
        for (int l = 0; l < sheet->line_count; l++) {
            sheet->columns[c].line_indices[l] = -1;
        }
    }
    
    sheet->lines = (char***)calloc(sheet->line_count, sizeof(char**));
    if (!sheet->lines) return -1;
    
    int idx = lines_idx + 1;
    for (int l = 0; l < sheet->line_count; l++) {
        jsmntok_t *line_tok = &cdb->tokens[idx];
        if (line_tok->type != JSMN_OBJECT) {
            idx = skip_to_end(idx, cdb->tokens) + 1;
            continue;
        }
        
        sheet->lines[l] = (char**)calloc(sheet->column_count, sizeof(char*));
        if (!sheet->lines[l]) {
            idx = skip_to_end(idx, cdb->tokens) + 1;
            continue;
        }
        
        for (int c = 0; c < sheet->column_count; c++) {
            int val_idx = find_key_in_object(cdb, idx, sheet->columns[c].name);
            if (val_idx >= 0) {
                sheet->lines[l][c] = copy_token_string(cdb->json_data, &cdb->tokens[val_idx]);
                sheet->columns[c].line_indices[l] = val_idx;
            }
        }
        
        idx = skip_to_end(idx, cdb->tokens);
    }
    
    return 0;
}

static int parse_cdb_structure(CDB *cdb) {
    if (cdb->token_count < 1) return -1;
    if (cdb->tokens[0].type != JSMN_OBJECT) return -1;
    
    int sheets_idx = find_key_in_object(cdb, 0, "sheets");
    if (sheets_idx < 0) return -1;
    
    jsmntok_t *sheets_tok = &cdb->tokens[sheets_idx];
    cdb->sheet_count = sheets_tok->size;
    cdb->sheets = (CDBSheet*)calloc(cdb->sheet_count, sizeof(CDBSheet));
    if (!cdb->sheets) return -1;
    
    int idx = sheets_idx + 1;
    for (int s = 0; s < cdb->sheet_count; s++) {
        jsmntok_t *sheet_tok = &cdb->tokens[idx];
        
        if (sheet_tok->type != JSMN_OBJECT) {
            idx = skip_to_end(idx, cdb->tokens);
            s--;
            continue;
        }
        
        CDBSheet *sheet = &cdb->sheets[s];
        sheet->columns = NULL;
        sheet->column_count = 0;
        sheet->lines = NULL;
        sheet->line_count = 0;
        
        int name_val_idx = find_key_in_object(cdb, idx, "name");
        if (name_val_idx >= 0) {
            sheet->name = copy_token_string(cdb->json_data, &cdb->tokens[name_val_idx]);
        }
        
        int columns_val_idx = find_key_in_object(cdb, idx, "columns");
        if (columns_val_idx >= 0) {
            parse_columns(cdb, sheet, columns_val_idx);
        }
        
        int lines_val_idx = find_key_in_object(cdb, idx, "lines");
        if (lines_val_idx >= 0) {
            parse_lines(cdb, sheet, lines_val_idx);
        }
        
        idx = skip_to_end(idx, cdb->tokens);
    }
    
    return 0;
}

CDB *cdb_open(const char *filepath) {
    CDB *cdb = (CDB*)calloc(1, sizeof(CDB));
    if (!cdb) return NULL;
    
    cdb->error = CDB_OK;
    cdb->json_data = NULL;
    cdb->tokens = NULL;
    cdb->token_count = 0;
    cdb->token_capacity = 0;
    cdb->sheets = NULL;
    cdb->sheet_count = 0;
    
    FILE *f = fopen(filepath, "rb");
    if (!f) {
        cdb->error = CDB_ERROR_FILE_NOT_FOUND;
        cdb_close(cdb);
        return NULL;
    }
    
    fseek(f, 0, SEEK_END);
    cdb->json_length = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    if (cdb->json_length <= 0) {
        fclose(f);
        cdb->error = CDB_ERROR_FILE_READ;
        cdb_close(cdb);
        return NULL;
    }
    
    cdb->json_data = (char*)malloc(cdb->json_length + 1);
    if (!cdb->json_data) {
        fclose(f);
        cdb->error = CDB_ERROR_OUT_OF_MEMORY;
        cdb_close(cdb);
        return NULL;
    }
    
    size_t read_len = fread(cdb->json_data, 1, cdb->json_length, f);
    fclose(f);
    
    if (read_len != (size_t)cdb->json_length) {
        cdb->error = CDB_ERROR_FILE_READ;
        cdb_close(cdb);
        return NULL;
    }
    
    cdb->json_data[cdb->json_length] = '\0';
    
    jsmn_init(&cdb->parser);
    
    cdb->token_capacity = CDB_INITIAL_TOKEN_COUNT;
    cdb->tokens = (jsmntok_t*)malloc(sizeof(jsmntok_t) * cdb->token_capacity);
    if (!cdb->tokens) {
        cdb->error = CDB_ERROR_OUT_OF_MEMORY;
        cdb_close(cdb);
        return NULL;
    }
    
    int r;
    while ((r = jsmn_parse(&cdb->parser, cdb->json_data, cdb->json_length, cdb->tokens, cdb->token_capacity)) == JSMN_ERROR_NOMEM) {
        if (ensure_token_capacity(cdb, cdb->token_capacity * 2) < 0) {
            cdb->error = CDB_ERROR_OUT_OF_MEMORY;
            cdb_close(cdb);
            return NULL;
        }
    }
    
    if (r < 0) {
        cdb->error = CDB_ERROR_JSON_PARSE;
        cdb_close(cdb);
        return NULL;
    }
    
    cdb->token_count = r;
    
    if (parse_cdb_structure(cdb) < 0) {
        cdb->error = CDB_ERROR_INVALID_CDB;
        cdb_close(cdb);
        return NULL;
    }
    
    return cdb;
}

void cdb_close(CDB *cdb) {
    if (!cdb) return;
    
    if (cdb->sheets) {
        for (int s = 0; s < cdb->sheet_count; s++) {
            CDBSheet *sheet = &cdb->sheets[s];
            if (sheet->name) free(sheet->name);
            
            if (sheet->columns) {
                for (int c = 0; c < sheet->column_count; c++) {
                    CDBColumn *col = &sheet->columns[c];
                    if (col->name) free(col->name);
                    if (col->type_str) free(col->type_str);
                    if (col->enum_values) {
                        for (int e = 0; e < col->enum_count; e++) {
                            free(col->enum_values[e]);
                        }
                        free(col->enum_values);
                    }
                    if (col->ref_sheet) free(col->ref_sheet);
                    if (col->line_indices) free(col->line_indices);
                }
                free(sheet->columns);
            }
            
            if (sheet->lines) {
                for (int l = 0; l < sheet->line_count; l++) {
                    if (sheet->lines[l]) {
                        for (int c = 0; c < sheet->column_count; c++) {
                            if (sheet->lines[l][c]) free(sheet->lines[l][c]);
                        }
                        free(sheet->lines[l]);
                    }
                }
                free(sheet->lines);
            }
        }
        free(cdb->sheets);
    }
    
    if (cdb->tokens) free(cdb->tokens);
    if (cdb->json_data) free(cdb->json_data);
    
    free(cdb);
}

CDBError cdb_get_error(CDB *cdb) {
    return cdb->error;
}

int cdb_get_sheet_count(CDB *cdb) {
    if (!cdb) return 0;
    return cdb->sheet_count;
}

CDBSheet *cdb_get_sheet(CDB *cdb, int index) {
    if (!cdb || index < 0 || index >= cdb->sheet_count) return NULL;
    return &cdb->sheets[index];
}

CDBSheet *cdb_get_sheet_by_name(CDB *cdb, const char *name) {
    if (!cdb || !name) return NULL;
    for (int i = 0; i < cdb->sheet_count; i++) {
        if (cdb->sheets[i].name && strcmp(cdb->sheets[i].name, name) == 0) {
            return &cdb->sheets[i];
        }
    }
    return NULL;
}

const char *cdb_sheet_get_name(CDBSheet *sheet) {
    if (!sheet) return NULL;
    return sheet->name;
}

int cdb_column_count(CDBSheet *sheet) {
    if (!sheet) return 0;
    return sheet->column_count;
}

CDBColumn *cdb_get_column(CDBSheet *sheet, int index) {
    if (!sheet || index < 0 || index >= sheet->column_count) return NULL;
    return &sheet->columns[index];
}

CDBColumn *cdb_get_column_by_name(CDBSheet *sheet, const char *name) {
    if (!sheet || !name) return NULL;
    for (int i = 0; i < sheet->column_count; i++) {
        if (sheet->columns[i].name && strcmp(sheet->columns[i].name, name) == 0) {
            return &sheet->columns[i];
        }
    }
    return NULL;
}

const char *cdb_column_get_name(CDBColumn *column) {
    if (!column) return NULL;
    return column->name;
}

const char *cdb_column_get_type_str(CDBColumn *column) {
    if (!column) return NULL;
    return column->type_str;
}

CDBColumnType cdb_column_get_type(CDBColumn *column) {
    if (!column) return CDB_TSTRING;
    return column->type;
}

int cdb_column_is_optional(CDBColumn *column) {
    if (!column) return 0;
    return column->is_optional;
}

int cdb_column_get_enum_count(CDBColumn *column) {
    if (!column) return 0;
    return column->enum_count;
}

const char *cdb_column_get_enum_value(CDBColumn *column, int index) {
    if (!column || index < 0 || index >= column->enum_count) return NULL;
    return column->enum_values[index];
}

const char *cdb_column_get_ref_sheet(CDBColumn *column) {
    if (!column) return NULL;
    return column->ref_sheet;
}

const char **cdb_column_get_enum_values_ptr(CDBColumn *column) {
    if (!column) return NULL;
    return (const char**)column->enum_values;
}

int cdb_row_count(CDBSheet *sheet) {
    if (!sheet) return 0;
    return sheet->line_count;
}

CDBRow *cdb_get_row(CDBSheet *sheet, int index) {
    if (!sheet || index < 0 || index >= sheet->line_count) return NULL;
    CDBRow *row = (CDBRow*)malloc(sizeof(CDBRow));
    if (!row) return NULL;
    row->sheet = sheet;
    row->row_index = index;
    return row;
}

void cdb_row_free(CDBRow *row) {
    free(row);
}

const char *cdb_value_get_string(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return NULL;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return NULL;
    return val;
}

int cdb_value_get_int(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 0;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return 0;
    return atoi(val);
}

double cdb_value_get_float(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 0.0;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return 0.0;
    return atof(val);
}

int cdb_value_get_bool(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 0;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val) return 0;
    return is_string_true(val);
}

int cdb_value_is_null(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 1;
    char *val = row->sheet->lines[row->row_index][column];
    return (val == NULL || strlen(val) == 0);
}

const char *cdb_value_get_raw(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return NULL;
    return row->sheet->lines[row->row_index][column];
}

int cdb_value_get_type(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return CDB_TSTRING;
    return row->sheet->columns[column].type;
}

static int count_flags_in_string(const char *flags_str) {
    if (!flags_str || strlen(flags_str) == 0) return 0;
    int count = 1;
    for (const char *p = flags_str; *p; p++) {
        if (*p == ',') count++;
    }
    return count;
}

int cdb_value_get_flags_count(CDBRow *row, int column) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 0;
    if (row->sheet->columns[column].type != CDB_TFLAGS) return 0;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return 0;
    return count_flags_in_string(val);
}

const char *cdb_value_get_flag(CDBRow *row, int column, int index) {
    if (!row || column < 0 || column >= row->sheet->column_count) return NULL;
    if (row->sheet->columns[column].type != CDB_TFLAGS) return NULL;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return NULL;
    
    int count = count_flags_in_string(val);
    if (index < 0 || index >= count) return NULL;
    
    static char buffer[256];
    strncpy(buffer, val, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    
    char *token;
    char *saveptr;
    int i = 0;
    token = strtok_r(buffer, ",", &saveptr);
    while (token != NULL) {
        while (*token == ' ' || *token == '\t') token++;
        if (i == index) {
            size_t len = strlen(token);
            if (len > 0 && token[len - 1] == ' ') {
                token[len - 1] = '\0';
            }
            return token;
        }
        i++;
        token = strtok_r(NULL, ",", &saveptr);
    }
    return NULL;
}

int cdb_value_has_flag(CDBRow *row, int column, const char *flag) {
    if (!row || column < 0 || column >= row->sheet->column_count) return 0;
    if (row->sheet->columns[column].type != CDB_TFLAGS) return 0;
    if (!flag) return 0;
    char *val = row->sheet->lines[row->row_index][column];
    if (!val || strlen(val) == 0) return 0;
    
    static char buffer[256];
    strncpy(buffer, val, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    
    char *token;
    char *saveptr;
    token = strtok_r(buffer, ",", &saveptr);
    while (token != NULL) {
        while (*token == ' ' || *token == '\t') token++;
        size_t len = strlen(token);
        if (len > 0 && token[len - 1] == ' ') {
            token[len - 1] = '\0';
        }
        if (strcmp(token, flag) == 0) {
            return 1;
        }
        token = strtok_r(NULL, ",", &saveptr);
    }
    return 0;
}

const char *cdb_get_type_name(CDBColumnType type) {
    if (type >= 0 && type <= CDB_TPOLYMORPH) {
        return type_names[type];
    }
    return "Unknown";
}

int cdb_get_type_by_name(const char *name) {
    if (!name) return -1;
    for (int i = 0; i <= CDB_TPOLYMORPH; i++) {
        if (strcmp(type_names[i], name) == 0) {
            return i;
        }
    }
    return -1;
}
