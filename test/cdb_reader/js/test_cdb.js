/*
 * CastleDB QuickJS Test Script
 */

"use strict";

var CDB, db, weapons, consumables;

print("=== CastleDB QuickJS Test ===\n");

// Open database
print("Opening item.cdb...");
db = CDB.open("../item.cdb");
print("Database opened: " + db);
print("Sheet names: " + JSON.stringify(db.getSheetNames()));
print("Sheet count: " + db.getSheetCount());
print("");

// Get weapons sheet
print("Getting weapons sheet...");
weapons = db.sheet("武器");
print("Sheet: " + weapons);
print("Columns: " + weapons.columns.length);
print("Row count: " + weapons.rowCount);
print("");

// Print column info
print("=== Column Info ===");
for (var col of weapons.columns) {
    var info = col.name + " (" + col.typeName + ")";
    if (col.enumValues && col.enumValues.length > 0) {
        info += " = [" + col.enumValues.join(", ") + "]";
    }
    print("  " + info);
}
print("");

// Print all weapons
print("=== Weapons Data ===");
for (var row of weapons.rows) {
    var obj = row.toObject();
    print(obj.id + ": " + obj.名稱 + " (" + obj.武器類型 + ", " + obj.稀有度 + ")");
    print("  Damage: " + obj.物理傷害 + " phys / " + obj.魔法傷害 + " magic");
    print("  Speed: " + obj.攻擊速度 + ", Price: " + obj.價格);
}
print("");

// Find weapons
print("=== Find Examples ===");
var sword = weapons.find(function(r) { return r.get("武器類型") === "劍"; });
if (sword) {
    print("First sword: " + sword.get("名稱"));
}

var rare = weapons.filter(function(r) { return r.get("稀有度") === "稀有"; });
print("Rare weapons: " + rare.length);

var legendary = weapons.find(function(r) { return r.get("稀有度") === "傳說"; });
if (legendary) {
    print("Legendary: " + legendary.get("名稱") + " - " + legendary.get("物理傷害") + " phys damage!");
}
print("");

// Get consumables sheet
print("=== Consumables ===");
consumables = db.sheet("消耗品");
print("Sheet: " + consumables);
print("Row count: " + consumables.rowCount);
print("");

// Print consumables
for (var row of consumables.rows) {
    var obj = row.toObject();
    var recovery = [];
    if (obj.生命恢復 > 0) recovery.push("HP+" + obj.生命恢復);
    if (obj.魔法恢復 > 0) recovery.push("MP+" + obj.魔法恢復);
    if (obj.持續時間 > 0) recovery.push(obj.持續時間 + "s");
    print(obj.id + ": " + obj.名稱 + " - " + recovery.join(", ") + " [CD:" + obj.冷卻時間 + "s, Price:" + obj.價格 + "]");
}
print("");

// Cleanup
print("Closing database...");
db.close();
print("Done!");
