// sEditTable.js
//
// By Byron Darrah, Arthur Clemens
//
// This code adds support to the Foswiki EditTablesPlugin for dynamically
// manipulating rows within a table.

/**

*/
// Global variables

var sEditTable;
// array of edittables
var sRowSelection;
var sAlternatingColors = [];
var DEBUG = 0;

/**

*/
// Here's a custom version of getElementByTagName.  I find it easier
// to debug certain problems this way when a script doesn't seem to be
// finding the node we'd expect.

function searchNodeTreeForTagName(node, tag_name) {
    if (node.tagName == tag_name) {
        return node;
    }
    for (var child = node.firstChild; child != null; child = child.nextSibling) {
        var r = searchNodeTreeForTagName(child, tag_name);
        if (r != null) {
            return r;
        }
    }
}

function hasClass(el, className) {
    if (!el || !className)
        return;
    var re = new RegExp('(?:^|\\s+)' + className + '(?:\\s+|$)');
    return re.test(el['className']);
}
function addClass(el, className) {
    if (!el || !className)
        return;
    if (hasClass(el, className)) {
        return;
    }
    // already present
    el['className'] = [el['className'], className].join(' ');
}
function removeClass(el, className) {
    if (!el || !className)
        return;
    if (!hasClass(el, className)) {
        return;
    }
    // not present
    
    var re = new RegExp('(?:^|\\s+)' + className + '(?:\\s+|$)', 'g');
    var c = el['className'];
    el['className'] = c.replace(re, ' ');
}

/**
Create user control elements and initialize table manipulation objects.
*/

// Build the list of edittables.
function edittableInit(form_name, asset_url, headerRows, footerRows) {
    
    // The form we want is actually the second thing in the
    // document that has the form_name.
    var forms = document.getElementsByName(form_name);
    var tableform = forms[1];
    
    if (tableform == null) {
        alert("Something went wrong: EditTable javascript features cannot be enabled.\n");
        return;
    }
    attachEvent(tableform, 'submit', submitHandler);
    
    var somerow = searchNodeTreeForTagName(tableform, "TR");
    
    if (somerow != null) {
        var row_container = somerow.parentNode;
        sEditTable = new EditTableObject(tableform, row_container);
    }
	sEditTable.headerRows = headerRows;
	sEditTable.footerRows = footerRows;
	 if (somerow != null) {
		insertActionButtons(asset_url);
        insertRowSeparators();
    }
    sRowSelection = new RowSelectionObject(asset_url);
    retrieveAlternatingRowColors();
    fixStyling();
}

/**

*/
// Create the etrow_id# inputs to tell the server about row changes we made.
function submitHandler(evt) {
	if (!evt) var evt = window.event;

	var ilen = sEditTable.numrows;

	var DEBUG_TXT = "";
    for (var rowpos = 0; rowpos < ilen; rowpos++) {
        var inpname = 'etrow_id' + (rowpos + 1);
        var row_id = sEditTable.revidx[rowpos] + 1;
        if (!row_id) continue;
        DEBUG_TXT += rowpos + ",row_id=" + row_id + ";";
        var inp = document.createElement('INPUT');
        inp.setAttribute('type', 'hidden');
        inp.setAttribute('name', inpname);
        inp.setAttribute('value', '' + row_id);
        sEditTable.tableform.appendChild(inp);
    }
	if (DEBUG) alert(DEBUG_TXT);
    return true;
}

/**

*/
function attachEvent(obj, evtype, handler) {
	if (!handler) return;
	if (window.addEventListener) {
        // Mozilla, Netscape, Firefox
        obj.addEventListener(evtype, handler, false);
    } else {
        // IE
        obj.attachEvent('on' + evtype, handler);
    }
}

/**

*/
function detachEvent(obj, evtype, handler) {
    if (window.addEventListener) {
        // Mozilla, Netscape, Firefox
        obj.removeEventListener(evtype, handler, false);
    } else {
        // IE
        obj.detachEvent('on' + evtype, handler);
    }
}

