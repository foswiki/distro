// TWiki namespace
if (twiki == undefined) var twiki = {};

twiki.getMetaTag = function(inKey) {
    if (twiki.metaTags == null || twiki.metaTags.length == 0) {
        // Do this the brute-force way because of the problem
        // seen sporadically on Bugs web where the DOM appears complete, but
        // the META tags are not all found by getElementsByTagName
        var head = document.getElementsByTagName("META");
        head = head[0].parentNode.childNodes;
        twiki.metaTags = new Array();
        for (var i = 0; i < head.length; i++) {
            if (head[i].tagName != null &&
                head[i].tagName.toUpperCase() == 'META') {
                twiki.metaTags[head[i].name] = head[i].content;
            }
        }
    }
    return twiki.metaTags[inKey]; 
};

// Get all elements under root that have the given tag and include the
// given class
twiki.getElementsByClassName = function(root, tag, className) {
	var elms = root.getElementsByTagName(tag);
	className = className.replace(/\-/g, "\\-");
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

