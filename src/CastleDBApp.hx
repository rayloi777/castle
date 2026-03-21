/*
 * CastleDB Browser Application
 * Full-featured browser-compatible version with all bug fixes and features
 */

import cdb.Database;
import cdb.Data;
import cdb.Sheet;
import cdb.Types.Guid;

@:expose
class CastleDBApp {
    
    static var db: Database;
    static var currentSheet: String;
    static var selectedRow: Int = -1;
    static var selectedCol: Int = -1;
    static var history: Array<{d: String, o: String, sheet: String, filter: String}> = [];
    static var historyIndex: Int = -1;
    static var clipboard: Dynamic = null;
    static var currentFilter: String = null;
    static var currentFileName: String = null;
    static var subSheetData: {sheetName: String, rowIndex: Int, colIndex: Int, subSheet: Sheet, parentSheet: Sheet, parentRow: Dynamic} = null;
    static var imageBank: Map<String, String> = new Map();
    
    public static function init() {
        js.Syntax.code('
        document.addEventListener("keydown", function(e) {
            if (e.ctrlKey || e.metaKey) {
                switch(e.key) {
                    case "s": e.preventDefault(); if(typeof saveFile === "function") saveFile(); break;
                    case "z": e.preventDefault(); CastleDBApp.undo(); break;
                    case "y": e.preventDefault(); CastleDBApp.redo(); break;
                    case "f": e.preventDefault(); document.getElementById("search-input").focus(); break;
                    case "c": if (!window.getSelection().toString()) CastleDBApp.copyRow(selectedRow); break;
                    case "v": if (!window.getSelection().toString()) CastleDBApp.pasteRow(selectedRow); break;
                }
            }
            if (e.key === "Delete" && selectedRow >= 0 && !window.getSelection().toString()) {
                e.preventDefault();
                CastleDBApp.deleteRow(selectedRow);
            }
            if (e.key === "Escape") {
                CastleDBApp.clearSelection();
            }
        });
        ');
    }
    
    // ==================== Selection ====================
    
    @:expose
    public static function clearSelection(): Void {
        selectedRow = -1;
        selectedCol = -1;
        js.Syntax.code("$('#table-body tr').removeClass('selected');");
        js.Syntax.code("$('.context-menu').hide();");
        closeModalIfOpen();
    }
    
    static function closeModalIfOpen(): Void {
        js.Syntax.code("if ($('#modal-container').html()) { closeModal(); }");
    }
    
    // ==================== File Operations ====================
    
    public static function loadCDB(content: String): Void {
        try {
            db = new Database();
            db.load(content);
            currentSheet = db.sheets.length > 0 ? db.sheets[0].name : null;
            history = [];
            historyIndex = -1;
            currentFilter = null;
            loadImageBank();
            saveState();
            renderUI();
        } catch(e: Dynamic) {
            trace("Error loading CDB: " + e);
            js.Syntax.code("console.error(e && e.stack || e)");
            throw e;
        }
    }
    
    public static function getDatabase(): Database {
        return db;
    }
    
    public static function getCurrentSheet(): Sheet {
        if (db == null || currentSheet == null) return null;
        return db.getSheet(currentSheet);
    }
    
    @:expose
    public static function getSheetInfo(): {rowCount: Int, colCount: Int} {
        var sheet = getCurrentSheet();
        if (sheet == null) return {rowCount: 0, colCount: 0};
        var lines = sheet.lines;
        var cols = sheet.columns;
        return {rowCount: lines != null ? lines.length : 0, colCount: cols != null ? cols.length : 0};
    }
    
    @:expose
    public static function getCurrentSheetName(): String {
        return currentSheet;
    }
    
    public static function setCurrentSheet(name: String): Void {
        currentSheet = name;
        currentFilter = null;
        selectedRow = -1;
        selectedCol = -1;
        renderUI();
    }
    
    public static function createNewDatabase(): Void {
        db = new Database();
        db.createSheet("Sheet1");
        currentSheet = "Sheet1";
        history = [];
        historyIndex = -1;
        currentFilter = null;
        saveState();
        renderUI();
    }
    
    public static function getCDBContent(): String {
        if (db == null) return null;
        return db.save();
    }
    
    // ==================== Undo/Redo ====================
    
    public static function saveState(): Void {
        var sdata = {
            d: db.save(),
            o: haxe.Serializer.run(getOpenedState()),
            sheet: currentSheet,
            filter: currentFilter
        };
        if (historyIndex < history.length - 1) {
            history = history.slice(0, historyIndex + 1);
        }
        history.push(sdata);
        historyIndex = history.length - 1;
        if (history.length > 100) {
            history.shift();
            historyIndex--;
        }
    }
    
    static function getOpenedState(): Dynamic {
        var opened: Dynamic = {};
        for (sheet in db.sheets) {
            Reflect.setField(opened, sheet.name, true);
        }
        return opened;
    }
    
    @:expose
    public static function undo(): Void {
        if (historyIndex > 0) {
            historyIndex--;
            restoreState(history[historyIndex]);
        }
    }
    
    @:expose
    public static function redo(): Void {
        if (historyIndex < history.length - 1) {
            historyIndex++;
            restoreState(history[historyIndex]);
        }
    }
    
    public static function canUndo(): Bool {
        return historyIndex > 0;
    }
    
    public static function canRedo(): Bool {
        return historyIndex < history.length - 1;
    }
    
    static function restoreState(state: {d: String, o: String, sheet: String, filter: String}): Void {
        db.loadData(cdb.Parser.parse(state.d, true));
        currentSheet = state.sheet;
        currentFilter = state.filter;
        selectedRow = -1;
        selectedCol = -1;
        renderUI();
    }
    
    // ==================== Image Bank Management ====================
    
    static function getImageBankKey(fileName: String): String {
        return currentFileName != null ? 'castle_img_' + currentFileName : 'castle_img_default';
    }
    
    public static function loadImageBank(): Void {
        try {
            var key = getImageBankKey(currentFileName);
            var stored: String = js.Syntax.code("localStorage.getItem({0})", key);
            imageBank = new Map();
            if (stored != null) {
                var data: Dynamic = haxe.Json.parse(stored);
                for (field in Reflect.fields(data)) {
                    imageBank.set(field, Reflect.field(data, field));
                }
            }
        } catch(e: Dynamic) {
            imageBank = new Map();
        }
    }
    
    public static function saveImageBank(): Void {
        try {
            var key = getImageBankKey(currentFileName);
            var obj: Dynamic = {};
            for (key in imageBank.keys()) {
                Reflect.setField(obj, key, imageBank.get(key));
            }
            js.Syntax.code("localStorage.setItem({0},{1})", key, haxe.Json.stringify(obj));
        } catch(e: Dynamic) {
            trace('Failed to save image bank: ' + e);
        }
    }
    
    public static function getImageData(key: String): String {
        return imageBank.get(key);
    }
    
    public static function addImageToBank(key: String, data: String): Void {
        imageBank.set(key, data);
        saveImageBank();
    }
    
    // ==================== Sheet Management ====================
    
    @:expose
    public static function createSheet(name: String): Bool {
        if (db == null || name == null || name == "") return false;
        for (sheet in db.sheets) {
            if (sheet.name == name) return false;
        }
        saveState();
        db.createSheet(name);
        currentSheet = name;
        renderUI();
        return true;
    }
    
    @:expose
    public static function deleteSheet(name: String): Bool {
        if (db == null) return false;
        var sheet = db.getSheet(name);
        if (sheet == null) return false;
        if (db.sheets.length <= 1) return false;
        
        saveState();
        @:privateAccess db.data.sheets.remove(sheet.sheet);
        @:privateAccess db.sheets.remove(sheet);
        db.sync();
        if (currentSheet == name) {
            currentSheet = db.sheets.length > 0 ? db.sheets[0].name : null;
        }
        renderUI();
        return true;
    }
    
    @:expose
    public static function renameSheet(oldName: String, newName: String): Bool {
        if (db == null || newName == null || newName == "") return false;
        var sheet = db.getSheet(oldName);
        if (sheet == null) return false;
        for (s in db.sheets) {
            if (s.name == newName) return false;
        }
        saveState();
        @:privateAccess sheet.sheet.name = newName;
        db.sync();
        currentSheet = newName;
        renderUI();
        return true;
    }
    
    @:expose
    public static function moveSheet(name: String, delta: Int): Bool {
        if (db == null) return false;
        var sheet = db.getSheet(name);
        if (sheet == null) return false;
        
        var idx = db.sheets.indexOf(sheet);
        var newIdx = idx + delta;
        if (newIdx < 0 || newIdx >= db.sheets.length) return false;
        
        saveState();
        @:privateAccess db.data.sheets.remove(sheet.sheet);
        @:privateAccess db.sheets.remove(sheet);
        @:privateAccess db.data.sheets.insert(newIdx, sheet.sheet);
        @:privateAccess db.sheets.insert(newIdx, sheet);
        db.sync();
        renderUI();
        return true;
    }
    
    public static function getSheetNames(): Array<String> {
        if (db == null) return [];
        var names = [];
        for (sheet in db.sheets) {
            if (sheet.props == null || !sheet.props.hide) {
                names.push(sheet.name);
            }
        }
        return names;
    }
    
    // ==================== Column Management ====================
    
    static function columnNameExists(sheet: Sheet, name: String, excludeIndex: Int = -1): Bool {
        for (i in 0...sheet.columns.length) {
            if (i == excludeIndex) continue;
            if (sheet.columns[i].name == name) return true;
        }
        return false;
    }
    
    @:expose
    public static function createColumn(sheetName: String, colData: Dynamic): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return false;
        
        var name = colData.name;
        if (name == null || name == "") return false;
        if (columnNameExists(sheet, name)) return false;
        
        var colType: ColumnType = parseColumnType(colData.type, colData);
        
        saveState();
        @:privateAccess sheet.sheet.columns.push({
            name: name,
            type: colType,
            typeStr: getTypeString(colType, colData),
            opt: colData.opt == true
        });
        db.sync();
        renderUI();
        return true;
    }
    
