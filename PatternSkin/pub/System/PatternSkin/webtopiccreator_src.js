foswiki.webTopicCreator = {
    /**
     * Checks if the entered topic name is a valid WikiWord.
     * If so, enables the submit button, if not: enables the submit button if
     * the user allows non-WikiWords as topic name; otherwise disables the
     * submit button and returns 'false'.
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
    _canSubmit: function(inForm, inShouldConvertInput) {

        var inputForTopicName = inForm.topic.value;
        
        /* Topic names of zero length are not allowed */
        if (inputForTopicName.length == 0) {
            $(inForm.submit).addClass("foswikiSubmitDisabled")
            .attr('disabled', true);
            /* Update feedback field */
            $("#webTopicCreatorFeedback").html("");
            return false;
        }
        var hasNonWikiWordCheck = (inForm.nonwikiword != undefined);
        var userAllowsNonWikiWord = true;
        if (hasNonWikiWordCheck) {
            // nonwikiword can be a radio button or a hidden input
            userAllowsNonWikiWord = (inForm.nonwikiword.checked
                                     || inForm.nonwikiword.value == 'on');
        }
        
        /* check if current input is a valid WikiWord */
        var noSpaceName = foswiki.webTopicCreator
        ._removeSpacesAndPunctuation(inputForTopicName);
        
        /*
          if necessary, create a WikiWord from the input name
          (when a non-WikiWord is not allowed)
        */
        var wikiWordName = noSpaceName;
        if (!userAllowsNonWikiWord) {
            wikiWordName = foswiki.webTopicCreator._removeSpacesAndPunctuation(
                foswiki.String.capitalize(inputForTopicName));
        }

        if (userAllowsNonWikiWord) {
            wikiWordName = foswiki.webTopicCreator._filterSpacesAndPunctuation(
                inputForTopicName.substr(0,1).toLocaleUpperCase()
                + inputForTopicName.substr(1));
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
            $(inForm.submit).removeClass("foswikiSubmitDisabled")
            .attr('disabled', false);
            return true;
        } else {
            $(inForm.submit).addClass("foswikiSubmitDisabled")
            .attr('disabled', true);
            return false;
        }
    },
    
    _removeSpacesAndPunctuation: function (inText) {
        return foswiki.String.removePunctuation(
            foswiki.String.removeSpaces(inText));
    },
    
    _filterSpacesAndPunctuation: function (inText) {
        return foswiki.String.removeSpaces(
            foswiki.String.filterPunctuation(inText));
    },
    
    _passFormValuesToNewLocation: function (inUrl) {
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
};

(function($) {
    $(document).ready(
        function() {
            $('form#newtopicform').each(
                function(index, el) {
                    // start with a check
                    foswiki.webTopicCreator._canSubmit(el,false);
                }).submit(
                    function () {
                        return foswiki.webTopicCreator._canSubmit(this,true);
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
                        foswiki.webTopicCreator._canSubmit(this.form,false);
                    })
                .change(
                    function(e) {
                        foswiki.webTopicCreator._canSubmit(this.form,false);
                    })
                .blur(
                    function(e) {
                        foswiki.webTopicCreator._canSubmit(this.form,true);
                    });

            $('input#nonwikiword')
                .change(
                    function() {
                        foswiki.webTopicCreator._canSubmit(this.form,false);
                    })
                .mouseup(
                    function() {
                        foswiki.webTopicCreator._canSubmit(this.form,false);
                    });
            $('a#pickparent')
                .click(
                    function() {
                        return foswiki.webTopicCreator
                            ._passFormValuesToNewLocation(getQueryUrl());
                    });
        });
})(jQuery);
