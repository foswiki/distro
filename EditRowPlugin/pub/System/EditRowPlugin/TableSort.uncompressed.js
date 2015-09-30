/**
 * Copyright (C) 2015 Foswiki Contributors
 * Author: Crawford Currie http://c-dot.co.uk
 *
 * sortTable(el, headrows, footrows, init)
 *
 * el - an element anywhere in the table
 * init - information about any presort
 *     col - column presorted on first call
 *     reverse - presort direction on first call, false = increasing,
 *               true = decreasing
 *
 * Automatically detects and sorts data types; numbers and dates
 */
function sortTable(el, init) {
    var $td = $(el).closest("td,th"),
    $tr = $td.closest("tr"),
    $table = $tr.closest("table"),
    $tbody = $table.children("tbody"),
    col = $td.index() + 1, // column index
    sort = $table.data("sort-data"),
    sortable = [],
    $rows = $table.children("thead,tbody,tfoot").children("tr");

    if (!sort) {
        sort = {
            reversed: [],
            last_col: init.col || -1
        };
        for (i = $tr.children().length; i > 0; i--)
            sort.reversed.push(false);

        if (typeof init.col !== "undefined")
            sort.reversed[init.col] = init.reverse;

        sort.bgs = 0;
        $rows.each(function() {
            var m = $(this).attr("class").match(/(foswikiTableRowdataBg(\d+))/);
            if (m) {
                var idx = Number.parseInt(m[2]) + 1;
                if (idx > sort.bgs)
                    sort.bgs = idx;
                $(this).removeClass(m[1]);
            }
        });
    }

    if (col === sort.last_col)
        sort.reversed[col] = !sort.reversed[col];

    var rev = sort.reversed[col];
    sort.last_col = col;

    $table
        .data("sort-data", sort)
        .find(".tableSortIcon")
        .remove();

    $tbody.children().each(function() {
        sortable.push($(this));
    });

    sortable.sort(function(a, b) {
        var av = a.children().eq(col-1).text(),
        bv = b.children().eq(col-1).text();

        return compareValues(av, bv) * (rev ? -1 : 1);
    });

//.foswikiTable tr.foswikiTableRowdataBg0 td.foswikiSortedCol
    // .tableSortIcon=  |The sort icon holder (span)  |

    $rows.children("td,th").removeClass(
        "foswikiSortedCol foswikiSortedAscendingCol "
        + "foswikiSortedDescendingCol foswikiTableEven foswikiTableOdd");

    $rows.each(function() {
        var m = $(this).attr("class").match(/(foswikiTableRowdataBg\d+)/);
        if (m)
            $(this).removeClass(m[1]);
        m = $(this).attr("class").match(/(foswikiTableRowdataBgSorted\d+)/);
        if (m)
            $(this).removeClass(m[1]);
    });

    $tbody.empty();
    // TablePlugin classes - databg. This is just too complex to correct.

    // .foswikiTableCol= + column number  | Unique column identifier, for instance: =foswikiTableCol0= |
    // .foswikiTableRow= + type + row number | Unique row identifier, for instance: =foswikiTableRowdataBg0= |
    $.each(sortable, function(index, $tr) {
        $tbody.append($tr);
    });

    // Get re-ordered rows
    $rows = $table.children("thead,tbody,tfoot").children("tr");
    $rows.removeClass("foswikiTableEven foswikiTableOdd");
    var index = 0;
    $rows.each(function() {
        $(this)
            .children("th,td").eq(col - 1) // get sorted column
            .addClass("foswikiSortedCol "
                      + "foswikiSorted"
                      + (rev ? "Descending" : "Ascending")
                      + "Col");

        if (sort.bgs > 0) {
            $(this).addClass(
                "foswikiTableRowdataBg" + (index % sort.bgs)
                    + " foswikiTableRowdataBgSorted" + (index % sort.bgs))
        }

        $(this).addClass("foswikiTable" +
                         (((index & 1) === 0) ? "Even" : "Odd"));
        index++;
    });

    $("<div></div>")
        .addClass("tableSortIcon ui-icon erp-button ui-icon-circle-triangle-" + 
                  (rev ? "s" : "n"))
        .attr("title", "Sorted " +
              (rev ? "descending" : "ascending"))
       .appendTo($td);
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
var WIKIDATE = new RegExp(
    "^\\s*([0-3]?[0-9])[-\\s/]*" +
    "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)" +
    "[-\\s/]*([0-9]{2}([0-9]{2})?)" +
    "(\\s*(-\\s*)?([0-9]{2}):([0-9]{2}))?", "i");
var RFC8601 = new RegExp(
    "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
    "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
    "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?");

// Convert date/time to epoch seconds. Return 0 if a valid date
// wasn't found.
function s2d(s) {
    // Wiki date/time
    var d = s.match(WIKIDATE);
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
    if (typeof v1 === "string")
        v1 = v1.normalize("NFKD");
    if (typeof v2 === "string")
        v2 = v2.normalize("NFKD");
    if (v1 == v2)
        return 0;
    if (v1 > v2)
        return 1;
    return -1;
}