/**

*/
function getEventAttr(evt, pname) {
    var e_out;
    var ie_var = "srcElement";
    var moz_var = "target";
    // "target" for Mozilla, Netscape, Firefox et al. ; "srcElement" for IE
    evt[moz_var] ? e_out = evt[moz_var][pname] : e_out = evt[ie_var][pname];
    return e_out;
}

/**

*/
function insertActionButtons(asset_url) {
    insertActionButtonsMove(asset_url);
    insertActionButtonsDelete(asset_url);
}

/**

*/
function insertActionButtonsMove(asset_url) {
    
    // do not show a move button for just one row
    if (sEditTable.numrows <= 1 ) return;
    
    var action_cell, action_butt;
    
    for (var rowpos = 0; rowpos < sEditTable.numrows; rowpos++) {
        var rownr = sEditTable.revidx[rowpos];
        var child = sEditTable.rows[rownr];
        if (child.tagName == 'TR') {
        	var isHeaderRow = (rowpos < sEditTable.headerRows);
        	var isFooterRow = (rowpos < sEditTable.headerRows + sEditTable.footerRows); // footer rows are written just below the header, and before the body
        	if (isHeaderRow || isFooterRow) {
        	    action_cell = document.createElement('TH');
        	    action_butt = document.createElement('SPAN');
        	} else {
	            action_cell = document.createElement('TD');
	            action_butt = createActionButtonMove(asset_url, rownr);
				action_cell.moveButton = action_butt;
				addClass(action_cell, 'editTableActionCell');
	        }
			action_cell.id = 'et_actioncell' + rownr;
			action_cell.appendChild(action_butt);
            child.insertBefore(action_cell, child.firstChild);
        }
    }
    // set styling for the last action_cell to remove the bottom border
    //addClass(action_cell, 'foswikiLast');
}

function createActionButtonMove (asset_url, rownr) {
	var action_butt = document.createElement('IMG');
	action_butt.setAttribute('title', 'Move row');
	action_butt.enableButtonSrc = asset_url + '/btn_move.gif';
	action_butt.disableButtonSrc = asset_url + '/btn_move_disabled.gif';
	action_butt.hoverButtonSrc = asset_url + '/btn_move_over.gif';
	action_butt.moveButtonSrc = asset_url + '/btn_move.gif';
	action_butt.setAttribute('src', action_butt.enableButtonSrc);
	
	action_butt.mohandler = mouseOverButtonHandler;
	attachEvent(action_butt, 'mouseover', action_butt.mohandler);
	action_butt.mouthandler = mouseOutButtonHandler;
	attachEvent(action_butt, 'mouseout', action_butt.mouthandler);
	
	action_butt.handler = moveHandler;
	attachEvent(action_butt, 'click', action_butt.handler);
	addClass(action_butt, 'editTableActionButton');
	action_butt.rownr = rownr;
	return action_butt;
}

/**

*/
function insertActionButtonsDelete(asset_url) {
    
    var action_cell, action_butt;
    
    for (var rowpos = 0; rowpos < sEditTable.numrows; rowpos++) {
        var rownr = sEditTable.revidx[rowpos];
        var child = sEditTable.rows[rownr];
        if (child.tagName == 'TR') {
        	var isHeaderRow = (rowpos < sEditTable.headerRows);
        	var isFooterRow = (rowpos < sEditTable.headerRows + sEditTable.footerRows); // footer rows are written just below the header, and before the body
        	if (isHeaderRow || isFooterRow) {
        	    action_cell = document.createElement('TH');
        	    action_butt = document.createElement('SPAN');
        	} else {
	            action_cell = document.createElement('TD');
	            action_butt = createActionButtonDelete(asset_url, rownr);
				action_cell.moveButton = action_butt;
				addClass(action_cell, 'editTableActionCell');
	        }
			action_cell.id = 'et_actioncell' + rownr;			
			action_cell.deleteButton = action_butt;
			action_cell.appendChild(action_butt);
            insertAfter(action_cell, child.lastChild);
        }
    }
    // set styling for the last action_cell to remove the bottom border
    addClass(action_cell, 'foswikiLast');
}

