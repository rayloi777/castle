# CastleDB QuickJS Extension

用於在 QuickJS JavaScript 引擎中方便地訪問 CastleDB (.cdb) 文件的原生擴展模組。

## 目錄結構

```
js/
├── cdb_quickjs.c      # QuickJS C 擴展綁定
├── cdb_module.js      # JavaScript 便捷包裝
├── test_cdb.js        # 測試腳本
├── test_cdb_main.c    # QuickJS 測試程序
├── Makefile           # 編譯腳本
└── build.sh           # 便捷構建腳本
```

## 編譯

### 使用 Makefile

```bash
cd js
make          # 編譯
make test_exe # 編譯並測試
make clean    # 清理
```

### 使用 build.sh

```bash
cd js
./build.sh    # 編譯並測試
```

### 獨立運行測試

```bash
cd js
./build/test_cdb ../../item.cdb
```

## JavaScript API

### 基本用法

```javascript
// 打開數據庫
var db = CDB.open("game_data/item.cdb");

// 獲取工作表
var weapons = db.sheet("武器");
var items = db.sheet("消耗品");

// 遍歷行
var rows = weapons.getRows();
for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var name = row.get("名稱");      // 按列名獲取值
    var obj = row.toObject();        // 轉換為普通 JS 對象
}

// 查找行
var sword = weapons.find(function(r) { 
    return r.get("武器類型") === "劍"; 
});

// 過濾行
var rare = weapons.filter(function(r) { 
    return r.get("稀有度") === "稀有"; 
});

// 關閉
db.close();
```

### API 參考

#### CDB.open(filename)

打開 CDB 文件。
- `filename`: .cdb 文件路徑
- 返回: `CDBDatabase` 實例

#### CDBDatabase

**方法:**
- `db.sheet(name)` - 根據名稱獲取工作表
- `db.getSheetNames()` - 獲取所有工作表名稱數組
- `db.getSheetCount()` - 獲取工作表數量
- `db.close()` - 關閉數據庫

#### CDBSheet

**方法:**
- `sheet.getName()` - 獲取工作表名稱
- `sheet.getColumnCount()` - 獲取列數
- `sheet.getColumnName(idx)` - 獲取指定索引的列名
- `sheet.getColumnType(idx)` - 獲取指定索引的列類型 (0-21)
- `sheet.getColumnEnumValues(idx)` - 獲取 TEnum/TFlags 的值數組
- `sheet.getRowCount()` - 獲取行數
- `sheet.getRows()` - 獲取所有行數組
- `sheet.getRow(index)` - 根據索引獲取行
- `sheet.column(name)` - 根據名稱獲取列定義
- `sheet.find(predicate)` - 查找第一個匹配的行
- `sheet.filter(predicate)` - 過濾所有匹配的行

#### CDBRow

**方法:**
- `row.get(name)` - 根據列名獲取值
- `row.has(name)` - 檢查列是否有值（非 null）
- `row.toObject()` - 轉換為普通 JavaScript 對象
- `row.getIndex()` - 獲取行索引

### 類型常量

```javascript
TID: 0, TSTRING: 1, TBOOL: 2, TINT: 3, TFLOAT: 4,
TENUM: 5, TREF: 6, TIMAGE: 7, TLIST: 8, TCUSTOM: 9,
TFLAGS: 10, TCOLOR: 11, TLAYER: 12, TFILE: 13, TTILEPOS: 14,
TTILELAYER: 15, TDYNAMIC: 16, TPROPERTIES: 17, TGRADIENT: 18,
TCURVE: 19, TGUID: 20, TPOLYMORPH: 21
```

## 完整範例

```javascript
var CDB = CDB || {};

// 打開遊戲數據
var db = CDB.open("data/item.cdb");

// 打印所有武器
var weapons = db.sheet("武器");
var rows = weapons.getRows();

print("=== 武器列表 ===");
for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var obj = row.toObject();
    print(obj.名稱 + " - ATK:" + obj.物理傷害);
}

// 查找傳說武器
var legendary = weapons.find(function(r) { 
    return r.get("稀有度") === "傳說"; 
});
if (legendary) {
    print("傳說武器: " + legendary.get("名稱"));
}

// 按類型分組
var swords = weapons.filter(function(r) { 
    return r.get("武器類型") === "劍"; 
});
print("劍類武器: " + swords.length + " 把");

// 關閉
db.close();
```

## 測試輸出格式

測試程序輸出與 C 語言示例相同的格式：

```
CastleDB C Reader Example
Version: 1.0.0
Opening: item.cdb
Successfully opened CDB file.
Sheets: 2

=== Available Sheets ===
  [0] 消耗品 (columns: 10, rows: 10)
  [1] 武器 (columns: 9, rows: 10)

========================================
Sheet: 消耗品
Columns: 10, Rows: 10
========================================

--- Column Info ---
  Column: id           Type: TId        (required)
  Column: 名稱           Type: TString    (required)
  Column: 稀有度          Type: TEnum      Values: [普通, 罕見, 稀有, 史詩, 傳說] (required)
  ...

--- Data Rows ---
...
```

## 性能提示

1. **避免重複調用 `toObject()`** - 每次調用都會創建新對象
2. **使用 `find()` 和 `filter()`** - C 擴展比純 JS 遍歷更快
3. **批量操作** - 對於大量數據，考虑一次性加載到數組

## 限制

- 目前不支持 `TList`、`TCustom`、`TPolymorph` 等嵌套類型的解析
- `TFlags` 返回字符串數組而不是位標誌
- 內存由 C 擴展管理，確保調用 `db.close()`

## 授權

ISC License - 見源文件頭部。
