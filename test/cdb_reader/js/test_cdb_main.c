/*
 * CastleDB QuickJS Standalone Test
 */

#include "quickjs.h"
#include "quickjs-libc.h"
#include "cdb_reader.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static JSValue js_cdb_open(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_cdb_get_sheet_count(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_cdb_get_sheet_names(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_cdb_sheet(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_cdb_close(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_sheet_get_name(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_sheet_get_row_count(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_sheet_get_rows(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_row_get(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);
static JSValue js_row_to_object(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv);

static JSClassID js_cdb_class_id = 0;
static JSClassID js_sheet_class_id = 0;
static JSClassID js_row_class_id = 0;

typedef struct {
    CDB *db;
    int sheet_count;
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

static void js_cdb_finalizer(JSRuntime *rt, JSValue val) {
    JCDB *jcdb = JS_GetOpaque(val, js_cdb_class_id);
    if (jcdb) {
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

static JSValue js_sheet_get_row_count(JSContext *ctx, JSValueConst thisVal, int argc, JSValueConst *argv) {
    JSheet *jsheet = JS_GetOpaque(thisVal, js_sheet_class_id);
    if (!jsheet) {
        return JS_EXCEPTION;
    }
    return JS_NewInt32(ctx, jsheet->row_count);
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
        default: {
            const char *raw = cdb_value_get_raw(row, col_index);
            result = JS_NewString(ctx, raw ? raw : "");
            break;
        }
    }

    free(row);
    return result;
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

static JSClassDef js_row_class = {
    .class_name = "Row",
    .finalizer = js_row_finalizer,
};

static const JSCFunctionListEntry js_cdb_funcs[] = {
    JS_CFUNC_DEF("open", 1, js_cdb_open),
    JS_CFUNC_DEF("sheet", 1, js_cdb_sheet),
    JS_CFUNC_DEF("close", 0, js_cdb_close),
    JS_CFUNC_DEF("getSheetCount", 0, js_cdb_get_sheet_count),
    JS_CFUNC_DEF("getSheetNames", 0, js_cdb_get_sheet_names),
};

static const JSCFunctionListEntry js_sheet_funcs[] = {
    JS_CFUNC_DEF("getName", 0, js_sheet_get_name),
    JS_CFUNC_DEF("getRowCount", 0, js_sheet_get_row_count),
    JS_CFUNC_DEF("getRows", 0, js_sheet_get_rows),
};

static const JSCFunctionListEntry js_row_funcs[] = {
    JS_CFUNC_DEF("get", 1, js_row_get),
    JS_CFUNC_DEF("toObject", 0, js_row_to_object),
};

static int js_cdb_init(JSContext *ctx, JSModuleDef *m) {
    JSRuntime *rt = JS_GetRuntime(ctx);
    JSValue proto_cdb, proto_sheet, proto_row;

    JS_NewClassID(rt, &js_cdb_class_id);
    JS_NewClassID(rt, &js_sheet_class_id);
    JS_NewClassID(rt, &js_row_class_id);

    JS_NewClass(rt, js_cdb_class_id, &js_cdb_class);
    JS_NewClass(rt, js_sheet_class_id, &js_sheet_class);
    JS_NewClass(rt, js_row_class_id, &js_row_class);

    proto_cdb = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_cdb, js_cdb_funcs, sizeof(js_cdb_funcs)/sizeof(js_cdb_funcs[0]));
    JS_SetClassProto(ctx, js_cdb_class_id, proto_cdb);

    proto_sheet = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_sheet, js_sheet_funcs, sizeof(js_sheet_funcs)/sizeof(js_sheet_funcs[0]));
    JS_SetClassProto(ctx, js_sheet_class_id, proto_sheet);

    proto_row = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_row, js_row_funcs, sizeof(js_row_funcs)/sizeof(js_row_funcs[0]));
    JS_SetClassProto(ctx, js_row_class_id, proto_row);

    return 0;
}

static JSModuleDef *js_init_module(JSContext *ctx, const char *module_name) {
    JSModuleDef *m;
    m = JS_NewCModule(ctx, module_name, js_cdb_init);
    JS_AddModuleExport(ctx, m, "CDB");
    return m;
}

void js_cdb_addon_register(JSContext *ctx) {
    js_init_module(ctx, "cdb");
}

