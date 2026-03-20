/*
 * CastleDB Browser Application
 * Full-featured browser-compatible version for sheet editing
 */

import cdb.Database;
import cdb.Data;
import cdb.Sheet;

@:expose
class CastleDBApp {
    
    static var db: Database;
    static var currentSheet: String;
    static var selectedRow: Int = -1;
    static var history: Array<{d: String, o: String}> = [];
    static var historyIndex: Int = -1;
    static var clipboard: Dynamic = null;
    
    public static function init() {
        untyped __js__('
        document.addEventListener("keydown", function(e) {
            if (e.ctrlKey || e.metaKey) {
                switch(e.key) {
                    case "s": e.preventDefault(); if(typeof saveFile === "function") saveFile(); break;
                    case "z": e.preventDefault(); undo(); break;
                    case "y": e.preventDefault(); redo(); break;
                }
            }
            if (e.key === "Delete" && selectedRow >= 0) {
                e.preventDefault();
                if(typeof deleteSelectedRow === "function") deleteSelectedRow();
            }
        });
        ');
    }
    
    // ==================== File Operations ====================
    
    public static function loadCDB(content: String): Void {
        try {
            db = new Database();
            db.load(content);
            currentSheet = db.sheets.length > 0 ? db.sheets[0].name : null;
            history = [];
            historyIndex = -1;
            renderUI();
        } catch(e: Dynamic) {
            trace("Error loading CDB: " + e);
            untyped __js__('console.error(e && e.stack || e)');
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
        renderUI();
    }
    
    public static function createNewDatabase(): Void {
        db = new Database();
        db.createSheet("Sheet1");
        currentSheet = "Sheet1";
        history = [];
        historyIndex = -1;
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
            o: haxe.Serializer.run(getOpenedState())
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
    
    public static function undo(): Void {
        if (historyIndex > 0) {
            historyIndex--;
            restoreState(history[historyIndex]);
        }
    }
    
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
    
    static function restoreState(state: {d: String, o: String}): Void {
        db.loadData(cdb.Parser.parse(state.d, true));
        renderUI();
    }
    
    // ==================== Sheet Management ====================
    
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
    
    public static function deleteSheet(name: String): Bool {
        if (db == null) return false;
        var sheet = db.getSheet(name);
        if (sheet == null) return false;
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
    
    public static function getSheetNames(): Array<String> {
        if (db == null) return [];
        var names = [];
        for (sheet in db.sheets) {
            if (!sheet.props.hide) {
                names.push(sheet.name);
            }
        }
        return names;
    }
    
    // ==================== Column Management ====================
    
    public static function createColumn(sheetName: String, colData: Dynamic): Bool {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return false;
        
        var colType: ColumnType = parseColumnType(colData.type, colData);
        
        saveState();
        @:privateAccess sheet.sheet.columns.push({
            name: colData.name,
            type: colType,
            typeStr: getTypeString(colType, colData),
            opt: colData.opt
        });
        db.sync();
        renderUI();
        return true;
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
            case TRef(s): "6:" + s;
            case TEnum(values): "5:" + values.join(",");
            case TFlags(values): "10:" + values.join(",");
            default: "1";
        }
    }
    
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
    
    static function parseColumnType(typeStr: String, colData: Dynamic): ColumnType {
        return switch(typeStr) {
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
            case "ref": TRef(colData.refSheet != null ? colData.refSheet : "");
            case "enum": TEnum(colData.enumValues != null ? colData.enumValues.split(",").map(StringTools.trim) : []);
            case "flags": TFlags(colData.flagsValues != null ? colData.flagsValues.split(",").map(StringTools.trim) : []);
            default: TString;
        }
    }
    
    // ==================== Row Management ====================
    
    public static function addRow(): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        saveState();
        @:privateAccess sheet.sheet.lines.push({});
        renderSheet();
    }
    
    public static function insertRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        saveState();
        @:privateAccess sheet.sheet.lines.insert(index, {});
        renderSheet();
    }
    
    public static function deleteRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        saveState();
        @:privateAccess sheet.sheet.lines.splice(index, 1);
        renderSheet();
    }
    