function createActionButtonDelete (asset_url, rownr) {
	
	var action_butt = document.createElement('IMG');
	action_butt.setAttribute('title', 'Delete row');
	action_butt.enableButtonSrc = asset_url + '/btn_delete.gif';
	action_butt.disableButtonSrc = asset_url + '/btn_delete_disabled.gif';
	action_butt.hoverButtonSrc = asset_url + '/btn_delete_over.gif';
	action_butt.setAttribute('src', action_butt.enableButtonSrc);
	
	action_butt.mohandler = mouseOverButtonHandler;
	attachEvent(action_butt, 'mouseover', action_butt.mohandler);
	action_butt.mouthandler = mouseOutButtonHandler;
	attachEvent(action_butt, 'mouseout', action_butt.mouthandler);
	
	action_butt.handler = deleteHandler;
	attachEvent(action_butt, 'click', action_butt.handler);
	
	addClass(action_butt, 'editTableActionButton');
	action_butt.rownr = rownr;
	return action_butt;
}


/**

*/
function insertRowSeparators() {
    
    var child;
    var sep_row,
    columns;
    
    for (var rowpos = 0; rowpos < sEditTable.numrows; rowpos++) {
        var rownr = sEditTable.revidx[rowpos];
        var isHeaderRow = (rowpos < sEditTable.headerRows);
		var isFooterRow = (rowpos < sEditTable.headerRows + sEditTable.footerRows); // footer rows are written just below the header, and before the body
		if (isHeaderRow || isFooterRow) {
			//
		} else {
			child = sEditTable.rows[rownr];
			columns = countRowColumns(child);
			sep_row = makeSeparatorRow(rownr, columns);
			child.parentNode.insertBefore(sep_row, child);
		}
    }
    sep_row = makeSeparatorRow(null, columns);
    child.parentNode.appendChild(sep_row);
    sEditTable.last_separator = sep_row;
}

/**

*/
function makeSeparatorRow(rownr, columns) {
    var sep_row = document.createElement('TR');
    var sep_cell = document.createElement('TD');
    sep_cell.colSpan = columns;
    sep_cell.colSpan = columns;
    sep_cell.style.padding = '0px';
    sep_cell.style.spacing = '0px';
    sep_cell.style.border = '0px';
    sep_cell.style.height = '0px';
    sep_cell.rownr = rownr;
    
    sep_row.rownr = rownr;
    sep_row.appendChild(sep_cell);
    sep_row.cell = sep_cell;
    addClass(sep_row, 'editTableRowSeparator');
    sep_row.id = 'et_rowseparator' + rownr;
    sep_row.ckhandler = sepClickHandler;
    sep_row.mohandler = sepMouseOverHandler;
    sep_row.mouthandler = sepMouseOutHandler;
    attachEvent(sep_row, 'click', sep_row.ckhandler);
    attachEvent(sep_row, 'mouseover', sep_row.mohandler);
    attachEvent(sep_row, 'mouseout', sep_row.mouthandler);
    return sep_row;
}

/**

*/
function countRowColumns(row_el) {
    var count = 0;
    for (var tcell = row_el.firstChild; tcell != null; tcell = tcell.nextSibling) {
        if (tcell.tagName == 'TD' || tcell.tagName == 'TH') {
            count += tcell.colSpan;
        }
    }
    return count;
}