int main(int argc, char **argv) {
    JSRuntime *rt;
    JSContext *ctx;
    JSValue result, cdb_obj;
    const char *cdb_path;

    if (argc < 2) {
        fprintf(stderr, "Usage: %s <cdb_file>\n", argv[0]);
        return 1;
    }
    cdb_path = argv[1];

    rt = JS_NewRuntime();
    if (!rt) {
        fprintf(stderr, "Failed to create JS runtime\n");
        return 1;
    }

    ctx = JS_NewContext(rt);
    if (!ctx) {
        fprintf(stderr, "Failed to create JS context\n");
        JS_FreeRuntime(rt);
        return 1;
    }

    js_std_add_helpers(ctx, argc, argv);
    js_init_module_std(ctx, "std");
    js_init_module_os(ctx, "os");

    JS_NewClassID(rt, &js_cdb_class_id);
    JS_NewClassID(rt, &js_sheet_class_id);
    JS_NewClassID(rt, &js_row_class_id);

    JS_NewClass(rt, js_cdb_class_id, &js_cdb_class);
    JS_NewClass(rt, js_sheet_class_id, &js_sheet_class);
    JS_NewClass(rt, js_row_class_id, &js_row_class);

    JSValue proto_cdb = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_cdb, js_cdb_funcs, sizeof(js_cdb_funcs)/sizeof(js_cdb_funcs[0]));
    JS_SetClassProto(ctx, js_cdb_class_id, proto_cdb);

    JSValue proto_sheet = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_sheet, js_sheet_funcs, sizeof(js_sheet_funcs)/sizeof(js_sheet_funcs[0]));
    JS_SetClassProto(ctx, js_sheet_class_id, proto_sheet);

    JSValue proto_row = JS_NewObject(ctx);
    JS_SetPropertyFunctionList(ctx, proto_row, js_row_funcs, sizeof(js_row_funcs)/sizeof(js_row_funcs[0]));
    JS_SetClassProto(ctx, js_row_class_id, proto_row);

    cdb_obj = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, cdb_obj, "open", JS_NewCFunction2(ctx, (JSCFunction *)js_cdb_open, "open", 1, JS_CFUNC_generic, 0));
    JS_SetPropertyStr(ctx, cdb_obj, "sheet", JS_NewCFunction2(ctx, (JSCFunction *)js_cdb_sheet, "sheet", 1, JS_CFUNC_generic, 0));
    JS_SetPropertyStr(ctx, cdb_obj, "close", JS_NewCFunction2(ctx, (JSCFunction *)js_cdb_close, "close", 0, JS_CFUNC_generic, 0));
    JS_SetPropertyStr(ctx, cdb_obj, "getSheetCount", JS_NewCFunction2(ctx, (JSCFunction *)js_cdb_get_sheet_count, "getSheetCount", 0, JS_CFUNC_generic, 0));
    JS_SetPropertyStr(ctx, cdb_obj, "getSheetNames", JS_NewCFunction2(ctx, (JSCFunction *)js_cdb_get_sheet_names, "getSheetNames", 0, JS_CFUNC_generic, 0));

    JSValue global_obj = JS_GetGlobalObject(ctx);
    JS_SetPropertyStr(ctx, global_obj, "CDB", cdb_obj);
    JS_FreeValue(ctx, global_obj);

    printf("=== CastleDB QuickJS Test ===\n\n");
    printf("Opening: %s\n", cdb_path);

    const char *script_fmt = 
        "var db = CDB.open('%s');\n"
        "var weapons = db.sheet('武器');\n"
        "var rows = weapons.getRows();\n"
        "console.log('Rows length: ' + rows.length);\n"
        "for (var i = 0; i < rows.length; i++) {\n"
        "    var item = rows[i].toObject();\n"
        "    console.log(item.名稱 + ' - ATK:' + item.物理傷害);\n"
        "}\n"
        "db.close();\n"
        "console.log('Done!');\n";

    char full_script[4096];
    snprintf(full_script, sizeof(full_script), script_fmt, cdb_path);

    result = JS_Eval(ctx, full_script, strlen(full_script), "<test>", 0);
    
    if (JS_IsException(result)) {
        fprintf(stderr, "Script error: ");
        JSValue err = JS_GetException(ctx);
        JSValue err_str = JS_ToString(ctx, err);
        const char *err_msg = JS_ToCString(ctx, err_str);
        fprintf(stderr, "%s\n", err_msg ? err_msg : "unknown error");
        JS_FreeCString(ctx, err_msg);
        JS_FreeValue(ctx, err);
        JS_FreeValue(ctx, result);
        JS_FreeContext(ctx);
        JS_FreeRuntime(rt);
        return 1;
    }

    JS_FreeValue(ctx, result);
    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);

    return 0;
}