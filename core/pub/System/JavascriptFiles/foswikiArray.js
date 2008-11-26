/**
Array utility functions.
*/

var foswiki; if (foswiki == undefined) foswiki = {};
foswiki.Array = {

	/**
	Removes an object from an Array.
	@param inArray : (required) Array to remove object from
	@param inObject : (required) Object to remove from Array
	*/
	remove:function(inArray, inObject) {
		if (!inArray || !inObject) return null;
		for (i=0; i<inArray.length; i++) {
			if (inObject == inArray[i]) {
				inArray.splice(i, 1);
			}
		}
	},
	
	/**
	Creates an Array from a list of function arguments.
	@param inArguments : function arguments
	@param inStartIndex : (optional) the starting index in the list of function arguments
	@return A new Array with elements from the passed function arguments.
	@use
	The following code creates an Array of all arguments passed after inName:
	<pre>
	function releaseProps(inName) {
		var properties = foswiki.Array.convertArgumentsToArray(arguments, 1);
		if (!properties) return;
		_releaseProps(inName, properties);
	}
	</pre>
	*/
	convertArgumentsToArray:function(inArguments, inStartIndex) {
		if (inArguments == undefined) return null;
		var ilen = inArguments.length;
		if (ilen == 0) return null;
		var start = 0;
		if (inStartIndex) {
			if (isNaN(inStartIndex)) return null;
			if (inStartIndex > ilen-1) return null;
			start = inStartIndex;
		}		
		var list = [];
		for (var i = start; i < ilen; i++) {
			list.push(inArguments[i]);
		}
		return list;
	},
	
	
	/**
	Determine the index of the (first) occurrence of an object in an array.
	@param inArray : (Array) array to search
	@param el : (Object) the object to find
	@return The index number; -1 if the object is not found; null if no valid Array has been passed.
	*/
	indexOf:function(inArray, el) {
		if (!inArray || inArray.length == undefined) return null;
		var i, ilen = inArray.length;
		for (i=0; i<ilen; ++i) {
			if (inArray[i] == el) return i;
		}
		return -1;
	}
};
