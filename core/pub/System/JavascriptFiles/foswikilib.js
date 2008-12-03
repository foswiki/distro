// Foswiki namespace
var foswiki; if (foswiki == undefined) foswiki = {};

foswiki.getMetaTag = function(inKey) {
    if (foswiki.metaTags == null || foswiki.metaTags.length == 0) {
        // Do this the brute-force way because of the problem
        // seen sporadically on Bugs web where the DOM appears complete, but
        // the META tags are not all found by getElementsByTagName
        var head = document.getElementsByTagName("META");
        head = head[0].parentNode.childNodes;
        foswiki.metaTags = new Array();
        for (var i = 0; i < head.length; i++) {
            if (head[i].tagName != null &&
                head[i].tagName.toUpperCase() == 'META') {
                foswiki.metaTags[head[i].name] = head[i].content;
            }
        }
    }
    return foswiki.metaTags[inKey]; 
};

/**
Get all elements under root that include the given class.
@param inRootElem: HTMLElement to start searching from
@param inClassName: CSS class name to find
@param inTag: (optional) HTML tag to speed up searching (if not given, a wildcard is used to search all elements)
@example:
<code>
var gallery = document.getElementById('galleryTable');
var elems = foswiki.getElementsByClassName(gallery, 'personalPicture');
var firstPicture = elems[0];
</code>
*/
foswiki.getElementsByClassName = function(inRootElem, inClassName, inTag) {
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

