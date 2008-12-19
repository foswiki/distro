package Foswiki::Configure::JS;

use strict;

use vars qw( $js1 $js2 );

sub js1 {
    local $/ = undef;
    return <DATA>;
}

sub js2 {
    return <<'HERE';
//<!--
document.write("<style type='text/css'>");
document.write(".foldableBlockClosed {display:none;}");
document.write("<\/style>");
//-->
HERE
}

1;
__DATA__
//<!--

var lastOpenBlock = null;
var lastOpenBlockLink = null;
var allBlocks = null; // array of all foldable blocks
var allBlockLinks = null; // array of all foldable block links (headers)

function foldBlock(id) {
    var shouldClose = false;
    var block = null;
    if (lastOpenBlock == null) {
        block = document.getElementById(id);
        if (block.open) {
            shouldClose = true;
        }
    }
    if (shouldClose) {
        closeBlock(id);
    } else {
        var o = openBlock(id);
        if (lastOpenBlock != null) {
            closeBlockElement(lastOpenBlock, lastOpenBlockLink);
        }
    }
    if (o && o.block) {
        lastOpenBlock = (lastOpenBlock == o.block) ? null : o.block;
    }
    if (o && o.blockLink) {
        lastOpenBlockLink = (lastOpenBlockLink == o.blockLink) ? null : o.blockLink;
    }
}

function openBlock(id) {
    var block = document.getElementById(id);
    var blockLink = document.getElementById('blockLink' + id);
    openBlockElement(block, blockLink);
    return {block:block, blockLink:blockLink};
}

function openBlockElement(block, blockLink) {
	var indicator = getElementsByClassName(blockLink, 'blockLinkIndicator')[0];
	indicator.innerHTML = '&#9660;';
    block.className = 'foldableBlock foldableBlockOpen';
    block.open = true;
    blockLink.className = 'blockLink blockLinkOn';
}

function closeBlock(id) {
    var block = document.getElementById(id);
    var blockLink = document.getElementById('blockLink' + id);
    closeBlockElement(block, blockLink);
    return {block:block, blockLink:blockLink};
}

function closeBlockElement(block, blockLink) {
	var indicator = getElementsByClassName(blockLink, 'blockLinkIndicator')[0];
	indicator.innerHTML = '&#9658;';
    block.className = 'foldableBlock foldableBlockClosed';
    block.open = false;
    blockLink.className = 'blockLink blockLinkOff';
}

function toggleAllOptions(open) {
    if (allBlocks == null) {
        allBlocks = getElementsByClassName(document, 'foldableBlock');
    }
    if (allBlockLinks == null) {
        allBlockLinks = getElementsByClassName(document, 'blockLink');
    }
    var i, ilen=allBlocks.length;
    if (open) {
        for (i=0; i<ilen; ++i) {
            openBlockElement(allBlocks[i], allBlockLinks[i]);
        }
    } else {
        for (i=0; i<ilen; ++i) {
            closeBlockElement(allBlocks[i], allBlockLinks[i]);
        }
    }
    lastOpenBlock = null;
    lastOpenBlockLink = null;
}

function getElementsByClassName(inRootElem, inClassName, inTag) {
	var tag = inTag || '*';
	var elms = inRootElem.getElementsByTagName(tag);
	var className = inClassName.replace(/\-/g, "\\-");
	var re = new RegExp("\\b" + className + "\\b");
	var el;
	var hits = new Array();
	for (var i = 0; i < elms.length; i++) {
		el = elms[i];
		if (re.test(el.className)) {
			hits.push(el);
		}
	}
	return hits;
}

function addLoadEvent (inFunction, inDoPrepend) {
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
			inFunction(); oldonload();
		};
		var appendFunc = function() {
			oldonload(); inFunction();
		};
		window.onload = inDoPrepend ? prependFunc : appendFunc;
	}
}

addLoadEvent(toggleAllOptions, 0);

//-->

