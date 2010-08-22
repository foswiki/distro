/**
 * Checks if the entered topic name is a valid WikiWord.
 * If so, enables the submit button, if not: enables the submit button if the
 * user allows non-WikiWords as topic name; otherwise disables the submit
 * button and returns 'false'.
 * Automatically removes spaces from entered name.
 * Automatically strips illegal characters.
 * If non-WikiWords are not allowed, capitalizes words (separated by space).
 * If non-WikiWords _are_ allowed, capitalizes sentence.
 * The generated topic name is written to a 'feedback' field.
 * @param inForm : pointer to the form
 * @param inShouldConvertInput : true: a new name is created from the
 * entered name
 * @return True: submit is enabled and topic creation is allowed; false:
 * submit is disabled and topic creation should be inhibited.
 */
function canSubmit(inForm, inShouldConvertInput) {

	var inputForTopicName = inForm.topic.value;

	/* Topic names of zero length are not allowed */
	if (inputForTopicName.length == 0) {
		disableSubmit(inForm.submit);
		/* Update feedback field */
		$("#webTopicCreatorFeedback").html("");
		return false;
	}
	
	var hasNonWikiWordCheck = (inForm.nonwikiword != undefined);
	var userAllowsNonWikiWord = true;
	if (hasNonWikiWordCheck) {
		userAllowsNonWikiWord = inForm.nonwikiword.checked;
	}
	
	/* check if current input is a valid WikiWord */
	var noSpaceName = removeSpacesAndPunctuation(inputForTopicName);

	/*
	if necessary, create a WikiWord from the input name
	(when a non-WikiWord is not allowed)
	*/
	var wikiWordName = noSpaceName;
	if (!userAllowsNonWikiWord) {
		wikiWordName = removeSpacesAndPunctuation(
            foswiki.String.capitalize(inputForTopicName));
	}
	if (userAllowsNonWikiWord) {
		wikiWordName = filterSpacesAndPunctuation(
            capitalizeSentence(inputForTopicName));
	}
	
	if (inShouldConvertInput) {
		if (hasNonWikiWordCheck && userAllowsNonWikiWord) {
			inForm.topic.value = wikiWordName;
		} else {
			inForm.topic.value = noSpaceName;
		}
	}

	/* Update feedback field */
	if (wikiWordName != inputForTopicName) {
		feedbackHeader = "<strong>" + TEXT_FEEDBACK_HEADER + "</strong>";
		feedbackText = feedbackHeader + wikiWordName;
		$("#webTopicCreatorFeedback").html(feedbackText);
	} else {
		$("#webTopicCreatorFeedback").html("");
	}
	
	if (foswiki.String.isWikiWord(wikiWordName) || userAllowsNonWikiWord) {
		enableSubmit(inForm.submit);
		return true;
	} else {
		disableSubmit(inForm.submit);
		return false;
	}
}

function removeSpacesAndPunctuation (inText) {
	return foswiki.String.removePunctuation(
        foswiki.String.removeSpaces(inText));
}

function filterSpacesAndPunctuation (inText) {
	return foswiki.String.removeSpaces(
        foswiki.String.filterPunctuation(inText));
}

function capitalizeSentence (inText) {
	return inText.substr(0,1).toUpperCase() + inText.substr(1);
}

/**
 * @param inState: true or false
*/
function enableSubmit(inButton) {
	if (!inButton)
        return;
	$(inButton).removeClass("foswikiSubmitDisabled");
	inButton.disabled = false;
}

function disableSubmit(inButton) {
	if (!inButton) return;
	$(inButton).addClass("foswikiSubmitDisabled");
	inButton.disabled = true;
}

function passFormValuesToNewLocation (inUrl) {
	var url = inUrl;
	// remove current parameters so we can override these with
    // newly entered values
	url = url.split("?")[0];
	// read values from form
	var params = "";
	var newtopic = document.forms.newtopicform.topic.value;
	params += ";newtopic=" + newtopic;
	var topicparent = document.forms.newtopicform.topicparent.value;
	params += ";topicparent=" + topicparent;
	var templatetopic = document.forms.newtopicform.templatetopic.value;
	params += ";templatetopic=" + templatetopic;
	var pickparent = URL_PICK_PARENT;
	params += ";pickparent=" + pickparent;
	params += ";template=" + URL_TEMPLATE;
	url += "?" + params;
	document.location.href = url;
	return false;
}

(function($) {
    $(document).ready(
        function() {
            $('form#newtopicform').each(
                function(index, el) {
                    // start with a check
                    canSubmit(el,false);
                }).submit(
                    function () {
                        return canSubmit(this,true);
                    });

            $('input#topic')
                .each(
                    function(index, el) {
                        // focus input field
                        el.focus();
                    })
                .keyup(
                    function(e) {
                        //alert("onkeyup topic");
                        canSubmit(this.form,false);
                    })
                .change(
                    function(e) {
                        canSubmit(this.form,false);
                    })
                .blur(
                    function(e) {
                        canSubmit(this.form,true);
                    });

            $('input#nonwikiword')
                .change(
                    function() {
                        canSubmit(this.form,false);
                    })
                .mouseup(
                    function() {
                        canSubmit(this.form,false);
                    });
            $('a#pickparent')
                .click(
                    function() {
                        return passFormValuesToNewLocation(getQueryUrl());
                    });
            $('a#viewtemplates').click(
                function() {
                    openTemplateWindow();
                    return false;
                });
        });
})(jQuery);
