
jQuery(document).ready(
    function ($) {
        // Mark a form step with a hoopy styled character
        $(".foswikiFormStep h3").each(
            function(index, el) {
                $(el).before(
                    '<span class="foswikiActionFormStepSign">&#9658;</span>'
                    );
            });

        $("input#jumpFormField")
            .each(
                function(index, el) {
                    foswiki.Form.initBeforeFocusText(
                        el, foswiki.getMetaTag('TEXT_JUMP'));
                })
            .focus(
                function() {
                    foswiki.Form.clearBeforeFocusText(this);
                })
            .blur(
                function() {
                    foswiki.Form.restoreBeforeFocusText(this);
                });

        $('input#quickSearchBox')
            .each(
                function(index, el) {
                    foswiki.Form.initBeforeFocusText(el,
                        foswiki.getMetaTag('TEXT_SEARCH'));
                })
            .focus(
                function() {
                    foswiki.Form.clearBeforeFocusText(this);
                })
            .blur(
                function() {
                    foswiki.Form.restoreBeforeFocusText(this);
                });

        // Create an attachment counter in the attachment table twisty.
        $('.foswikiAttachments')
            .each(
                function(index, el) {
	                var count = $(el).children('tr').length - 1;
                    var countStr = " <span class='patternSmallLinkToHeader'> "
                        + count + "<\/span>";
                    $(el).children('.patternAttachmentHeader h3').each(
                        function(index, el) {
                            $(el).append(countStr);
                        });
                }
            );

        var searchResultsCount = 0;

        // Search page handling
        $('.foswikiSearchResultCount span').each(
            function(index, el) {
                searchResultsCount += parseInt(el.innerHTML);
            });

        if (searchResultsCount > 0) {
            $('#foswikiNumberOfResultsContainer').each(
                function(index, el) {
                    // write result count
                    var text = " " + foswiki.getMetaTag('TEXT_NUM_TOPICS') +
                        " <b>" + searchResultsCount + " </b>";
                    el.innerHTML = text;
                });

            if ($('form#foswikiWebSearchForm').length) {
                $('#foswikiModifySearchContainer').each(
                    function(index, el) {
                        el.innerHTML =
                            ' <a href="#"><span class="foswikiLinkLabel foswikiSmallish">'
                            + foswiki.getMetaTag('TEXT_MODIFY_SEARCH')
                            + '</span></a>';
                        $(el).children('a').click(
                            function(e) {
                                this.location.hash = 'foswikiSearchForm';
                                return false;
                            });
                    });
            }
        }

        $('a.foswikiPopUp').click(
            function(e) {
//                foswiki.Window.openPopup(this.href, {template:"viewplain"});
                return false;
            });

        $('input.foswikiFocus').each(
            function(index, el) {
                el.focus();
            });

        $('input.foswikiChangeFormButton').click(
            function(e) {
                suppressSaveValidation();
            });

		if (foswiki && foswiki.Edit)
            foswiki.Edit.initForm();
	});