    public static function moveRow(fromIndex: Int, toIndex: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null) return;
        if (fromIndex < 0 || fromIndex >= sheet.lines.length) return;
        if (toIndex < 0 || toIndex >= sheet.lines.length) return;
        saveState();
        var line = sheet.lines[fromIndex];
        @:privateAccess sheet.sheet.lines.splice(fromIndex, 1);
        @:privateAccess sheet.sheet.lines.insert(toIndex, line);
        renderSheet();
    }
    
    public static function duplicateRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || index < 0 || index >= sheet.lines.length) return;
        saveState();
        var line = sheet.lines[index];
        var copy = Reflect.copy(line);
        @:privateAccess sheet.sheet.lines.insert(index + 1, copy);
        renderSheet();
    }
    
    public static function copyRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || index < 0 || index >= sheet.lines.length) return;
        clipboard = Reflect.copy(sheet.lines[index]);
    }
    
    public static function pasteRow(index: Int): Void {
        var sheet = getCurrentSheet();
        if (sheet == null || clipboard == null) return;
        saveState();
        var pasteCopy = Reflect.copy(clipboard);
        if (index >= 0 && index < sheet.lines.length) {
            @:privateAccess sheet.sheet.lines.insert(index + 1, pasteCopy);
        } else {
            @:privateAccess sheet.sheet.lines.push(pasteCopy);
        }
        renderSheet();
    }
    
    public static function hasClipboard(): Bool {
        return clipboard != null;
    }
    
    // ==================== Cell Editing ====================
    
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
                    converted = Std.parseInt(Std.string(value));
                    if (Math.isNaN(converted)) converted = 0;
                case TFloat:
                    converted = Std.parseFloat(Std.string(value));
                    if (Math.isNaN(converted)) converted = 0.0;
                case TBool:
                    converted = value == true || value == "true" || value == "1" || value == 1;
                default:
                    converted = value;
            }
            Reflect.setField(line, col.name, converted);
        }
    }
    
    // ==================== Reference Data ====================
    
    public static function getReferenceOptions(sheetName: String): Array<{id: String, name: String}> {
        var sheet = db.getSheet(sheetName);
        if (sheet == null) return [];
        
        var options = [];
        var idCol = null;
        var nameCol = null;
        
        for (col in sheet.columns) {
            if (col.type.match(TId)) idCol = col.name;
            if (col.type.match(TString) && nameCol == null) nameCol = col.name;
        }
        
        for (line in sheet.lines) {
            var id = idCol != null ? Reflect.field(line, idCol) : null;
            var name = nameCol != null ? Reflect.field(line, nameCol) : null;
            if (id != null) {
                options.push({ id: id, name: name != null ? name : id });
            }
        }
        
        return options;
    }
    
    // ==================== Rendering ====================
    
    public static function renderUI(): Void {
        if (db == null) return;
        
        var tabsHtml = "";
        for (sheet in db.sheets) {
            if (sheet.props != null && !sheet.props.hide) {
                var active = sheet.name == currentSheet ? " active" : "";
                tabsHtml += "<div class='tab" + active + "' onclick='CastleDBApp.setCurrentSheet(\"" + sheet.name + "\")'>" + sheet.name + "</div>";
            }
        }
        untyped $("#sheet-tabs").html(tabsHtml);
        
        renderSheet();
        untyped $("#welcome").hide();
        untyped $("#content").show();
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
                default: "string";
            }
            var optLabel = col.opt ? " (opt)" : "";
            headHtml += "<th>" + col.name + " <span style='color:#888;font-size:11px'>" + typeLabel + optLabel + "</span></th>";
        }
        headHtml += "</tr>";
        untyped $("#table-head").html(headHtml);
        
        var bodyHtml = "";
        for (rowIdx in 0...lines.length) {
            var line = lines[rowIdx];
            bodyHtml += "<tr data-row='" + rowIdx + "'>";
            for (colIdx in 0...columns.length) {
                var col = columns[colIdx];
                var val = line != null ? Reflect.field(line, col.name) : null;
                bodyHtml += renderCell(rowIdx, colIdx, col, val);
            }
            bodyHtml += "</tr>";
        }
        untyped $("#table-body").html(bodyHtml);
        
        attachCellHandlers();
        
        var statusText = lines.length + " rows | " + columns.length + " columns";
        if (canUndo()) statusText += " | Undo available";
        if (canRedo()) statusText += " | Redo available";
        untyped $("#status-bar").text(statusText);
    }
    
    static function renderCell(rowIdx: Int, colIdx: Int, col: Column, val: Dynamic): String {
        var inputAttrs = "data-row='" + rowIdx + "' data-col='" + colIdx + "'";
        
        return switch (col.type) {
            case TBool:
                var checked = val != null && val != false && val != 0 ? "checked" : "";
                "<td><input type='checkbox' class='edit-cell' " + inputAttrs + " " + checked + " /></td>";
            
            case TColor:
                var colorVal = val != null ? Std.string(val) : "#000000";
                "<td><input type='color' class='edit-cell color-input' " + inputAttrs + " value='" + colorVal + "' /></td>";
            
            case TEnum(values):
                var html = "<td><select class='edit-cell' " + inputAttrs + ">";
                html += "<option value=''>--</option>";
                for (i in 0...values.length) {
                    var selected: Dynamic = val;
                    var sel = (selected == i) ? "selected" : "";
                    html += "<option value='" + i + "' " + sel + ">" + values[i] + "</option>";
                }
                return html + "</select></td>";
            
            case TFlags(values):
                var html = "<td><div class='flags-cell' " + inputAttrs + ">";
                var flagsInt: Dynamic = val != null ? val : 0;
                for (i in 0...values.length) {
                    var bit = 1 << i;
                    var checked = (flagsInt & bit) != 0 ? "checked" : "";
                    html += "<label><input type='checkbox' class='edit-cell flag-check' data-flag='" + i + "' " + inputAttrs + " " + checked + " /> " + values[i] + "</label>";
                }
                return html + "</div></td>";
            
            case TRef(refSheet):
                var html = "<td><select class='edit-cell ref-select' " + inputAttrs + ">";
                html += "<option value=''>--</option>";
                var options = getReferenceOptions(refSheet);
                for (opt in options) {
                    var selected: Dynamic = val;
                    var sel = (selected == opt.id) ? "selected" : "";
                    html += "<option value='" + opt.id + "' " + sel + ">" + opt.name + "</option>";
                }
                return html + "</select></td>";
            
            case TList, TProperties:
                var displayVal = val != null ? Std.string(val).substr(0, 30) + "..." : "[empty]";
                "<td><span class='edit-cell complex-cell' " + inputAttrs + " style='cursor:pointer;color:#4A90D9;'>" + escapeHtml(displayVal) + "</span></td>";
            
            case TInt, TFloat:
                var numVal = val != null ? Std.string(val) : "";
                "<td><input type='number' class='edit-cell' " + inputAttrs + " value='" + numVal + "' step='any' /></td>";
            
            default:
                var strVal = val != null ? Std.string(val) : "";
                "<td><input type='text' class='edit-cell' " + inputAttrs + " value='" + escapeHtml(strVal) + "' /></td>";
        }
    }
    
    static function attachCellHandlers(): Void {
        untyped __js__('
        $(".edit-cell").off("change").on("change", function(e) {
            var target = $(e.target);
            var row = parseInt(target.attr("data-row"));
            var col = parseInt(target.attr("data-col"));
            var value = null;
            
            if (target.hasClass("flag-check")) {
                var flag = parseInt(target.attr("data-flag"));
                var flagsCell = target.closest(".flags-cell");
                var currentFlags = 0;
                flagsCell.find(".flag-check").each(function() {
                    if ($(this).is(":checked")) {
                        currentFlags |= (1 << parseInt($(this).attr("data-flag")));
                    }
                });
                value = currentFlags;
            } else if (target.attr("type") === "checkbox" && !target.hasClass("flag-check")) {
                value = target.is(":checked");
            } else if (target.attr("type") === "number") {
                var num = parseFloat(target.val());
                if (!isNaN(num)) value = num;
            } else {
                value = target.val();
                if (value === "") value = null;
            }
            
            CastleDBApp.updateCell(row, col, value);
        });
        ');
    }
    
    static function escapeHtml(s: String): String {
        return StringTools.htmlEscape(s);
    }
    
    // ==================== Recent Files ====================
    
    public static function getRecentFiles(): Array<String> {
        try {
            var stored = js.Browser.getLocalStorage().getItem("castle_recent");
            if (stored != null) {
                return haxe.Unserializer.run(stored);
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
            js.Browser.getLocalStorage().setItem("castle_recent", haxe.Serializer.run(recent));
        } catch(e: Dynamic) {}
    }
}
