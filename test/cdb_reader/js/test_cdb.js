/*
 * CastleDB QuickJS Test Script
 * 
 * Outputs in the same format as the C example.
 */

"use strict";

var CDB, db;

// Helper functions
function print_separator() {
    print("========================================");
}

function padRight(str, len) {
    str = String(str);
    while (str.length < len) str += " ";
    return str.substring(0, len);
}

function getTypeName(type) {
    var names = ["TId", "TString", "TBool", "TInt", "TFloat", "TEnum", "TRef", 
                 "TImage", "TList", "TCustom", "TFlags", "TColor", "TLayer", 
                 "TFile", "TTilePos", "TTileLayer", "TDynamic", "TProperties", 
                 "TGradient", "TCurve", "TGuid", "TPolymorph"];
    return names[type] || "Unknown";
}

function getSheetColumns(sheet) {
    // Use raw API to get column count and iterate
    var cols = [];
    var colCount = sheet.getColumnCount();
    for (var i = 0; i < colCount; i++) {
        cols.push({
            name: sheet.getColumnName(i),
            type: sheet.getColumnType(i),
            typeName: getTypeName(sheet.getColumnType(i)),
            enumValues: sheet.getColumnEnumValues ? sheet.getColumnEnumValues(i) : null,
            optional: sheet.isColumnOptional ? sheet.isColumnOptional(i) : false
        });
    }
    return cols;
}

function print_column_info(sheet, col) {
    var line = "  Column: " + padRight(col.name, 12) + " Type: " + padRight(col.typeName, 10);
    
    if (col.enumValues && col.enumValues.length > 0) {
        line += " Values: [" + col.enumValues.join(", ") + "]";
    }
    
    line += " " + (col.optional ? "(optional)" : "(required)");
    print(line);
}

function print_column_header(col) {
    print(padRight(col.name, 16));
}

function print_sheet(sheet) {
    var cols = getSheetColumns(sheet);
    var rowCount = sheet.getRowCount();
    
    print("");
    print_separator();
    print("Sheet: " + sheet.getName());
    print("Columns: " + cols.length + ", Rows: " + rowCount);
    print_separator();
    
    print("");
    print("--- Column Info ---");
    for (var c = 0; c < cols.length; c++) {
        print_column_info(sheet, cols[c]);
    }
    
    if (rowCount > 0) {
        print("");
        print("--- Data Rows ---");
        
        // Print header
        for (var c = 0; c < cols.length; c++) {
            print_column_header(cols[c]);
        }
        print("");
        
        // Print rows
        var rows = sheet.getRows();
        for (var r = 0; r < rows.length; r++) {
            var row = rows[r];
            for (var c = 0; c < cols.length; c++) {
                var val = row.get(cols[c].name);
                var display;
                
                if (val === null || val === undefined || val === "") {
                    display = "(null)";
                } else if (cols[c].type === 4) { // TFLOAT
                    display = Number(val).toFixed(2);
                } else if (cols[c].type === 2) { // TBOOL
                    display = val ? "true" : "false";
                } else {
                    display = String(val);
                }
                
                print(padRight(display, 16));
            }
            print("");
        }
    }
    
    print_separator();
}

// Main
var filepath = typeof CDB_PATH !== 'undefined' ? CDB_PATH : "item.cdb";

print("CastleDB C Reader Example");
print("Version: 1.0.0");
print("Opening: " + filepath);

db = CDB.open(filepath);
print("Successfully opened CDB file.");
print("Sheets: " + db.getSheetCount());

print("");
print("=== Available Sheets ===");
var sheetNames = db.getSheetNames();
for (var i = 0; i < sheetNames.length; i++) {
    var sheet = db.sheet(sheetNames[i]);
    print("  [" + i + "] " + sheet.getName() + " (columns: " + sheet.getColumnCount() + ", rows: " + sheet.getRowCount() + ")");
}

// Print all sheets
for (var i = 0; i < sheetNames.length; i++) {
    var sheet = db.sheet(sheetNames[i]);
    print_sheet(sheet);
}

// Lookup example
print("");
print("=== Lookup Example ===");
var consumables = db.sheet("消耗品");
if (consumables) {
    print("Found sheet: " + consumables.getName());
    var firstItem = consumables.getRows()[0];
    if (firstItem) {
        var obj = firstItem.toObject();
        print("First item: " + obj.名稱 + " (稀有度: " + obj.稀有度 + ", 價格: " + obj.價格 + ")");
    }
} else {
    print("Sheet '消耗品' not found.");
}

db.close();
print("");
print("CDB file closed successfully.");
