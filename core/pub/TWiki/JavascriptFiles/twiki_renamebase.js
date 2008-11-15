/**
Checks/unchecks all checkboxes in form inForm.
*/
function checkAll(inForm, inState) {
	// find button element index
	if (inForm == undefined) return;
	var i, j = 0;
	for (i = 0; i < inForm.length; ++i) {
		if (inForm.elements[i].name.match("referring_topics")) {
			inForm.elements[i].checked = inState;
		}
	}
}