/**

*/
function selectRow(rownr) {
    if (rownr == null && sRowSelection.row == null) {
        return;
    }
    var top_image = "none";
    var bottom_image = "none";
    
    
    if (rownr != null) {
        sRowSelection.row = sEditTable.rows[rownr];
        sRowSelection.rownum = rownr;
        //		top_image            = "url(" + sRowSelection.topImage + ")";
        //		bottom_image         = "url(" + sRowSelection.bottomImage + ")";
        
        var sep_row = sRowSelection.row.previousSibling;
        sRowSelection.topSep = sep_row;
        
        var next_rowpos = sEditTable.positions[rownr] + 1;
        if (next_rowpos < sEditTable.numrows) {
            var next_rownr = sEditTable.revidx[next_rowpos];
            sep_row = sEditTable.rows[next_rownr].previousSibling;
        } else {
            sep_row = sEditTable.last_separator;
        }
        sRowSelection.bottomSep = sep_row;
    }
    
    /* Set the style class of data cell elements in the selected row */
    
    var tableCells = sRowSelection.row.getElementsByTagName('TD');
    for (var i = 0; i < tableCells.length;++i) {
        if (rownr != null) {
            addClass(tableCells[i], 'editTableActionSelectedCell');
        } else {
            removeClass(tableCells[i], 'editTableActionSelectedCell');
        }
    }
    
    
    /* Place images of moving dashes above and below the selected row */
    
    if (sRowSelection.topSep != null) {
        var sepCells = sRowSelection.topSep.getElementsByTagName('TD');
        sepCells[0].style.backgroundImage = top_image;
        sepCells[0].style.backgroundRepeat = "repeat-x";
    }
    if (sRowSelection.bottomSep != null) {
        var sepCells = sRowSelection.bottomSep.getElementsByTagName('TD');
        sepCells[0].style.backgroundImage = bottom_image;
        sepCells[0].style.backgroundRepeat = "repeat-x";
    }
    if (rownr == null) {
        sRowSelection.row = null;
        sRowSelection.rownum = null;
        sRowSelection.topSep = null;
        sRowSelection.bottomSep = null;
    }
}

function mouseOverButtonHandler(evt) {
    var target = evt.srcElement ? evt.srcElement: evt.target;
	target.src = target['hoverButtonSrc'];
}

function mouseOutButtonHandler(evt) {
    var target = evt.srcElement ? evt.srcElement: evt.target;
	target.src = target['enableButtonSrc'];
}

/**
TODO: explorer fires twice, so nothing happens visually
*/
function moveHandler(evt) {
    
    if (sRowSelection.rownum != null) {
        // switch back
        sRowSelection.rownum = null;
        selectRow(null);
        switchDeleteButtons(evt);
        switchMoveButtons(evt);
        removeSeparatorAnimation();
        return;
    }
    var rownr = getEventAttr(evt, 'rownr');
    selectRow(rownr);
    switchDeleteButtons(evt);
    switchMoveButtons(evt);
    addSeparatorAnimation();
}

function addSeparatorAnimation() {
	addClass(sEditTable.rows[0].parentNode.parentNode, 'editTableMoveMode');
}

function removeSeparatorAnimation() {
	removeClass(sEditTable.rows[0].parentNode.parentNode, 'editTableMoveMode');
}

/**

*/
function sepClickHandler(evt) {	
    var rownr = getEventAttr(evt, 'rownr');
    if (sRowSelection.rownum == null) {
        return;
    }
    moveRow(sRowSelection.rownum, rownr);
    selectRow(null);
    switchDeleteButtons(evt);
    switchMoveButtons(evt);
    removeSeparatorAnimation();
}

/**

*/
function sepMouseOverHandler(evt) {
    var target = evt.srcElement ? evt.srcElement: evt.target;
    if (sRowSelection.rownum == null) {
        removeClass(target, 'editTableRowSeparatorHover');
    } else {
        addClass(target, 'editTableRowSeparatorHover');
    }
}

function sepMouseOutHandler(evt) {
    var target = evt.srcElement ? evt.srcElement: evt.target;
    removeClass(target, 'editTableRowSeparatorHover');
}

/**

*/
function switchDeleteButtons(evt) {
    var rownr = getEventAttr(evt, 'rownr');
    var mode = (sRowSelection.rownum == null) ? 'to_enable': 'to_disable';
    var ilen = sEditTable.rows.length;
    for (var i = 0; i < ilen;++i) {
        var row_elem = sEditTable.rows[i];
        var action_cell = row_elem.lastChild;
        var deleteButton = action_cell.deleteButton;
        if (!deleteButton) continue;
        if (mode == 'to_enable') {
            deleteButton.src = deleteButton['enableButtonSrc'];
            attachEvent(deleteButton, 'click', deleteButton.handler);
        } else {
            deleteButton.src = deleteButton['disableButtonSrc'];
            detachEvent(deleteButton, 'click', deleteButton.handler);
        }
    }
}

