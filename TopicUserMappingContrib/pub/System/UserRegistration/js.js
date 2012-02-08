function makeWikiName(a, b, c) {
    $("input[name='Twk1WikiName']").val(
	foswiki.String.makeCamelCase(
	    $("input[name='Twk1FirstName']").val(),
	    $("input[name='Twk1LastName']").val()));
}