    @:expose
    public static function editColumn(sheetName: String, colIndex: Int, colData: Dynamic): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) return false;
        
        var name = colData.name;
        if (name == null || name == "") return false;
        if (columnNameExists(sheet, name, colIndex)) return false;
        
        var colType: ColumnType = parseColumnType(colData.type, colData);
        var oldCol = sheet.columns[colIndex];
        
        saveState();
        
        var newCol: Column = {
            name: name,
            type: colType,
            typeStr: getTypeString(colType, colData),
            opt: colData.opt == true
        };
        
        if (oldCol.display != null) newCol.display = oldCol.display;
        if (oldCol.kind != null) newCol.kind = oldCol.kind;
        if (oldCol.documentation != null) newCol.documentation = oldCol.documentation;
        
        var nameChanged = oldCol.name != name;
        if (nameChanged) {
            for (line in sheet.lines) {
                var val = Reflect.field(line, oldCol.name);
                Reflect.deleteField(line, oldCol.name);
                Reflect.setField(line, name, val);
            }
        }
        
        @:privateAccess sheet.sheet.columns[colIndex] = newCol;
        db.sync();
        renderUI();
        return true;
    }
    
    @:expose
    public static function deleteColumn(sheetName: String, colIndex: Int): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) return false;
        
        saveState();
        var col = sheet.columns[colIndex];
        @:privateAccess sheet.sheet.columns.splice(colIndex, 1);
        
        for (line in sheet.lines) {
            Reflect.deleteField(line, col.name);
        }
        
        db.sync();
        renderUI();
        return true;
    }
    
    @:expose
    public static function moveColumn(sheetName: String, colIndex: Int, delta: Int): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) return false;
        
        var newIdx = colIndex + delta;
        if (newIdx < 0 || newIdx >= sheet.columns.length) return false;
        
        saveState();
        var col = sheet.columns[colIndex];
        @:privateAccess sheet.sheet.columns.splice(colIndex, 1);
        @:privateAccess sheet.sheet.columns.insert(newIdx, col);
        db.sync();
        renderUI();
        return true;
    }
    
    @:expose
    public static function setDisplayColumn(sheetName: String, colName: String): Void {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return;
        saveState();
        if (sheet.props.displayColumn == colName) {
            sheet.props.displayColumn = null;
        } else {
            sheet.props.displayColumn = colName;
        }
        db.sync();
        renderUI();
    }
    
    @:expose
    public static function setDisplayIcon(sheetName: String, colName: String): Void {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return;
        saveState();
        if (sheet.props.displayIcon == colName) {
            sheet.props.displayIcon = null;
        } else {
            sheet.props.displayIcon = colName;
        }
        db.sync();
        renderUI();
    }
    
    @:expose
    public static function getColumnInfo(sheetName: String, colIndex: Int): Dynamic {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) return null;
        
        var col = sheet.columns[colIndex];
        var info: Dynamic = {
            name: col.name,
            type: getTypeId(col.type),
            opt: col.opt == true,
            displayColumn: sheet.props.displayColumn == col.name,
            displayIcon: sheet.props.displayIcon == col.name
        };
        
        switch(col.type) {
            case TEnum(values): info.enumValues = values.join(",");
            case TFlags(values): info.flagsValues = values.join(",");
            case TRef(s): info.refSheet = s;
            default:
        }
        
        return info;
    }
    
    @:expose
    public static function getColumnNames(sheetName: String): Array<String> {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return [];
        return [for (c in sheet.columns) c.name];
    }
    
    @:expose
    public static function convertColumn(sheetName: String, colIndex: Int, conversionType: String): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) return false;
        
        var col = sheet.columns[colIndex];
        saveState();
        
        switch(conversionType) {
            case "lower":
                for (line in sheet.lines) {
                    var val: String = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val.toLowerCase());
                }
            case "upper":
                for (line in sheet.lines) {
                    var val: String = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val.toUpperCase());
                }
            case "title":
                for (line in sheet.lines) {
                    var val: String = Reflect.field(line, col.name);
                    if (val != null && val.length > 0) {
                        Reflect.setField(line, col.name, val.charAt(0).toUpperCase() + val.substr(1).toLowerCase());
                    }
                }
            case "mul10":
                for (line in sheet.lines) {
                    var val: Float = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val * 10);
                }
            case "div10":
                for (line in sheet.lines) {
                    var val: Float = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val / 10);
                }
            case "add1":
                for (line in sheet.lines) {
                    var val: Float = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val + 1);
                }
            case "sub1":
                for (line in sheet.lines) {
                    var val: Float = Reflect.field(line, col.name);
                    if (val != null) Reflect.setField(line, col.name, val - 1);
                }
            default:
                return false;
        }
        
        renderSheet();
        return true;
    }
    
    // ==================== Row Management ====================
    
    @:expose
    public static function addRow(): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        saveState();
        var newLine: Dynamic = {};
        
        for (col in sheet.columns) {
            if (col.type.match(TGuid)) {
                Reflect.setField(newLine, col.name, cdb.Database.genGUID());
            }
        }
        
        @:privateAccess sheet.sheet.lines.push(newLine);
        selectedRow = sheet.lines.length - 1;
        renderSheet();
    }
    
    @:expose
    public static function insertRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        saveState();
        var newLine: Dynamic = {};
        
        for (col in sheet.columns) {
            if (col.type.match(TGuid)) {
                Reflect.setField(newLine, col.name, cdb.Database.genGUID());
            }
        }
        
        @:privateAccess sheet.sheet.lines.insert(index, newLine);
        selectedRow = index;
        renderSheet();
    }
    
    @:expose
    public static function deleteRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        if (index < 0 || index >= sheet.lines.length) return;
        
        saveState();
        @:privateAccess sheet.sheet.lines.splice(index, 1);
        selectedRow = -1;
        renderSheet();
    }
    
    @:expose
    public static function moveRow(fromIndex: Int, toIndex: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        if (fromIndex < 0 || fromIndex >= sheet.lines.length) return;
        if (toIndex < 0 || toIndex >= sheet.lines.length) return;
        saveState();
        var line = sheet.lines[fromIndex];
        @:privateAccess sheet.sheet.lines.splice(fromIndex, 1);
        @:privateAccess sheet.sheet.lines.insert(toIndex, line);
        selectedRow = toIndex;
        renderSheet();
    }
    
    @:expose
    public static function duplicateRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || index < 0 || index >= sheet.lines.length) return;
        saveState();
        var line = sheet.lines[index];
        var copy = Reflect.copy(line);
        
        for (col in sheet.columns) {
            if (col.type.match(TGuid)) {
                Reflect.setField(copy, col.name, cdb.Database.genGUID());
            }
        }
        
        @:privateAccess sheet.sheet.lines.insert(index + 1, copy);
        selectedRow = index + 1;
        renderSheet();
    }
    
    @:expose
    public static function copyRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || index < 0 || index >= sheet.lines.length) return;
        clipboard = Reflect.copy(sheet.lines[index]);
    }
    
    @:expose
    public static function pasteRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || clipboard == null) return;
        saveState();
        var pasteCopy = Reflect.copy(clipboard);
        
        for (col in sheet.columns) {
            if (col.type.match(TGuid)) {
                Reflect.setField(pasteCopy, col.name, cdb.Database.genGUID());
            }
        }
        
        if (index >= 0 && index < sheet.lines.length) {
            @:privateAccess sheet.sheet.lines.insert(index + 1, pasteCopy);
            selectedRow = index + 1;
        } else {
            @:privateAccess sheet.sheet.lines.push(pasteCopy);
            selectedRow = sheet.lines.length - 1;
        }
        renderSheet();
    }
    
    @:expose
    public static function hasClipboard(): Bool {
        return clipboard != null;
    }
    
    // ==================== Separator Management ====================
    
    @:expose
    public static function toggleSeparator(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        saveState();
        
        var sepIndex = -1;
        for (i in 0...sheet.separators.length) {
            if (sheet.separators[i].index == index) {
                sepIndex = i;
                break;
            }
        }
        
        if (sepIndex >= 0) {
            sheet.separators.splice(sepIndex, 1);
        } else {
            sheet.separators.push({ index: index });
            sheet.separators.sort(function(a, b) return a.index - b.index);
        }
        
        @:privateAccess sheet.sheet.separators = sheet.separators;
        renderSheet();
    }
    
    @:expose
    public static function setSeparatorTitle(index: Int, title: String): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        saveState();
        
        var sepIndex = -1;
        for (i in 0...sheet.separators.length) {
            if (sheet.separators[i].index == index) {
                sepIndex = i;
                break;
            }
        }
        
        if (sepIndex >= 0) {
            sheet.separators[sepIndex].title = title;
        }
        
        @:privateAccess sheet.sheet.separators = sheet.separators;
        renderSheet();
    }
    
    // ==================== Cell Editing ====================
    
    @:expose
    public static function updateCell(rowIndex: Int, colIndex: Int, value: Dynamic): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        
        saveState();
        
        if (value == null || value == "") {
            Reflect.deleteField(line, col.name);
        } else {
            var converted: Dynamic = value;
            switch (col.type) {
                case TInt:
                    var parsed = Std.parseInt(Std.string(value));
                    if (parsed == null) parsed = 0;
                    converted = parsed;
                case TFloat:
                    var parsed = Std.parseFloat(Std.string(value));
                    if (Math.isNaN(parsed)) parsed = 0.0;
                    converted = parsed;
                case TBool:
                    converted = value == true || value == "true" || value == "1" || value == 1;
                case TColor:
                    var hex = Std.string(value);
                    if (StringTools.startsWith(hex, "#")) hex = hex.substr(1);
                    if (hex.length == 6) {
                        hex = "FF" + hex;
                    }
                    if (hex.length == 8) {
                        var r = Std.parseInt("0x" + hex.substr(2, 2));
                        var g = Std.parseInt("0x" + hex.substr(4, 2));
                        var b = Std.parseInt("0x" + hex.substr(6, 2));
                        var a = Std.parseInt("0x" + hex.substr(0, 2));
                        if (r != null && g != null && b != null && a != null) {
                            converted = (a << 24) | (r << 16) | (g << 8) | b;
                        } else {
                            converted = 0xFF000000;
                        }
                    } else {
                        converted = 0xFF000000;
                    }
                default:
                    converted = value;
            }
            Reflect.setField(line, col.name, converted);
        }
        
        renderSheet();
    }
    
    // ==================== Search/Filter ====================
    
    @:expose
    public static function setFilter(filter: String): Void {
        currentFilter = filter != null && filter.length > 0 ? filter.toLowerCase() : null;
        selectedRow = -1;
        renderSheet();
    }
    
    static function matchesFilter(line: Dynamic, columns: Array<Column>): Bool {
        if (currentFilter == null) return true;
        for (col in columns) {
            var val = Reflect.field(line, col.name);
            if (val != null && Std.string(val).toLowerCase().indexOf(currentFilter) >= 0) {
                return true;
            }
        }
        return false;
    }
    
    // ==================== Sub-sheet Editing ====================
    
    @:expose
    public static function openSubSheet(rowIndex: Int, colIndex: Int): Dynamic {
        var sheet = getCurrentSheet();
        if (sheet == null) return null;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        var val = line != null ? Reflect.field(line, col.name) : null;
        
        var subSheetName = sheet.name + "@" + col.name;
        var subSheet = db.getSheet(subSheetName);
        
        subSheetData = {
            sheetName: sheet.name,
            rowIndex: rowIndex,
            colIndex: colIndex,
            subSheet: subSheet,
            parentSheet: sheet,
            parentRow: line
        };
        
        return {
            parentSheet: sheet.name,
            columnName: col.name,
            columnType: getTypeId(col.type),
            subSheetName: subSheet != null ? subSheet.name : null,
            data: val,
            columns: subSheet != null ? [for (c in subSheet.columns) {name: c.name, type: getTypeId(c.type), opt: c.opt}] : []
        };
    }
    
    @:expose
    public static function getSubSheetData(): Dynamic {
        if (subSheetData == null || subSheetData.subSheet == null) return null;
        
        var sub = subSheetData.subSheet;
        return {
            columns: [for (c in sub.columns) {name: c.name, type: getTypeId(c.type), opt: c.opt}],
            lines: sub.lines
        };
    }
    
    @:expose
    public static function updateSubSheetCell(lineIndex: Int, colName: String, value: Dynamic): Void {
        if (subSheetData == null || subSheetData.subSheet == null) return;
        
        saveState();
        var line = subSheetData.subSheet.lines[lineIndex];
        if (line == null) return;
        
        if (value == null || value == "") {
            Reflect.deleteField(line, colName);
        } else {
            Reflect.setField(line, colName, value);
        }
    }
    
    @:expose
    public static function addSubSheetRow(): Void {
        if (subSheetData == null || subSheetData.subSheet == null) return;
        saveState();
        @:privateAccess subSheetData.subSheet.sheet.lines.push({});
    }
    
    @:expose
    public static function deleteSubSheetRow(index: Int): Void {
        if (subSheetData == null || subSheetData.subSheet == null) return;
        saveState();
        @:privateAccess subSheetData.subSheet.sheet.lines.splice(index, 1);
    }
    
    @:expose
    public static function closeSubSheet(): Void {
        if (subSheetData != null && subSheetData.parentRow != null) {
            var col = subSheetData.parentSheet.columns[subSheetData.colIndex];
            var sub = subSheetData.subSheet;
            if (sub != null) {
                Reflect.setField(subSheetData.parentRow, col.name, sub.lines);
            }
        }
        subSheetData = null;
    }
    
    // ==================== Gradient Editing ====================
    
    @:expose
    public static function openGradientEditor(rowIndex: Int, colIndex: Int): Dynamic {
        var sheet = getCurrentSheet();
        if (sheet == null) return null;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        var val: Dynamic = Reflect.field(line, col.name);
        
        if (val == null) {
            val = { colors: [0xFF0000, 0x00FF00, 0x0000FF], positions: [0.0, 0.5, 1.0] };
        }
        
        return {
            colors: val.colors != null ? val.colors : [],
            positions: val.positions != null ? val.positions : []
        };
    }
    
    @:expose
    public static function saveGradient(rowIndex: Int, colIndex: Int, colors: Array<Int>, positions: Array<Float>): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        
        saveState();
        Reflect.setField(line, col.name, { colors: colors, positions: positions });
        renderSheet();
    }
    
    // ==================== Curve Editing ====================
    
    @:expose
    public static function openCurveEditor(rowIndex: Int, colIndex: Int): Dynamic {
        var sheet = getCurrentSheet();
        if (sheet == null) return null;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        var val = Reflect.field(line, col.name);
        
        if (val == null) {
            val = [];
        }
        
        return { points: val };
    }
    
    @:expose
    public static function saveCurve(rowIndex: Int, colIndex: Int, points: Array<Float>): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        
        var col = sheet.columns[colIndex];
        var line = sheet.lines[rowIndex];
        
        saveState();
        Reflect.setField(line, col.name, points);
        renderSheet();
    }
    
    // ==================== Reference Validation ====================
    
    public static function validateReference(sheetName: String, colIndex: Int): {valid: Bool, message: String} {
        var sheet = db.getSheet(sheetName);
        if (sheet == null || colIndex < 0 || colIndex >= sheet.columns.length) {
            return {valid: false, message: "Invalid sheet or column"};
        }
        
        var col = sheet.columns[colIndex];
        switch(col.type) {
            case TRef(refSheet):
                var refSheetObj = db.getSheet(refSheet);
                if (refSheetObj == null) {
                    return {valid: false, message: "Referenced sheet not found: " + refSheet};
                }
                
                var idCol: String = null;
                for (c in refSheetObj.columns) {
                    if (c.type.match(TId)) {
                        idCol = c.name;
                        break;
                    }
                }
                
                if (idCol == null) {
                    return {valid: true, message: null};
                }
                
                var validIds = new Map<String, Bool>();
                for (line in refSheetObj.lines) {
                    var id: String = Reflect.field(line, idCol);
                    if (id != null) validIds.set(id, true);
                }
                
                var invalidCount = 0;
                for (line in sheet.lines) {
                    var val: String = Reflect.field(line, col.name);
                    if (val != null && val != "" && !validIds.exists(val)) {
                        invalidCount++;
                    }
                }
                
                if (invalidCount > 0) {
                    return {valid: false, message: invalidCount + " broken reference(s)"};
                }
                return {valid: true, message: null};
            default:
                return {valid: true, message: null};
        }
    }
    
    @:expose
    public static function getRowReferences(sheetName: String, rowIndex: Int): Array<{sheet: String, column: String, row: Int}> {
        var refs: Array<{sheet: String, column: String, row: Int}> = [];
        
        var sheet = db.getSheet(sheetName);
        if (sheet == null || rowIndex < 0 || rowIndex >= sheet.lines.length) return refs;
        
        var line = sheet.lines[rowIndex];
        var idCol: String = null;
        var idVal: String = null;
        
        for (col in sheet.columns) {
            if (col.type.match(TId)) {
                idCol = col.name;
                idVal = Reflect.field(line, col.name);
                break;
            }
        }
        
        if (idVal == null) return refs;
        
        for (s in db.sheets) {
            for (c in s.columns) {
                switch(c.type) {
                    case TRef(refSheetName):
                        if (refSheetName == sheetName) {
                            for (i in 0...s.lines.length) {
                                var val: String = Reflect.field(s.lines[i], c.name);
                                if (val == idVal) {
                                    refs.push({sheet: s.name, column: c.name, row: i});
                                }
                            }
                        }
                    default:
                }
            }
        }
        
        return refs;
    }
    
    // ==================== Type Helpers ====================
    
    static function getTypeId(type: ColumnType): String {
        return switch(type) {
            case TId: "id";
            case TInt: "int";
            case TFloat: "float";
            case TBool: "bool";
            case TColor: "color";
            case TFile: "file";
            case TImage: "image";
            case TList: "list";
            case TProperties: "properties";
            case TGuid: "guid";
            case TRef(_): "ref";
            case TEnum(_): "enum";
            case TFlags(_): "flags";
            case TGradient: "gradient";
            case TCurve: "curve";
            case TDynamic: "dynamic";
            default: "string";
        }
    }
    
    static function getTypeString(type: ColumnType, colData: Dynamic): String {
        return switch(type) {
            case TInt: "3";
            case TFloat: "4";
            case TBool: "2";
            case TColor: "11";
            case TFile: "13";
            case TImage: "7";
            case TList: "8";
            case TProperties: "17";
            case TGuid: "20";
            case TId: "0";
            case TRef(s): "6:" + s;
            case TEnum(values): "5:" + values.join(",");
            case TFlags(values): "10:" + values.join(",");
            case TGradient: "18";
            case TCurve: "19";
            default: "1";
        }
    }
    
    static function parseColumnType(typeStr: String, colData: Dynamic): ColumnType {
        return switch(typeStr) {
            case "id": TId;
            case "string": TString;
            case "int": TInt;
            case "float": TFloat;
            case "bool": TBool;
            case "color": TColor;
            case "file": TFile;
            case "image": TImage;
            case "list": TList;
            case "properties": TProperties;
            case "guid": TGuid;
            case "gradient": TGradient;
            case "curve": TCurve;
            case "dynamic": TDynamic;
            case "ref": TRef(colData.refSheet != null ? colData.refSheet : "");
            case "enum": TEnum(colData.enumValues != null ? colData.enumValues.split(",").map(StringTools.trim) : []);
            case "flags": TFlags(colData.flagsValues != null ? colData.flagsValues.split(",").map(StringTools.trim) : []);
            default: TString;
        }
    }
    
    // ==================== Reference Data ====================
    
    public static function getReferenceOptions(sheetName: String): Array<{id: String, name: String}> {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return [];
        
        return [for (si in sheet.all) { id: si.id, name: si.disp }];
    }
    
    // ==================== Rendering ====================
    
    public static function renderUI(): Void {
        if (db == null) return;
        
        var tabsHtml = "";
        var sheetIndex = 0;
        for (i in 0...db.sheets.length) {
            var sheet = db.sheets[i];
            if (sheet.props == null || !sheet.props.hide) {
                var active = sheet.name == currentSheet ? " active" : "";
                var icon = sheet.props.displayColumn != null ? getDisplayIcon(sheet) : "";
                tabsHtml += "<div class='tab" + active + "' data-sheet='" + sheet.name + "' data-index='" + sheetIndex + "' onclick='CastleDBApp.setCurrentSheet(\"" + sheet.name + "\")' oncontextmenu='showSheetContextMenu(event, \"" + sheet.name + "\")'>" + icon + escapeHtml(sheet.name) + "</div>";
                sheetIndex++;
            }
        }
        untyped $("#sheet-tabs").html(tabsHtml);
        
        renderSheet();
        untyped $("#welcome").hide();
        untyped $("#content").show();
    }
    
    static function getDisplayIcon(sheet: Sheet): String {
        if (sheet.props.displayIcon == null) return "";
        for (col in sheet.columns) {
            if (col.name == sheet.props.displayIcon) {
                return "[ICON] ";
            }
        }
        return "";
    }
    
    public static function renderSheet(): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) {
            untyped $("#table-head").html("");
            untyped $("#table-body").html("");
            return;
        }
        
        var columns = sheet.columns;
        var lines = sheet.lines;
        if (columns == null) columns = [];
        if (lines == null) lines = [];
        
        var headHtml = "<tr>";
        for (i in 0...columns.length) {
            var col = columns[i];
            var typeLabel = switch(col.type) {
                case TInt: "int";
                case TFloat: "float";
                case TBool: "bool";
                case TEnum(_): "enum";
                case TFlags(_): "flags";
                case TRef(s): "ref(" + s + ")";
                case TColor: "color";
                case TFile: "file";
                case TImage: "image";
                case TList: "list";
                case TProperties: "props";
                case TGuid: "guid";
                case TId: "id";
                case TGradient: "gradient";
                case TCurve: "curve";
                case TDynamic: "dynamic";
                default: "string";
            }
            var optLabel = col.opt ? " (opt)" : "";
            var dispMark = sheet.props.displayColumn == col.name ? " ★" : "";
            var iconMark = sheet.props.displayIcon == col.name ? " ⬡" : "";
            var validation = validateReference(sheet.name, i);
            var errorClass = !validation.valid ? " style='color:red;'" : "";
            headHtml += "<th data-col='" + i + "' oncontextmenu='showColumnContextMenu(event, " + i + ")'" + errorClass + ">" + escapeHtml(col.name) + " <span style='color:#888;font-size:11px'>" + typeLabel + optLabel + dispMark + iconMark + "</span></th>";
        }
        headHtml += "</tr>";
        untyped $("#table-head").html(headHtml);
        
        var bodyHtml = "";
        var filteredCount = 0;
        var visibleIndex = 0;
        
        for (rowIdx in 0...lines.length) {
            var line = lines[rowIdx];
            
            var isSeparator = false;
            for (sep in sheet.separators) {
                if (sep.index == rowIdx) {
                    var title = sep.title != null ? sep.title : "";
                    bodyHtml += "<tr class='separator-row' data-separator='" + rowIdx + "'><td colspan='" + columns.length + "' onclick='CastleDBApp.toggleSeparator(" + rowIdx + ")'>" + escapeHtml(title) + " <span style='color:#888;font-size:10px'>(click to remove)</span></td></tr>";
                    isSeparator = true;
                    break;
                }
            }
            
            if (!matchesFilter(line, columns)) continue;
            filteredCount++;
            
            var selected = rowIdx == selectedRow ? " selected" : "";
            bodyHtml += "<tr data-row='" + rowIdx + "' data-visible='" + visibleIndex + "' class='data-row" + selected + "'>";
            
            for (colIdx in 0...columns.length) {
                var col = columns[colIdx];
                var val = line != null ? Reflect.field(line, col.name) : null;
                var isRef = col.type.match(TRef(_));
                var refValid = isRef ? validateRefValue(col, val) : true;
                bodyHtml += renderCell(rowIdx, colIdx, col, val, refValid);
            }
            bodyHtml += "</tr>";
            visibleIndex++;
        }
        untyped $("#table-body").html(bodyHtml);
        
        attachCellHandlers();
        
        var statusText = lines.length + " rows";
        if (currentFilter != null) statusText += " (" + filteredCount + " shown)";
        statusText += " | " + columns.length + " columns";
        if (canUndo()) statusText += " | Ctrl+Z: Undo";
        if (canRedo()) statusText += " | Ctrl+Y: Redo";
        untyped $("#status-bar").text(statusText);
    }
    
    static function validateRefValue(col: Column, val: Dynamic): Bool {
        if (val == null || val == "") return true;
        switch(col.type) {
            case TRef(refSheet):
                var refSheetObj = db.getSheet(refSheet);
                if (refSheetObj == null) return false;
                
                var idCol: String = null;
                for (c in refSheetObj.columns) {
                    if (c.type.match(TId)) {
                        idCol = c.name;
                        break;
                    }
                }
                
                if (idCol == null) return true;
                
                for (line in refSheetObj.lines) {
                    var id: String = Reflect.field(line, idCol);
                    if (id == val) return true;
                }
                return false;
            default:
                return true;
        }
    }
    
    static function renderCell(rowIdx: Int, colIdx: Int, col: Column, val: Dynamic, refValid: Bool = true): String {
        var inputAttrs = "data-row='" + rowIdx + "' data-col='" + colIdx + "'";
        var errorStyle = refValid ? "" : " style='background:#ffebee;color:#c62828;'";
        
        return switch (col.type) {
            case TBool:
                var checked = val != null && val != false && val != 0 ? "checked" : "";
                "<td><input type='checkbox' class='edit-cell' " + inputAttrs + " " + checked + " /></td>";
            
            case TColor:
                var colorHex = "000000";
                if (val != null) {
                    var intVal: Int = val;
                    var r = (intVal >> 16) & 0xFF;
                    var g = (intVal >> 8) & 0xFF;
                    var b = intVal & 0xFF;
                    colorHex = StringTools.hex(r, 2) + StringTools.hex(g, 2) + StringTools.hex(b, 2);
                }
                var alphaHex = "FF";
                if (val != null) {
                    var a = (val >> 24) & 0xFF;
                    alphaHex = StringTools.hex(a, 2);
                }
                "<td><input type='text' class='edit-cell color-cell' " + inputAttrs + " data-color='" + alphaHex + colorHex + "' value='#" + alphaHex + colorHex + "'" + errorStyle + " /></td>";
            
            case TEnum(values):
                var html = "<td><select class='edit-cell' " + inputAttrs + errorStyle + ">";
                html += "<option value=''>--</option>";
                for (i in 0...values.length) {
                    var sel = (val == i) ? "selected" : "";
                    html += "<option value='" + i + "' " + sel + ">" + escapeHtml(values[i]) + "</option>";
                }
                return html + "</select></td>";
            
            case TFlags(values):
                var html = "<td><div class='flags-cell' " + inputAttrs + errorStyle + ">";
                var flagsInt: Dynamic = val != null ? val : 0;
                for (i in 0...values.length) {
                    var bit = 1 << i;
                    var checked = (flagsInt & bit) != 0 ? "checked" : "";
                    html += "<label><input type='checkbox' class='edit-cell flag-check' data-flag='" + i + "' " + inputAttrs + " " + checked + " /> " + escapeHtml(values[i]) + "</label>";
                }
                return html + "</div></td>";
            
            case TRef(refSheet):
                var html = "<td><select class='edit-cell ref-select' " + inputAttrs + errorStyle + ">";
                html += "<option value=''>--</option>";
                var options = getReferenceOptions(refSheet);
                for (opt in options) {
                    var sel = (val == opt.id) ? "selected" : "";
                    html += "<option value='" + escapeHtml(opt.id) + "' " + sel + ">" + escapeHtml(opt.name) + "</option>";
                }
                return html + "</select></td>";
            
            case TList:
                var count = val != null && Std.isOfType(val, Array) ? val.length : 0;
                var displayVal = "[" + count + " items]";
                return "<td><span class='edit-cell list-cell' " + inputAttrs + " style='cursor:pointer;color:#4A90D9;' onclick='openListEditor(" + rowIdx + ", " + colIdx + ")'>" + displayVal + "</span></td>";
            
            case TProperties:
                var hasProps = val != null && Reflect.fields(val).length > 0;
                var displayVal = hasProps ? "[" + Reflect.fields(val).length + " props]" : "[empty]";
                return "<td><span class='edit-cell props-cell' " + inputAttrs + " style='cursor:pointer;color:#4A90D9;' onclick='openPropsEditor(" + rowIdx + ", " + colIdx + ")'>" + displayVal + "</span></td>";
            
            case TGradient:
                return "<td><span class='edit-cell gradient-cell' " + inputAttrs + " style='cursor:pointer;color:#4A90D9;' onclick='openGradientEditor(" + rowIdx + ", " + colIdx + ")'>[Gradient]</span></td>";
            
            case TCurve:
                return "<td><span class='edit-cell curve-cell' " + inputAttrs + " style='cursor:pointer;color:#4A90D9;' onclick='openCurveEditor(" + rowIdx + ", " + colIdx + ")'>[Curve]</span></td>";
            
            case TInt, TFloat:
                var numVal = val != null ? Std.string(val) : "";
                return "<td><input type='number' class='edit-cell' " + inputAttrs + " value='" + numVal + "' step='any'" + errorStyle + " /></td>";
            
            case TId:
                var strVal = val != null ? Std.string(val) : "";
                return "<td><input type='text' class='edit-cell id-cell' " + inputAttrs + " value='" + escapeHtml(strVal) + "' style='font-weight:bold;color:#1565C0;'" + errorStyle + " /></td>";
            
            case TImage:
                var strVal = val != null ? Std.string(val) : "";
                if (strVal != "" && strVal.indexOf(":") < 0) {
                    var imgData = getImageData(strVal);
                    if (imgData != null) {
                        return "<td><img src='" + imgData + "' class='image-preview' " + inputAttrs + " onclick='openImagePicker(" + rowIdx + "," + colIdx + ")' /></td>";
                    } else {
                        return "<td><span class='image-missing' " + inputAttrs + " onclick='openImagePicker(" + rowIdx + "," + colIdx + ")'>[Missing: " + escapeHtml(strVal) + "]</span></td>";
                    }
                } else if (strVal != "") {
                    return "<td><img src='" + escapeHtml(strVal) + "' class='image-preview' " + inputAttrs + " onclick='openImagePicker(" + rowIdx + "," + colIdx + ")' /></td>";
                } else {
                    return "<td><button class='image-upload-btn' " + inputAttrs + " onclick='openImagePicker(" + rowIdx + "," + colIdx + ")'>+ Image</button></td>";
                }
            
            case TFile:
                var strVal = val != null ? Std.string(val) : "";
                var ext = strVal != "" ? strVal.split(".").pop().toLowerCase() : "";
                var isImage = (ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "gif" || ext == "webp");
                if (isImage && strVal != "") {
                    if (strVal.indexOf(":") >= 0) {
                        return "<td><img src='" + escapeHtml(strVal) + "' class='image-preview' /></td>";
                    } else {
                        return "<td><span class='file-path'>" + escapeHtml(strVal) + " <span style='color:#888'>(URL not supported)</span></span></td>";
                    }
                } else if (strVal != "") {
                    return "<td><span class='file-path'>" + escapeHtml(strVal) + "</span></td>";
                } else {
                    return "<td><input type='text' class='edit-cell' " + inputAttrs + " value='' placeholder='file path'" + errorStyle + " /></td>";
                }
            
            default:
                var strVal = val != null ? Std.string(val) : "";
                return "<td><input type='text' class='edit-cell' " + inputAttrs + " value='" + escapeHtml(strVal) + "'" + errorStyle + " /></td>";
        }
    }
    
    static function attachCellHandlers(): Void {
        js.Syntax.code("setupCellHandlers()");
    }
    
    // ==================== Image Handling ====================
    
    @:expose
    public static function openImagePicker(rowIndex: Int, colIndex: Int): Void {
        js.Syntax.code("window.currentImagePickerRow = {0}", rowIndex);
        js.Syntax.code("window.currentImagePickerCol = {0}", colIndex);
        js.Syntax.code("document.getElementById(\"image-file-input\").click()");
    }
    
    @:expose
    public static function handleImageUpload(dataUrl: String, fileName: String): Void {
        var ext = fileName.split(".").pop().toLowerCase();
        var key = "img_" + Std.string(Date.now().getTime()) + "." + ext;
        
        addImageToBank(key, dataUrl);
        
        var row: Int = cast js.Lib.eval("parseInt(window.currentImagePickerRow)");
        var col: Int = cast js.Lib.eval("parseInt(window.currentImagePickerCol)");
        if (row != null && col != null) {
            updateCell(row, col, key);
        }
    }
    
    static function escapeHtml(s: String): String {
        if (s == null) return "";
        return StringTools.htmlEscape(s);
    }
    
    // ==================== Recent Files ====================
    
    public static function getRecentFiles(): Array<String> {
        try {
            var stored = js.Browser.getLocalStorage().getItem("castle_recent");
            if (stored != null) {
                return haxe.Json.parse(stored);
            }
        } catch(e: Dynamic) {}
        return [];
    }
    
    public static function addRecentFile(path: String): Void {
        try {
            var recent = getRecentFiles();
            recent.remove(path);
            recent.unshift(path);
            if (recent.length > 10) recent.pop();
            js.Browser.getLocalStorage().setItem("castle_recent", haxe.Json.stringify(recent));
        } catch(e: Dynamic) {}
    }
}