/**
Enables/disabled the move buttons.
Disabling: except for the row that has been selected.
*/
function switchMoveButtons(evt) {
    var rownr = getEventAttr(evt, 'rownr');
    var mode = (sRowSelection.rownum == null) ? 'to_enable': 'to_disable';
    var ilen = sEditTable.rows.length;
    for (var i = 0; i < ilen;++i) {
        var buttonMode = mode;
        if (mode == 'to_disable' && i == sRowSelection.rownum) {
            buttonMode = 'to_enable';
        }
        var row_elem = sEditTable.rows[i];
        var action_cell = row_elem.firstChild;
        var moveButton = action_cell.moveButton;
        if (!moveButton) continue;
        if (buttonMode == 'to_enable') {
            moveButton.src = moveButton['enableButtonSrc'];
            attachEvent(moveButton, 'click', moveButton.handler);
        } else {
            moveButton.src = moveButton['disableButtonSrc'];
            detachEvent(moveButton, 'click', moveButton.handler);
        }
    }
}

/**

*/
function deleteHandler(evt) {
    var rownr = getEventAttr(evt, 'rownr');
    var from_row_pos = sEditTable.positions[rownr];
    
    // Remove the from_row from the table.
    
    var from_row_elem = sEditTable.rows[rownr];
    from_row_elem.parentNode.removeChild(from_row_elem.previousSibling);
    from_row_elem.parentNode.removeChild(from_row_elem);
    
    // Update all rows after from_row.
    
    for (var rowpos = from_row_pos + 1; rowpos < sEditTable.numrows; rowpos++) {
        var rownum = sEditTable.revidx[rowpos];
        var newpos = rowpos - 1;
        sEditTable.positions[rownum] = newpos;
        sEditTable.revidx[newpos] = rownum;
        updateRowlabels(rownum, -1);
    }
    
    if (sRowSelection.rownum == rownr) {
        selectRow(null);
    }

    sEditTable.numrows--;
    sEditTable.tableform.etrows.value = sEditTable.numrows - (sEditTable.headerRows + sEditTable.footerRows);
    
    fixStyling();
}

/**
to write
*/
function addHandler() {
    //
    
}

/**

*/
function retrieveAlternatingRowColors() {
	if (!sEditTable) return;
    var ilen = sEditTable.numrows;
    for (var i = 0; i < ilen;++i) {
        var tr = sEditTable.rows[i];
        var tableCells = tr.getElementsByTagName('TD');
        var alternate = (i % 2 == 0) ? 0: 1;
        for (var j = 0; j < tableCells.length;++j) {
            if (sAlternatingColors[0] != null && sAlternatingColors[1] != null)
                continue;
            var color = tableCells[j].getAttribute('bgColor');
            if (color)
                sAlternatingColors[alternate] = color;
        }
        if (sAlternatingColors[0] != null && sAlternatingColors[1] != null) {
            return;
        }
    }
}

/**
Style the last row.
*/
function fixStyling() {
	if (!sEditTable) return;
    // style even/uneven rows
    var ilen = sEditTable.numrows;
    for (var i = 0; i < ilen; i++) {
        var num = sEditTable.revidx[i];
        var tr = sEditTable.rows[num];
        var tableCells = tr.getElementsByTagName('TD');
        var alternate = (i % 2 == 0) ? 0: 1;
        var className = (i % 2 == 0) ? 'foswikiTableEven': 'foswikiTableOdd';
        
        
        if (!sAlternatingColors[alternate]) {
            continue;
        }
        removeClass(tr, 'foswikiTableEven');
        removeClass(tr, 'foswikiTableOdd');
        addClass(tr, className);
        
        
        for (var j = 0; j < tableCells.length;++j) {
            var cell = tableCells[j];
            removeClass(cell, 'foswikiLast');
            addClass(cell, className);
            cell.removeAttribute('bgColor');
            cell.setAttribute('bgColor', sAlternatingColors[alternate]);
        }
    }
    
    // style last row
    
    var lastRowNum = sEditTable.revidx[sEditTable.numrows - 1];
    var lastRowElement = sEditTable.rows[lastRowNum];
    var tableCells = lastRowElement.getElementsByTagName('TD');
    for (var i = 0; i < tableCells.length;++i) {
        addClass(tableCells[i], 'foswikiLast');
    }
    
    
}

