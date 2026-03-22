/*
 * CastleDB QuickJS Module - JavaScript Convenience Wrapper
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

"use strict";

/**
 * Open a CDB file and return a CDBDatabase instance.
 * @param {string} filename - Path to the .cdb file
 * @returns {CDBDatabase}
 */
function openCDB(filename) {
    return CDB.open(filename);
}

/**
 * CDBDatabase class - represents an open CDB file
 */
class CDBDatabase {
    constructor() {
        this._db = null;
    }

    /**
     * Get sheet by name
     * @param {string} name - Sheet name
     * @returns {CDBSheet}
     */
    sheet(name) {
        return this._db.sheet(name);
    }

    /**
     * Get all sheet names
     * @returns {string[]}
     */
    getSheetNames() {
        return this._db.getSheetNames();
    }

    /**
     * Get number of sheets
     * @returns {number}
     */
    getSheetCount() {
        return this._db.sheetCount;
    }

    /**
     * Close the database
     */
    close() {
        if (this._db) {
            this._db.close();
            this._db = null;
        }
    }

    toString() {
        return `CDBDatabase(sheets: ${this.getSheetCount()})`;
    }
}

/**
 * CDBSheet class - represents a sheet/table in the database
 */
class CDBSheet {
    constructor() {
        this._sheet = null;
    }

    /**
     * Get sheet name
     * @returns {string}
     */
    getName() {
        return this._sheet.getName();
    }

    /**
     * Get column count
     * @returns {number}
     */
    getColumnCount() {
        return this._sheet.getColumns().length;
    }

    /**
     * Get row count
     * @returns {number}
     */
    getRowCount() {
        return this._sheet.getRowCount();
    }

    /**
     * Get all rows as an array
     * @returns {CDBRow[]}
     */
    getRows() {
        return this._sheet.getRows();
    }

    /**
     * Get row by index
     * @param {number} index 
     * @returns {CDBRow}
     */
    row(index) {
        return this._sheet.getRow(index);
    }

    /**
     * Get column by name
     * @param {string} name 
     * @returns {CDBColumn}
     */
    column(name) {
        const cols = this._sheet.getColumns();
        for (let col of cols) {
            if (col.getName() === name) {
                return col;
            }
        }
        return null;
    }

    /**
     * Find first row matching predicate
     * @param {function} predicate 
     * @returns {CDBRow|null}
     */
    find(predicate) {
        const rows = this.getRows();
        for (let row of rows) {
            if (predicate(row)) {
                return row;
            }
        }
        return null;
    }

    /**
     * Filter rows matching predicate
     * @param {function} predicate 
     * @returns {CDBRow[]}
     */
    filter(predicate) {
        const rows = this.getRows();
        return rows.filter(predicate);
    }

    /**
     * Convert to 2D array
     * @returns {Array[]}
     */
    toArray() {
        return this._sheet.toArray();
    }

    /**
     * Get raw sheet object (for advanced use)
     */
    get raw() {
        return this._sheet;
    }

    get name() { return this.getName(); }
    get columns() { return this._sheet.getColumns(); }
    get rowCount() { return this.getRowCount(); }
    get rows() { return this.getRows(); }

    toString() {
        return `CDBSheet(${this.getName()}, rows: ${this.getRowCount()})`;
    }

    /**
     * Iterator support
     */
    *[Symbol.iterator]() {
        const rows = this.getRows();
        for (let row of rows) {
            yield row;
        }
    }
}

/**
 * CDBColumn class - represents a column definition
 */
class CDBColumn {
    constructor() {
        this._col = null;
    }

    getName() {
        return this._col.getName();
    }

    getType() {
        return this._col.getType();
    }

    getTypeName() {
        return this._col.getTypeName();
    }

    getEnumValues() {
        return this._col.getEnumValues();
    }

    isOptional() {
        return this._col.isOptional();
    }

    get raw() {
        return this._col;
    }

    get name() { return this.getName(); }
    get type() { return this.getType(); }
    get typeName() { return this.getTypeName(); }
    get enumValues() { return this.getEnumValues(); }
    get optional() { return this.isOptional(); }

    toString() {
        return `CDBColumn(${this.getName()}, ${this.getTypeName()})`;
    }
}

/**
 * CDBRow class - represents a row of data
 */
class CDBRow {
    constructor() {
        this._row = null;
    }

    /**
     * Get value by column name
     * @param {string} name 
     * @returns {any}
     */
    get(name) {
        return this._row.get(name);
    }

    /**
     * Check if column has a value (not null)
     * @param {string} name 
     * @returns {boolean}
     */
    has(name) {
        return this._row.has(name);
    }

    /**
     * Convert to plain object
     * @returns {Object}
     */
    toObject() {
        return this._row.toObject();
    }

    /**
     * Get row index
     * @returns {number}
     */
    getIndex() {
        return this._row.getIndex();
    }

    get raw() {
        return this._row;
    }

    get index() { return this.getIndex(); }

    toString() {
        return `CDBRow(index: ${this.getIndex()})`;
    }

    /**
     * Property access by column name
     */
    __get(name) {
        return this._row.get(name);
    }
}

/**
 * Type constants
 */
const CDBTypes = {
    TID: 0,
    TSTRING: 1,
    TBOOL: 2,
    TINT: 3,
    TFLOAT: 4,
    TENUM: 5,
    TREF: 6,
    TIMAGE: 7,
    TLIST: 8,
    TCUSTOM: 9,
    TFLAGS: 10,
    TCOLOR: 11,
    TLAYER: 12,
    TFILE: 13,
    TTILEPOS: 14,
    TTILELAYER: 15,
    TDYNAMIC: 16,
    TPROPERTIES: 17,
    TGRADIENT: 18,
    TCURVE: 19,
    TGUID: 20,
    TPOLYMORPH: 21
};

/**
 * Export module
 */
module.exports = {
    CDB: {
        open: openCDB
    },
    CDBDatabase,
    CDBSheet,
    CDBColumn,
    CDBRow,
    CDBTypes
};
