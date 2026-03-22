# CastleDB QuickJS Extension

用於在 QuickJS JavaScript 引擎中方便地訪問 CastleDB (.cdb) 文件的原生擴展模組。

## 目錄結構

```
js/
├── cdb_quickjs.c      # QuickJS C 擴展（需要 QuickJS 庫）
├── cdb_module.js      # JavaScript 便捷包裝
├── test_cdb.js        # 測試腳本
└── Makefile           # 編譯腳本
```

## 安裝 QuickJS

### 使用 Homebrew (macOS)

```bash
brew install quickjs
```

### 從源碼編譯

```bash
git clone https://github.com/nicowillis/quickjs.git
cd quickjs
make
sudo make install
```

## 編譯擴展

```bash
cd js
make
```

需要 QuickJS 開發庫和頭文件。

## JavaScript API

### 基本用法

```javascript
// 加載模組
var CDB = require("./cdb_module.js").CDB;

// 打開數據庫
var db = CDB.open("game_data/item.cdb");

// 獲取工作表
var weapons = db.sheet("武器");
var items = db.sheet("消耗品");

// 遍歷行
for (var row of weapons.rows) {
    print(row.get("名稱"));  // 或使用 row.名稱
}

// 查找行
var sword = weapons.find(function(r) { 
    return r.get("武器類型") === "劍"; 
});

// 轉換為普通對象
var obj = sword.toObject();
print(obj.名稱, obj.物理傷害);
```

### API 參考

#### CDB.open(filename)
打開 CDB 文件。
- `filename`: .cdb 文件路徑
- 返回: `CDBDatabase` 實例

#### CDBDatabase

**方法:**
- `db.sheet(name)` - 根據名稱獲取工作表
- `db.getSheetNames()` - 獲取所有工作表名稱
- `db.getSheetCount()` - 獲取工作表數量
- `db.close()` - 關閉數據庫

**屬性:**
- `db.sheetCount` - 工作表數量

#### CDBSheet

**方法:**
- `sheet.getName()` - 獲取工作表名稱
- `sheet.getColumnCount()` - 獲取列數
- `sheet.getRowCount()` - 獲取行數
- `sheet.getRow(index)` - 根據索引獲取行
- `sheet.getRows()` - 獲取所有行
- `sheet.column(name)` - 根據名稱獲取列定義
- `sheet.find(predicate)` - 查找第一個匹配的行
- `sheet.filter(predicate)` - 過濾所有匹配的行
- `sheet.toArray()` - 轉換為 2D 數組

**屬性:**
- `sheet.name` - 工作表名稱
- `sheet.columns` - 列定義數組
- `sheet.rowCount` - 行數
- `sheet.rows` - 行數組

#### CDBRow

**方法:**
- `row.get(name)` - 根據列名獲取值
- `row.has(name)` - 檢查列是否有值（非空）
- `row.toObject()` - 轉換為普通 JavaScript 對象
- `row.getIndex()` - 獲取行索引

**屬性:**
- `row.index` - 行索引

**直接屬性訪問:**
```javascript
row.名稱      // 調用 row.get("名稱")
row.物理傷害  // 調用 row.get("物理傷害")
```

#### CDBColumn

**方法:**
- `col.getName()` - 獲取列名
- `col.getType()` - 獲取列類型（數字）
- `col.getTypeName()` - 獲取類型名稱字符串
- `col.getEnumValues()` - 獲取枚舉值（對於 TEnum/TFlags）
- `col.isOptional()` - 是否可選

**屬性:**
- `col.name` - 列名
- `col.type` - 類型數字
- `col.typeName` - 類型名稱字符串
- `col.enumValues` - 枚舉值數組
- `col.optional` - 是否可選

### 類型常量

```javascript
var T = require("./cdb_module.js").CDBTypes;

T.TID         // 0
T.TSTRING     // 1
T.TBOOL       // 2
T.TINT        // 3
T.TFLOAT      // 4
T.TENUM       // 5
T.TREF        // 6
T.TIMAGE      // 7
T.TLIST       // 8
T.TCUSTOM     // 9
T.TFLAGS      // 10
T.TCOLOR      // 11
T.TLAYER      // 12
T.TFILE       // 13
T.TTILEPOS    // 14
T.TTILELAYER  // 15
T.TDYNAMIC    // 16
T.TPROPERTIES  // 17
T.TGRADIENT    // 18
T.TCURVE      // 19
T.TGUID       // 20
T.TPOLYMORPH  // 21
```

## 完整範例

```javascript
var CDB = require("./cdb_module.js").CDB;

// 打開遊戲數據
var db = CDB.open("data/game.cdb");

// 打印所有武器
var weapons = db.sheet("武器");
print("=== 武器列表 ===");
for (var w of weapons.rows) {
    var obj = w.toObject();
    print(obj.id + ": " + obj.名稱);
    print("  傷害: " + obj.物理傷害 + " / " + obj.魔法傷害);
    print("  速度: " + obj.攻擊速度 + ", 價格: " + obj.價格);
}

// 查找傳說武器
var legendary = weapons.find(function(r) { 
    return r.get("稀有度") === "傳說"; 
});
if (legendary) {
    print("\n傳說武器: " + legendary.get("名稱"));
}

// 按類型分組
var swords = weapons.filter(function(r) { 
    return r.get("武器類型") === "劍"; 
});
print("\n劍類武器: " + swords.length + " 把");

// 關閉
db.close();
print("\n完成!");
```

## 測試

```bash
cd js

# 編譯（需要 QuickJS）
make

# 測試
qjs --addon build/cdb.so test_cdb.js

# 或使用便捷包裝
qjs -e "
var CDB = require('./cdb_module.js').CDB;
var db = CDB.open('../item.cdb');
print(db.getSheetNames());
db.close();
"
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