/**

*/
function moveRow(from_row, to_row) {
	if (!sEditTable) return;
    var from_row_pos = sEditTable.positions[from_row];
    var to_row_pos;

    // If the end separator row was selected, use the last row.
    
    if (to_row == null) {
        to_row_pos = sEditTable.numrows - 1;
        to_row = sEditTable.revidx[to_row_pos];
    } else {
        to_row_pos = sEditTable.positions[to_row];
        if (to_row_pos > from_row_pos) {
            to_row_pos--;
            to_row = sEditTable.revidx[to_row_pos];
        }
    }
    
    
    var inc = 1;
    if (to_row_pos == -1 || from_row_pos > to_row_pos) {
        inc = -1;
    }
    if (from_row == to_row) {
        return;
    }
    
    
    // Remove the from_row from the table.
    
    var from_row_elem = sEditTable.rows[from_row];
    var from_row_sep = from_row_elem.previousSibling;
    workaroundIECheckboxBug(from_row_elem);
    from_row_elem.parentNode.removeChild(from_row_sep);
    from_row_elem.parentNode.removeChild(from_row_elem);
    
    
    // Update all rows after from_row up to to_row.
    
    for (var rowpos = from_row_pos + inc; rowpos != to_row_pos + inc; rowpos += inc) {
        var rownum = sEditTable.revidx[rowpos];
        var newpos = rowpos - inc;
        sEditTable.positions[rownum] = newpos;
        sEditTable.revidx[newpos] = rownum;
        updateRowlabels(rownum, -inc);
    }
    
    
    var insertion_target;
    if (inc == 1) {
        insertion_target = sEditTable.rows[to_row]
            insertAfter(from_row_elem, insertion_target);
        insertAfter(from_row_sep, insertion_target);
    } else {
        insertion_target = sEditTable.rows[to_row].previousSibling;
        insertBefore(from_row_sep, insertion_target);
        insertBefore(from_row_elem, insertion_target);
    }
    sEditTable.positions[from_row] = to_row_pos;
    sEditTable.revidx[to_row_pos] = from_row;
    updateRowlabels(from_row, to_row_pos - from_row_pos);
    fixStyling();
}

/**

*/
function insertAfter(newnode, oldnode) {
    var parent = oldnode.parentNode;
    if (oldnode.nextSibling == null) {
        parent.appendChild(newnode);
    } else {
        parent.insertBefore(newnode, oldnode.nextSibling);
    }
}

/**

*/
function insertBefore(newnode, oldnode) {
    oldnode.parentNode.insertBefore(newnode, oldnode);
}

/**

*/
// IE will reset checkboxes to their default state when they are moved around
// in the DOM tree, so we have to override the default state.

function workaroundIECheckboxBug(container) {
    var elems = container.getElementsByTagName('INPUT');
    for (var i = 0; elems[i] != null; i++) {
        var inp = elems[i];
        if (inp['type'] == 'radio') {
            inp['defaultChecked'] = inp['checked'];
        }
    }
}

/**

*/

function RowSelectionObject(asset_url) {
    this.row = null;
    this.rownum = null;
    this.topSep = null;
    this.bottomSep = null;
    return this;
}

/**
Construct an EditTable object.  This includes building an array of all the
rows in a table, and making a map of row numbers to row positions (and the
reverse).
*/

