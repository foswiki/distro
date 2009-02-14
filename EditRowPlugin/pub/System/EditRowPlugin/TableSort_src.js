// Code from http://www.brainjar.com/
// License GPL 2
// Extended by Crawford Currie Copyright (C) 2007 http://c-dot.co.uk
//-----------------------------------------------------------------------------
// sortTable(id, col, rev)
//
//  tblEl - an element anywhere in the table
//  rev - If true, the column is sorted in reverse (descending) order
//        initially.
//  headrows - number of rows in table header (unsorted)
//  footrows number of rows in table footer (unsorted)
//
// Automatically detects and sorts data types; numbers and dates

function sortTable(el, rev, headrows, footrows) {

    // Search up to find the containing TD or TH
    var tdEl = el;
    while (tdEl != null &&
           tdEl.tagName.toUpperCase() != "TD" &&
           tdEl.tagName.toUpperCase() != "TH") {
        tdEl = tdEl.parentNode;
    }
    if (tdEl == null) {
        return;
    }

    // Continue up to the TR
    var trEl = tdEl;
    while (trEl != null && trEl.tagName.toUpperCase() != "TR") {
        trEl = trEl.parentNode;
    }
    if (trEl == null) {
        return;
    }

    // Continue to search up to find the containing table
    var tblEl = trEl;
    while (tblEl != null && tblEl.tagName.toUpperCase() != "TABLE") {
        tblEl = tblEl.parentNode;
    }
    if (tblEl == null) {
        return;
    }

    // Now work out the column index
    var col = 0;
    var i = 0;
    while (i < trEl.childNodes.length) {
        if (trEl.childNodes[i].tagName != null) {
            if (trEl.childNodes[i] == tdEl)
                break;
            col++;
        }
        i++;
    }
    if (i == trEl.childNodes.length) {
        return null;
    }

    // Find the TBODY, and work out the number of rows
    var tblBody = null;
    var gotBody = false;
    for (var i = 0; i < tblEl.childNodes.length; i++) {
        var tn = tblEl.childNodes[i].tagName;
        if (tn != null)
            tn = tn.toUpperCase();
        if (tn == "THEAD") {
            // Bloody TablePlugin generates footer rows in the THEAD!
            if (gotBody)
                footrows -= tblEl.childNodes[i].rows.length;
            else
                headrows -= tblEl.childNodes[i].rows.length;
        }
        else if (tn == "TBODY") {
            tblBody = tblEl.childNodes[i];
            gotBody = true;
        }
        else if (tn == "TFOOT") {
            footrows -= tblEl.childNodes[i].rows.length;
        }
    }

    // The first time this function is called for a given table, set up an
    // array of reverse sort flags.
    if (tblEl.reverseSort == null) {
        tblEl.reverseSort = new Array();
        // Also, assume the team name column is initially sorted.
        tblEl.lastColumn = 1;
    }
    
    // If this column has not been sorted before, set the initial sort direction.
    if (tblEl.reverseSort[col] == null)
        tblEl.reverseSort[col] = rev;
    
    // If this column was the last one sorted, reverse its sort direction.
    if (col == tblEl.lastColumn)
        tblEl.reverseSort[col] = !tblEl.reverseSort[col];
    
    // Remember this column as the last one sorted.
    tblEl.lastColumn = col;
    
    // Set the table display style to "none" - necessary for Netscape 6 
    // browsers.
    var oldDsply = tblEl.style.display;
    tblEl.style.display = "none";
    
    // Sort the rows based on the content of the specified column using a
    // selection sort.
    
    var tmpEl;
    var i, j;
    var minVal, minIdx;
    var testVal;
    var cmp;
    
    var start = (headrows > 0 ? headrows : 0);
    var end = tblBody.rows.length - (footrows > 0 ? footrows : 0);
    for (i = start; i < end - 1; i++) {
        
        // Assume the current row has the minimum value.
        minIdx = i;
        minVal = getTextValue(tblBody.rows[i].cells[col]);
        
        // Search the rows that follow the current one for a smaller value.
        for (j = i + 1; j < end; j++) {
            testVal = getTextValue(tblBody.rows[j].cells[col]);
            cmp = compareValues(minVal, testVal);
            // Negate the comparison result if the reverse sort flag is set.
            if (tblEl.reverseSort[col])
                cmp = -cmp;
            // If this row has a smaller value than the current minimum,
            // remember its position and update the current minimum value.
            if (cmp > 0) {
                minIdx = j;
                minVal = testVal;
            }
        }
        
        // By now, we have the row with the smallest value. Remove it from the
        // table and insert it before the current row.
        if (minIdx > i) {
            tmpEl = tblBody.removeChild(tblBody.rows[minIdx]);
            tblBody.insertBefore(tmpEl, tblBody.rows[i]);
        }
    }
    
    // Make it look pretty.
    // Not used, but kept for when TablePlugin uses classes.
    //makePretty(tblBody, col);
    
    // Restore the table's display style.
    tblEl.style.display = oldDsply;
    
    return false;
}

//-----------------------------------------------------------------------------
// Functions to get and compare values during a sort.
//-----------------------------------------------------------------------------

// This code is necessary for browsers that don't reflect the DOM constants
// (like IE).
if (document.ELEMENT_NODE == null) {
    document.ELEMENT_NODE = 1;
    document.TEXT_NODE = 3;
}

function getTextValue(el) {
    
    if (!el)
        return '';

    var i;
    var s;
    
    // Find and concatenate the values of all text nodes contained within the
    // element.
    s = "";
    for (i = 0; i < el.childNodes.length; i++)
        if (el.childNodes[i].nodeType == document.TEXT_NODE)
            s += el.childNodes[i].nodeValue;
        else if (el.childNodes[i].nodeType == document.ELEMENT_NODE &&
                 el.childNodes[i].tagName == "BR")
            s += " ";
        else
            // Use recursion to get text within sub-elements.
            s += getTextValue(el.childNodes[i]);
    
    return normalizeString(s);
}

