/*
 * CastleDB C Reader Example
 * 
 * Demonstrates how to use the cdb_reader library to read CDB files.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "cdb_reader.h"

static const char *type_names[] = {
    "TId", "TString", "TBool", "TInt", "TFloat",
    "TEnum", "TRef", "TImage", "TList", "TCustom",
    "TFlags", "TColor", "TLayer", "TFile", "TTilePos",
    "TTileLayer", "TDynamic", "TProperties", "TGradient", "TCurve",
    "TGuid", "TPolymorph"
};

static const char *get_type_name(CDBColumnType type) {
    if (type >= 0 && type <= CDB_TPOLYMORPH) {
        return type_names[type];
    }
    return "Unknown";
}

static void print_separator(void) {
    printf("========================================\n");
}

static void print_value(CDBRow *row, int col_idx, CDBColumnType col_type) {
    if (cdb_value_is_null(row, col_idx)) {
        printf("(null)");
        return;
    }
    
    switch (col_type) {
        case CDB_TID:
        case CDB_TSTRING:
        case CDB_TENUM:
        case CDB_TREF:
        case CDB_TIMAGE:
        case CDB_TCUSTOM:
        case CDB_TCOLOR:
        case CDB_TFILE:
        case CDB_TGUID:
            printf("%s", cdb_value_get_string(row, col_idx));
            break;
        case CDB_TINT:
            printf("%d", cdb_value_get_int(row, col_idx));
            break;
        case CDB_TFLOAT:
            printf("%.2f", cdb_value_get_float(row, col_idx));
            break;
        case CDB_TBOOL:
            printf("%s", cdb_value_get_bool(row, col_idx) ? "true" : "false");
            break;
        case CDB_TFLAGS:
            {
                int count = cdb_value_get_flags_count(row, col_idx);
                if (count > 0) {
                    printf("[");
                    for (int i = 0; i < count; i++) {
                        if (i > 0) printf(", ");
                        printf("%s", cdb_value_get_flag(row, col_idx, i));
                    }
                    printf("]");
                } else {
                    printf("%s", cdb_value_get_string(row, col_idx));
                }
            }
            break;
        default:
            printf("%s", cdb_value_get_raw(row, col_idx));
            break;
    }
}

static void print_column_header(CDBColumn *col) {
    const char *name = cdb_column_get_name(col);
    printf("%-16s", name ? name : "(unnamed)");
}

static void print_column_info(CDBColumn *col) {
    const char *name = cdb_column_get_name(col);
    CDBColumnType type = cdb_column_get_type(col);
    
    printf("  Column: %-12s Type: %-10s", 
           name ? name : "(unnamed)",
           get_type_name(type));
    
    if (type == CDB_TENUM || type == CDB_TFLAGS) {
        printf(" Values: [");
        int enum_count = cdb_column_get_enum_count(col);
        for (int i = 0; i < enum_count; i++) {
            if (i > 0) printf(", ");
            printf("%s", cdb_column_get_enum_value(col, i));
        }
        printf("]");
    } else if (type == CDB_TREF) {
        const char *ref = cdb_column_get_ref_sheet(col);
        printf(" Ref: %s", ref ? ref : "(none)");
    }
    
    printf(" %s\n", cdb_column_is_optional(col) ? "(optional)" : "(required)");
}

static void print_sheet(CDBSheet *sheet) {
    printf("\n");
    print_separator();
    const char *sheet_name = cdb_sheet_get_name(sheet);
    printf("Sheet: %s\n", sheet_name ? sheet_name : "(unnamed)");
    printf("Columns: %d, Rows: %d\n", cdb_column_count(sheet), cdb_row_count(sheet));
    print_separator();
    
    printf("\n--- Column Info ---\n");
    for (int c = 0; c < cdb_column_count(sheet); c++) {
        CDBColumn *col = cdb_get_column(sheet, c);
        if (col) {
            print_column_info(col);
        }
    }
    
    if (cdb_row_count(sheet) > 0) {
        printf("\n--- Data Rows ---\n");
        
        for (int c = 0; c < cdb_column_count(sheet); c++) {
            CDBColumn *col = cdb_get_column(sheet, c);
            if (col) {
                print_column_header(col);
            }
        }
        printf("\n");
        
        for (int r = 0; r < cdb_row_count(sheet); r++) {
            CDBRow *row = cdb_get_row(sheet, r);
            if (row) {
                for (int c = 0; c < cdb_column_count(sheet); c++) {
                    CDBColumn *col = cdb_get_column(sheet, c);
                    if (col) {
                        CDBColumnType col_type = cdb_column_get_type(col);
                        print_value(row, c, col_type);
                        printf(" ");
                    }
                }
                printf("\n");
                free(row);
            }
        }
    }
    print_separator();
}

int main(int argc, char *argv[]) {
    const char *filepath = "item.cdb";
    
    if (argc > 1) {
        filepath = argv[1];
    }
    
    printf("CastleDB C Reader Example\n");
    printf("Version: %s\n", CDB_VERSION);
    printf("Opening: %s\n", filepath);
    
    CDB *cdb = cdb_open(filepath);
    if (!cdb) {
        fprintf(stderr, "Error: Failed to open CDB file: %s\n", filepath);
        fprintf(stderr, "Error code: %d\n", cdb_get_error(cdb));
        return 1;
    }
    
    printf("Successfully opened CDB file.\n");
    printf("Sheets: %d\n", cdb_get_sheet_count(cdb));
    
    printf("\n=== Available Sheets ===\n");
    for (int i = 0; i < cdb_get_sheet_count(cdb); i++) {
        CDBSheet *sheet = cdb_get_sheet(cdb, i);
        if (sheet) {
            printf("  [%d] %s (columns: %d, rows: %d)\n", 
                   i, 
                   cdb_sheet_get_name(sheet) ? cdb_sheet_get_name(sheet) : "(unnamed)",
                   cdb_column_count(sheet),
                   cdb_row_count(sheet));
        }
    }
    
    for (int i = 0; i < cdb_get_sheet_count(cdb); i++) {
        CDBSheet *sheet = cdb_get_sheet(cdb, i);
        if (sheet) {
            print_sheet(sheet);
        }
    }
    
    printf("\n=== Lookup Example ===\n");
    CDBSheet *items = cdb_get_sheet_by_name(cdb, "物品");
    if (items) {
        printf("Found sheet: %s\n", cdb_sheet_get_name(items));
        
        CDBColumn *name_col = cdb_get_column_by_name(items, "名稱");
        CDBColumn *price_col = cdb_get_column_by_name(items, "價格");
        CDBColumn *type_col = cdb_get_column_by_name(items, "類型");
        
        if (name_col && price_col && type_col) {
            int name_idx = -1, price_idx = -1, type_idx = -1;
            for (int c = 0; c < cdb_column_count(items); c++) {
                CDBColumn *col = cdb_get_column(items, c);
                if (col) {
                    if (col == name_col) name_idx = c;
                    if (col == price_col) price_idx = c;
                    if (col == type_col) type_idx = c;
                }
            }
            
            if (name_idx >= 0 && price_idx >= 0 && type_idx >= 0) {
                printf("\nItems with price > 100:\n");
                printf("%-20s %-10s %-10s\n", "Name", "Type", "Price");
                printf("---------------------------------------\n");
                
                for (int r = 0; r < cdb_row_count(items); r++) {
                    CDBRow *row = cdb_get_row(items, r);
                    if (row) {
                        int price = cdb_value_get_int(row, price_idx);
                        if (price > 100) {
                            const char *name = cdb_value_get_string(row, name_idx);
                            const char *type = cdb_value_get_string(row, type_idx);
                            printf("%-20s %-10s %-10d\n", 
                                   name ? name : "(null)",
                                   type ? type : "(null)",
                                   price);
                        }
                        free(row);
                    }
                }
            }
        }
    } else {
        printf("Sheet '物品' not found.\n");
    }
    
    cdb_close(cdb);
    printf("\nCDB file closed successfully.\n");
    
    return 0;
}