function EditTableObject(tableform, row_container) {
    this.tableform = tableform;
    this.rows = new Array();
    this.positions = new Array();
    this.revidx = new Array();
    this.numrows = 0;
    this.headerRows = 0;
    this.footerRows = 0;
    this.last_separator = null;
    var got_thead = 0;
    var first_head = 0;
    
    
    // If rows are contained in <THEAD> and <TBODY> elements, then we must be
    // sure to iterate over all of them.
    
    while (row_container != null) {
      
        // If there were any rows before the first thead, we'll have to correct
        // our notion of the row positions, because browsers display the header
        // above the body instead of in the order they appear in the DOM.
        
        if (row_container.tagName == "THEAD" && got_thead == 0) {
            first_head = this.numrows;
            got_thead = 1;
        }

        var row_elem = row_container.firstChild;
        while (row_elem != null) {
            if (row_elem.tagName == "TR") {
                this.rows[this.numrows] = row_elem;
                this.positions[this.numrows] = this.numrows - first_head;
                this.revidx[this.numrows - first_head] = this.numrows;
                this.numrows++;
            }
            row_elem = row_elem.nextSibling;
        }
        
        // Now make any necessary position adjustments to account for an
        // out-of-order THEAD.
      
        if (first_head > 0) {
            var num_headrows = this.numrows - first_head;
            for (var body_rownum = 0; body_rownum < first_head; body_rownum++) {
                this.positions[body_rownum] = body_rownum + num_headrows;
                this.revidx[body_rownum + num_headrows] = body_rownum;
            }
            first_head = 0;
        }     
        
        row_container = row_container.nextSibling;
    }
    return this;
}

/**

*/
// Update all row labels in a row by adding a delta amount to each one.

function updateRowlabels(rownum, delta) {
	if (!sEditTable) return;
    var row = sEditTable.rows[rownum];
    var label_nodes = row.getElementsByTagName('DIV');

    for (var i = 0; label_nodes[i] != null; i++) {
        var lnode = label_nodes[i];
        if (lnode.className == 'et_rowlabel') {
            var input_node = lnode.getElementsByTagName('INPUT').item(0);
            var new_val = parseInt(input_node.value);
            if (isNaN(new_val)) {
                new_val = '????';
            } else {
                new_val = '' + (new_val + delta);
            }
            input_node.value = new_val;
            while (lnode.firstChild != null) {
                lnode.removeChild(lnode.firstChild);
            }
            // Create a new row label span to replace the old one.
            
            var new_text = document.createTextNode(new_val);
            lnode.appendChild(new_text);
            lnode.appendChild(input_node);
        }
    }
    
    
}

/**
Grabs the values from <meta> tags and inits the table with the table id and topic url.
*/
function init() {
    var noJavascript = foswiki.getMetaTag('EDITTABLEPLUGIN_NO_JAVASCRIPTINTERFACE_EditTableId');
	if (noJavascript) return;
    var currentFormName = foswiki.getMetaTag('EDITTABLEPLUGIN_FormName');
    var url = foswiki.getMetaTag('EDITTABLEPLUGIN_EditTableUrl');
    var headerRows = parseInt(foswiki.getMetaTag('EDITTABLEPLUGIN_headerRows'));
    var footerRows = parseInt(foswiki.getMetaTag('EDITTABLEPLUGIN_footerRows'));
    edittableInit(currentFormName, url, headerRows, footerRows);
}

/**
Copied from foswikiEvent.js.
*/
function addLoadEvent(inFunction, inDoPrepend) {
    if (typeof(inFunction) != "function") {
        return;
    }
    var oldonload = window.onload;
    if (typeof window.onload != 'function') {
        window.onload = function() {
            inFunction();
        };
    } else {
        var prependFunc = function() {
            inFunction();
            oldonload();
        };
        var appendFunc = function() {
            oldonload();
            inFunction();
        };
        window.onload = inDoPrepend ? prependFunc: appendFunc;
    }
}

addLoadEvent(init);

/**

*/
// EOF: sEditTable.js