var months = new Array();
months["jan"] = 0;
months["feb"] = 1;
months["mar"] = 2;
months["apr"] = 3;
months["may"] = 4;
months["jun"] = 5;
months["jul"] = 6;
months["aug"] = 7;
months["sep"] = 8;
months["oct"] = 9;
months["nov"] = 10;
months["dec"] = 11;

// "31 Dec 2003 - 23:59",
// "31-Dec-2003 - 23:59",
// "31/Dec/2003 - 23:59",
// "31/Dec/03 - 23:59",
var TWIKIDATE = new RegExp(
    "^\\s*([0-3]?[0-9])[-\\s/]*" +
    "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)" +
    "[-\\s/]*([0-9]{2}[0-9]{2}?)" +
    "(\\s*(-\\s*)?([0-9]{2}):([0-9]{2}))?", "i");
var RFC8601 = new RegExp(
    "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
    "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
    "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?");

// Convert date/time to epoch seconds. Return 0 if a valid date
// wasn't found.
function s2d(s) {
    // TWiki date/time
    var d = s.match(TWIKIDATE);
    if (d != null) {
        var nd = new Date();
        nd.setDate(Number(d[1]));
        nd.setMonth(months[d[2].toLowerCase()]);
        if (d[3].length == 2) {
            var year = d[3];
            // I'll be dead by the time this fails :-)
            if (year > 59)
                year += 1900;
            else
                year += 2000;
            nd.setYear(year);
        } else
            nd.setYear(d[3]);
        if (d[6] != null && d[6].length)
            nd.setHours(d[6]);
        if (d[7] != null && d[7].length)
            nd.setMinutes(d[7]);
        return nd.getTime();
    }

    // RFC8601 date/time
    // (Paul Sowden, http://delete.me.uk/2005/03/iso8601.html)
    var d = s.match(RFC8601);
    if (d == null)
        return 0;

    var offset = 0;
    var date = new Date(d[1], 0, 1);

    if (d[3])  date.setMonth(d[3] - 1);
    if (d[5])  date.setDate(d[5]);
    if (d[7])  date.setHours(d[7]);
    if (d[8])  date.setMinutes(d[8]);
    if (d[10]) date.setSeconds(d[10]);
    if (d[12]) date.setMilliseconds(Number("0." + d[12]) * 1000);
    if (d[14]) {
        offset = (Number(d[16]) * 60) + Number(d[17]);
        offset *= ((d[15] == '-') ? 1 : -1);
    }

    offset -= date.getTimezoneOffset();
    time = (Number(date) + (offset * 60 * 1000));
    return time;
}

function compareValues(v1, v2) {
    // if the values are both dates, convert them to epoch seconds
    var d1 = s2d(v1);
    if (d1) {
        var d2 = s2d(v2);
        if (d2) {
            v1 = d1;
            v2 = d2;
        }
    } else {
        // If the values are numeric, convert them to floats.
        var f1 = parseFloat(v1);
        if (!isNaN(f1)) {
            var f2 = parseFloat(v2);
            if (!isNaN(f2)) {
                v1 = f1;
                v2 = f2;
            }
        }
    }
    // Compare the two values.
    if (v1 == v2)
        return 0;
    if (v1 > v2)
        return 1;
    return -1;
}

// Regular expressions for normalizing white space.
var whtSpEnds = new RegExp("^\\s*|\\s*$", "g");
var whtSpMult = new RegExp("\\s\\s+", "g");

function normalizeString(s) {
    
    s = s.replace(whtSpMult, " ");  // Collapse any multiple whites space.
    s = s.replace(whtSpEnds, "");   // Remove leading or trailing white space.
    
    return s;
}

//-----------------------------------------------------------------------------
// Functions to update the table appearance after a sort.
// Not used, but kept for when TablePlugin uses classes.
//-----------------------------------------------------------------------------

/*
// Style class names.
var rowClsNm = "alternateRow";
var colClsNm = "sortedColumn";

// Regular expressions for setting class names.
var rowTest = new RegExp(rowClsNm, "gi");
var colTest = new RegExp(colClsNm, "gi");

function makePretty(tblEl, col) {
    
    var i, j;
    var rowEl, cellEl;
    
    // Set style classes on each row to alternate their appearance.
    for (i = 0; i < tblEl.rows.length; i++) {
        rowEl = tblEl.rows[i];
        rowEl.className = rowEl.className.replace(rowTest, "");
        if (i % 2 != 0)
            rowEl.className += " " + rowClsNm;
        rowEl.className = normalizeString(rowEl.className);
        // Set style classes on each column (other than the name column) to
        // highlight the one that was sorted.
        for (j = 2; j < tblEl.rows[i].cells.length; j++) {
            cellEl = rowEl.cells[j];
            cellEl.className = cellEl.className.replace(colTest, "");
            if (j == col)
                cellEl.className += " " + colClsNm;
            cellEl.className = normalizeString(cellEl.className);
        }
    }
    
    // Find the table header and highlight the column that was sorted.
    var el = tblEl.parentNode.tHead;
    if (el) {
        rowEl = el.rows[el.rows.length - 1];
        // Set style classes for each column as above.
        for (i = 2; i < rowEl.cells.length; i++) {
            cellEl = rowEl.cells[i];
            cellEl.className = cellEl.className.replace(colTest, "");
            // Highlight the header of the sorted column.
            if (i == col)
                cellEl.className += " " + colClsNm;
            cellEl.className = normalizeString(cellEl.className);
        }
    }
}
*/
