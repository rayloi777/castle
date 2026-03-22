/*
 * CastleDB QuickJS Extension
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

#include "quickjs.h"
#include "../cdb_reader.h"

#include <stdlib.h>
#include <string.h>

#ifndef countof
#define countof(x) (sizeof(x) / sizeof((x)[0]))
#endif

typedef struct {
    CDB *db;
    int sheet_count;
    JSValue *sheets;
} JCDB;

typedef struct {
    CDBSheet *sheet;
    JCDB *jcdb;
    int row_count;
} JSheet;

typedef struct {
    JSheet *jsheet;
    int row_index;
} JRow;

typedef struct {
    JSheet *jsheet;
    int col_index;
} JColumn;

static JSClassID js_cdb_class_id = 0;
static JSClassID js_sheet_class_id = 0;
static JSClassID js_column_class_id = 0;
static JSClassID js_row_class_id = 0;

static void js_cdb_finalizer(JSRuntime *rt, JSValue val) {
    JCDB *jcdb = JS_GetOpaque(val, js_cdb_class_id);
    if (jcdb) {
        if (jcdb->sheets) {
            free(jcdb->sheets);
        }
        if (jcdb->db) {
            cdb_close(jcdb->db);
        }
        free(jcdb);
    }
}

static void js_sheet_finalizer(JSRuntime *rt, JSValue val) {
    JSheet *jsheet = JS_GetOpaque(val, js_sheet_class_id);
    if (jsheet) {
        free(jsheet);
    }
}

static void js_column_finalizer(JSRuntime *rt, JSValue val) {
    JColumn *jcol = JS_GetOpaque(val, js_column_class_id);
    if (jcol) {
        free(jcol);
    }
}

static void js_row_finalizer(JSRuntime *rt, JSValue val) {
    JRow *jrow = JS_GetOpaque(val, js_row_class_id);
    if (jrow) {
        free(jrow);
    }
}

static JSValue js_cdb_open(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    const char *filename;
    JCDB *jcdb;
    JSValue obj;

    if (argc < 1) {
        return JS_EXCEPTION;
    }

    filename = JS_ToCString(ctx, argv[0]);
    if (!filename) {
        return JS_EXCEPTION;
    }

    CDB *db = cdb_open(filename);
    JS_FreeCString(ctx, filename);

    if (!db) {
        JS_ThrowReferenceError(ctx, "Failed to open CDB file");
        return JS_EXCEPTION;
    }

    jcdb = calloc(1, sizeof(JCDB));
    if (!jcdb) {
        cdb_close(db);
        return JS_EXCEPTION;
    }

    jcdb->db = db;
    jcdb->sheet_count = cdb_get_sheet_count(db);
    jcdb->sheets = calloc(jcdb->sheet_count, sizeof(JSValue));

    obj = JS_NewObjectClass(ctx, js_cdb_class_id);
    JS_SetOpaque(obj, jcdb);

    return obj;
}

static JSValue js_cdb_get_sheet_count(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JCDB *jcdb = JS_GetOpaque(thisVal, js_cdb_class_id);
    if (!jcdb) {
        return JS_EXCEPTION;
    }
    return JS_NewInt32(ctx, jcdb->sheet_count);
}

static JSValue js_cdb_get_sheet_names(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JCDB *jcdb = JS_GetOpaque(thisVal, js_cdb_class_id);
    if (!jcdb) {
        return JS_EXCEPTION;
    }

    JSValue arr = JS_NewArray(ctx);
    for (int i = 0; i < jcdb->sheet_count; i++) {
        CDBSheet *sheet = cdb_get_sheet(jcdb->db, i);
        if (sheet) {
            const char *name = cdb_sheet_get_name(sheet);
            JS_SetPropertyUint32(ctx, arr, i, JS_NewString(ctx, name ? name : ""));
        }
    }
    return arr;
}

static JSValue js_cdb_sheet(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JCDB *jcdb = JS_GetOpaque(thisVal, js_cdb_class_id);
    const char *name;
    JSValue obj;

    if (!jcdb || argc < 1) {
        return JS_EXCEPTION;
    }

    name = JS_ToCString(ctx, argv[0]);
    if (!name) {
        return JS_EXCEPTION;
    }

    CDBSheet *sheet = cdb_get_sheet_by_name(jcdb->db, name);
    JS_FreeCString(ctx, name);

    if (!sheet) {
        JS_ThrowReferenceError(ctx, "Sheet not found");
        return JS_EXCEPTION;
    }

    JSheet *jsheet = calloc(1, sizeof(JSheet));
    if (!jsheet) {
        return JS_EXCEPTION;
    }
    jsheet->sheet = sheet;
    jsheet->jcdb = jcdb;
    jsheet->row_count = cdb_row_count(sheet);

    obj = JS_NewObjectClass(ctx, js_sheet_class_id);
    JS_SetOpaque(obj, jsheet);

    return obj;
}

static JSValue js_cdb_close(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JCDB *jcdb = JS_GetOpaque(thisVal, js_cdb_class_id);
    if (jcdb) {
        if (jcdb->sheets) {
            free(jcdb->sheets);
            jcdb->sheets = NULL;
        }
        if (jcdb->db) {
            cdb_close(jcdb->db);
            jcdb->db = NULL;
        }
    }
    return JS_UNDEFINED;
}

static JSValue js_sheet_get_name(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }
    const char *name = cdb_sheet_get_name(jsheet->sheet);
    return JS_NewString(ctx, name ? name : "");
}

static JSValue js_sheet_get_columns(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }

    int count = cdb_column_count(jsheet->sheet);
    JSValue arr = JS_NewArray(ctx);

    for (int i = 0; i < count; i++) {
        CDBColumn *col = cdb_get_column(jsheet->sheet, i);
        if (col) {
            JSValue colObj = JS_NewObjectClass(ctx, js_column_class_id);
            JColumn *jcol = calloc(1, sizeof(JColumn));
            jcol->jsheet = jsheet;
            jcol->col_index = i;
            JS_SetOpaque(colObj, jcol);
            JS_SetPropertyUint32(ctx, arr, i, colObj);
        }
    }
    return arr;
}

static JSValue js_sheet_get_row_count(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }
    return JS_NewInt32(ctx, jsheet->row_count);
}

static JSValue js_sheet_get_row(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    int32_t index;
    JSValue obj;

    if (!jsheet || argc < 1) {
        return JS_EXCEPTION;
    }

    if (JS_ToInt32(ctx, &index, argv[0])) {
        return JS_EXCEPTION;
    }

    if (index < 0 || index >= jsheet->row_count) {
        JS_ThrowRangeError(ctx, "Row index out of bounds");
        return JS_EXCEPTION;
    }

    JRow *jrow = calloc(1, sizeof(JRow));
    if (!jrow) {
        return JS_EXCEPTION;
    }
    jrow->jsheet = jsheet;
    jrow->row_index = index;

    obj = JS_NewObjectClass(ctx, js_row_class_id);
    JS_SetOpaque(obj, jrow);

    return obj;
}

static JSValue js_sheet_get_rows(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }

    JSValue arr = JS_NewArray(ctx);
    for (int i = 0; i < jsheet->row_count; i++) {
        JRow *jrow = calloc(1, sizeof(JRow));
        if (!jrow) continue;
        jrow->jsheet = jsheet;
        jrow->row_index = i;

        JSValue rowObj = JS_NewObjectClass(ctx, js_row_class_id);
        JS_SetOpaque(rowObj, jrow);
        JS_SetPropertyUint32(ctx, arr, i, rowObj);
    }
    return arr;
}

static JSValue js_sheet_find(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet || argc < 1) {
        return JS_EXCEPTION;
    }

    JSValue func = argv[0];
    if (!JS_IsFunction(ctx, func)) {
        JS_ThrowTypeError(ctx, "Argument must be a function");
        return JS_EXCEPTION;
    }

    for (int i = 0; i < jsheet->row_count; i++) {
        JRow *jrow = calloc(1, sizeof(JRow));
        if (!jrow) continue;
        jrow->jsheet = jsheet;
        jrow->row_index = i;

        JSValue rowObj = JS_NewObjectClass(ctx, js_row_class_id);
        JS_SetOpaque(rowObj, jrow);

        JSValue result = JS_Call(ctx, func, rowObj, 1, &rowObj);
        JS_FreeValue(ctx, rowObj);

        if (JS_ToBool(ctx, result)) {
            jrow = calloc(1, sizeof(JRow));
            jrow->jsheet = jsheet;
            jrow->row_index = i;
            JSValue foundObj = JS_NewObjectClass(ctx, js_row_class_id);
            JS_SetOpaque(foundObj, jrow);
            return foundObj;
        }
        JS_FreeValue(ctx, result);
    }
    return JS_NULL;
}

static JSValue js_sheet_to_array(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }

    int col_count = cdb_column_count(jsheet->sheet);
    JSValue arr = JS_NewArray(ctx);

    for (int r = 0; r < jsheet->row_count; r++) {
        CDBRow *row = cdb_get_row(jsheet->sheet, r);
        if (!row) continue;

        JSValue rowArr = JS_NewArray(ctx);
        for (int c = 0; c < col_count; c++) {
            CDBColumn *col = cdb_get_column(jsheet->sheet, c);
            CDBColumnType type = cdb_column_get_type(col);
            JSValue val;

            switch (type) {
                case CDB_TINT:
                    val = JS_NewInt32(ctx, cdb_value_get_int(row, c));
                    break;
                case CDB_TFLOAT:
                    val = JS_NewFloat64(ctx, cdb_value_get_float(row, c));
                    break;
                case CDB_TBOOL:
                    val = JS_NewBool(ctx, cdb_value_get_bool(row, c));
                    break;
                case CDB_TID:
                case CDB_TSTRING:
                case CDB_TIMAGE:
                case CDB_TFILE: {
                    const char *str = cdb_value_get_string(row, c);
                    val = JS_NewString(ctx, str ? str : "");
                    break;
                }
                default: {
                    const char *raw = cdb_value_get_raw(row, c);
                    val = JS_NewString(ctx, raw ? raw : "");
                    break;
                }
            }
            JS_SetPropertyUint32(ctx, rowArr, c, val);
        }
        JS_SetPropertyUint32(ctx, arr, r, rowArr);
        free(row);
    }
    return arr;
}

static JSValue js_column_get_name(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JColumn *jcol = JS_GetOpaque(thisVal, js_column_class_id);
    if (!jcol) {
        return JS_EXCEPTION;
    }
    CDBColumn *col = cdb_get_column(jcol->jsheet->sheet, jcol->col_index);
    const char *name = cdb_column_get_name(col);
    return JS_NewString(ctx, name ? name : "");
}

static JSValue js_column_get_type(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JColumn *jcol = JS_GetOpaque(thisVal, js_column_class_id);
    if (!jcol) {
        return JS_EXCEPTION;
    }
    CDBColumn *col = cdb_get_column(jcol->jsheet->sheet, jcol->col_index);
    return JS_NewInt32(ctx, cdb_column_get_type(col));
}

static JSValue js_column_get_type_name(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JColumn *jcol = JS_GetOpaque(thisVal, js_column_class_id);
    if (!jcol) {
        return JS_EXCEPTION;
    }
    CDBColumn *col = cdb_get_column(jcol->jsheet->sheet, jcol->col_index);
    const char *type_name = cdb_get_type_name(cdb_column_get_type(col));
    return JS_NewString(ctx, type_name);
}

static JSValue js_column_get_enum_values(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JColumn *jcol = JS_GetOpaque(thisVal, js_column_class_id);
    if (!jcol) {
        return JS_EXCEPTION;
    }

    CDBColumn *col = cdb_get_column(jcol->jsheet->sheet, jcol->col_index);
    int count = cdb_column_get_enum_count(col);
    JSValue arr = JS_NewArray(ctx);

    for (int i = 0; i < count; i++) {
        const char *val = cdb_column_get_enum_value(col, i);
        JS_SetPropertyUint32(ctx, arr, i, JS_NewString(ctx, val ? val : ""));
    }
    return arr;
}

static JSValue js_column_is_optional(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JColumn *jcol = JS_GetOpaque(thisVal, js_column_class_id);
    if (!jcol) {
        return JS_EXCEPTION;
    }
    CDBColumn *col = cdb_get_column(jcol->jsheet->sheet, jcol->col_index);
    return JS_NewBool(ctx, cdb_column_is_optional(col));
}

static JSValue js_row_get(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JRow *jrow = JS_GetOpaque(thisVal, js_row_class_id);
    const char *col_name;

    if (!jrow || argc < 1) {
        return JS_EXCEPTION;
    }

    col_name = JS_ToCString(ctx, argv[0]);
    if (!col_name) {
        return JS_EXCEPTION;
    }

    CDBSheet *sheet = jrow->jsheet->sheet;
    CDBColumn *col = cdb_get_column_by_name(sheet, col_name);
    JS_FreeCString(ctx, col_name);

    if (!col) {
        JS_ThrowReferenceError(ctx, "Column not found");
        return JS_EXCEPTION;
    }

    int col_index = -1;
    for (int i = 0; i < cdb_column_count(sheet); i++) {
        if (cdb_get_column(sheet, i) == col) {
            col_index = i;
            break;
        }
    }

    if (col_index < 0) {
        return JS_EXCEPTION;
    }

    CDBRow *row = cdb_get_row(sheet, jrow->row_index);
    if (!row) {
        return JS_EXCEPTION;
    }

    CDBColumnType type = cdb_column_get_type(col);
    JSValue result;

    switch (type) {
        case CDB_TINT:
            result = JS_NewInt32(ctx, cdb_value_get_int(row, col_index));
            break;
        case CDB_TFLOAT:
            result = JS_NewFloat64(ctx, cdb_value_get_float(row, col_index));
            break;
        case CDB_TBOOL:
            result = JS_NewBool(ctx, cdb_value_get_bool(row, col_index));
            break;
        case CDB_TID:
        case CDB_TSTRING:
        case CDB_TIMAGE:
        case CDB_TFILE:
        case CDB_TENUM: {
            const char *str = cdb_value_get_string(row, col_index);
            result = JS_NewString(ctx, str ? str : "");
            break;
        }
        case CDB_TFLAGS: {
            int count = cdb_value_get_flags_count(row, col_index);
            JSValue arr = JS_NewArray(ctx);
            for (int i = 0; i < count; i++) {
                const char *flag = cdb_value_get_flag(row, col_index, i);
                JS_SetPropertyUint32(ctx, arr, i, JS_NewString(ctx, flag ? flag : ""));
            }
            result = arr;
            break;
        }
        default: {
            const char *raw = cdb_value_get_raw(row, col_index);
            result = JS_NewString(ctx, raw ? raw : "");
            break;
        }
    }

    free(row);
    return result;
}

static JSValue js_row_get_index(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JRow *jrow = JS_GetOpaque(thisVal, js_row_class_id);
    if (!jrow) {
        return JS_EXCEPTION;
    }
    return JS_NewInt32(ctx, jrow->row_index);
}

static JSValue js_row_has(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JRow *jrow = JS_GetOpaque(thisVal, js_row_class_id);
    const char *col_name;

    if (!jrow || argc < 1) {
        return JS_EXCEPTION;
    }

    col_name = JS_ToCString(ctx, argv[0]);
    if (!col_name) {
        return JS_EXCEPTION;
    }

    CDBSheet *sheet = jrow->jsheet->sheet;
    CDBColumn *col = cdb_get_column_by_name(sheet, col_name);
    JS_FreeCString(ctx, col_name);

    if (!col) {
        return JS_FALSE;
    }

    int col_index = -1;
    for (int i = 0; i < cdb_column_count(sheet); i++) {
        if (cdb_get_column(sheet, i) == col) {
            col_index = i;
            break;
        }
    }

    if (col_index < 0) {
        return JS_FALSE;
    }

    CDBRow *row = cdb_get_row(sheet, jrow->row_index);
    if (!row) {
        return JS_FALSE;
    }

    int is_null = cdb_value_is_null(row, col_index);
    free(row);
    return JS_NewBool(ctx, !is_null);
}

static JSValue js_row_to_object(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JRow *jrow = JS_GetOpaque(thisVal, js_row_class_id);
    if (!jrow) {
        return JS_EXCEPTION;
    }

    CDBSheet *sheet = jrow->jsheet->sheet;
    int col_count = cdb_column_count(sheet);
    JSValue obj = JS_NewObject(ctx);

    CDBRow *row = cdb_get_row(sheet, jrow->row_index);
    if (!row) {
        return obj;
    }

    for (int c = 0; c < col_count; c++) {
        CDBColumn *col = cdb_get_column(sheet, c);
        const char *col_name = cdb_column_get_name(col);
        if (!col_name) continue;

        CDBColumnType type = cdb_column_get_type(col);
        JSValue val;

        switch (type) {
            case CDB_TINT:
                val = JS_NewInt32(ctx, cdb_value_get_int(row, c));
                break;
            case CDB_TFLOAT:
                val = JS_NewFloat64(ctx, cdb_value_get_float(row, c));
                break;
            case CDB_TBOOL:
                val = JS_NewBool(ctx, cdb_value_get_bool(row, c));
                break;
            case CDB_TID:
            case CDB_TSTRING:
            case CDB_TIMAGE:
            case CDB_TFILE:
            case CDB_TENUM: {
                const char *str = cdb_value_get_string(row, c);
                val = JS_NewString(ctx, str ? str : "");
                break;
            }
            default: {
                const char *raw = cdb_value_get_raw(row, c);
                val = JS_NewString(ctx, raw ? raw : "");
                break;
            }
        }
        JS_SetPropertyStr(ctx, obj, col_name, val);
    }

    free(row);
    return obj;
}

static JSClassDef js_cdb_class = {
    .class_name = "CDB",
    .finalizer = js_cdb_finalizer,
};

static JSClassDef js_sheet_class = {
    .class_name = "Sheet",
    .finalizer = js_sheet_finalizer,
};

static JSClassDef js_column_class = {
    .class_name = "Column",
    .finalizer = js_column_finalizer,
};

static JSClassDef js_row_class = {
    .class_name = "Row",
    .finalizer = js_row_finalizer,
};

static const JSCFunctionListEntry js_cdb_funcs[] = {
    JS_CFUNC_DEF("open", 1, js_cdb_open),
    JS_CFUNC_DEF("sheet", 1, js_cdb_sheet),
    JS_CFUNC_DEF("close", 0, js_cdb_close),
    JS_CFUNC_DEF("getSheetNames", 0, js_cdb_get_sheet_names),
    JS_CFUNC_DEF("getSheetCount", 0, js_cdb_get_sheet_count),
};

static const JSCFunctionListEntry js_sheet_funcs[] = {
    JS_CFUNC_DEF("getName", 0, js_sheet_get_name),
    JS_CFUNC_DEF("getColumns", 0, js_sheet_get_columns),
    JS_CFUNC_DEF("getRowCount", 0, js_sheet_get_row_count),
    JS_CFUNC_DEF("getRow", 1, js_sheet_get_row),
    JS_CFUNC_DEF("getRows", 0, js_sheet_get_rows),
    JS_CFUNC_DEF("find", 1, js_sheet_find),
    JS_CFUNC_DEF("toArray", 0, js_sheet_to_array),
};

static const JSCFunctionListEntry js_column_funcs[] = {
    JS_CFUNC_DEF("getName", 0, js_column_get_name),
    JS_CFUNC_DEF("getType", 0, js_column_get_type),
    JS_CFUNC_DEF("getTypeName", 0, js_column_get_type_name),
    JS_CFUNC_DEF("getEnumValues", 0, js_column_get_enum_values),
    JS_CFUNC_DEF("isOptional", 0, js_column_is_optional),
};

static const JSCFunctionListEntry js_row_funcs[] = {
    JS_CFUNC_DEF("get", 1, js_row_get),
    JS_CFUNC_DEF("has", 1, js_row_has),
    JS_CFUNC_DEF("toObject", 0, js_row_to_object),
    JS_CFUNC_DEF("getIndex", 0, js_row_get_index),
};

static int js_cdb_init(JSContext *ctx, JSModuleDef *m) {
    JSValue proto_cdb, proto_sheet, proto_column, proto_row;

    JS_NewClassID(&js_cdb_class_id);
    JS_NewClassID(&js_sheet_class_id);
    JS_NewClassID(&js_column_class_id);
    JS_NewClassID(&js_row_class_id);

    JS_NewClass(JS_GetRuntime(ctx), js_cdb_class_id, &js_cdb_class);
    JS_NewClass(JS_GetRuntime(ctx), js_sheet_class_id, &js_sheet_class);
    JS_NewClass(JS_GetRuntime(ctx), js_column_class_id, &js_column_class);
    JS_NewClass(JS_GetRuntime(ctx), js_row_class_id, &js_row_class);

    proto_cdb = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_cdb, js_cdb_funcs, countof(js_cdb_funcs));
    JS_SetClassProto(ctx, js_cdb_class_id, proto_cdb);

    proto_sheet = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_sheet, js_sheet_funcs, countof(js_sheet_funcs));
    JS_SetClassProto(ctx, js_sheet_class_id, proto_sheet);

    proto_column = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_column, js_column_funcs, countof(js_column_funcs));
    JS_SetClassProto(ctx, js_column_class_id, proto_column);

    proto_row = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_row, js_row_funcs, countof(js_row_funcs));
    JS_SetClassProto(ctx, js_row_class_id, proto_row);

    JSValue obj = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, obj, js_cdb_funcs, countof(js_cdb_funcs));
    JS_AddModuleExport(ctx, m, "CDB");
    JS_SetModuleExport(ctx, m, "CDB", obj);

    return 0;
}

static JSModuleDef *js_init_module(JSContext *ctx, const char *module_name) {
    JSModuleDef *m;
    m = JS_NewCModule(ctx, module_name, js_cdb_init);
    return m;
}

void js_cdb_addon_register(JSContext *ctx) {
    js_init_module(ctx, "cdb");
}

#ifdef __cplusplus
extern "C" {
#endif

__attribute__((visibility("default")))
void js_addon_cdb_init(JSContext *ctx) {
    js_cdb_addon_register(ctx);
}

#ifdef __cplusplus
}
#endif
