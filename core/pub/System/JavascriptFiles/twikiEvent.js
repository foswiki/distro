if (twiki == undefined) var twiki = {};
twiki.Event = {

	/**
	Chain a new load handler onto the existing handler chain
	Original code: http://simon.incutio.com/archive/2004/05/26/addLoadEvent
	Modified for TWiki
	@param inFunction : (Function) function to add
	@param inDoPrepend : (Boolean) if true: adds the function to the head of the handler list; otherwise it will be added to the end (executed last)
	*/
	addLoadEvent:function (inFunction, inDoPrepend) {
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
	
};
