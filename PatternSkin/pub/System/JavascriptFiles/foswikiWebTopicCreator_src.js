(function ($) {
    "use strict";

    foswiki.webTopicCreator = {

        /*
        Preloaded parent list.
        */
        parentList: undefined,

        /*
        Checks if the entered topic name is a valid WikiWord.
        If so, enables the submit button, if not: enables the submit button if
        the user allows non-WikiWords as topic name; otherwise disables the
        submit button and returns 'false'.
        Automatically removes spaces from entered name.
        Automatically strips illegal characters.
        If non-WikiWords are not allowed, capitalizes words (separated by space).
        If non-WikiWords _are_ allowed, capitalizes sentence.
        The generated topic name is written to a 'feedback' field.
        @param $form : the form (jQuery object)
        @param shouldConvertInput : true: a new name is created from the
        entered name
        @return True: submit is enabled and topic creation is allowed; false:
        submit is disabled and topic creation should be inhibited.
        */
        canSubmit: function ($form, shouldConvertInput) {
            // Replace illegal characters in the name with spaces. This is
            // always done, irrespective of whether we are non-wikiwording
            // or not.
            var inputName = $('input[name=topic]', $form).val(),
                re = foswiki.getPreference('NAMEFILTER'),
                onlyWikiName = false,
                finalName,
                feedbackHeader,
                feedbackText,
                error,
                cleanName = foswiki.String.trimSpaces(inputName);

            if (typeof(re) === 'string') {
                re = new RegExp(re, "g");
            }

            /* Topic names of zero length are not allowed */
            if (inputName.length === 0) {
                $('input[type=submit]', $form).addClass('foswikiSubmitDisabled').attr('disabled', true);
                // Update feedback fields
                $('.webTopicCreatorFeedback', $form).html('');
                $('.webTopicCreatorError', $form).html('');
                return false;
            }
            $('input[name=onlywikiname]', $form).each(function (index, el) {
                onlyWikiName = el.checked;
            });
            if (cleanName.length === 0) {
                return false;
            }
            if (onlyWikiName) {
                // Take out all illegal chars
                cleanName = inputName.replace(re, '');
                // Capitalize just the first character
                finalName = cleanName.substr(0, 1).toLocaleUpperCase() + cleanName.substr(1);
            } else {
                // Replace illegal chars with spaces
                cleanName = inputName.replace(re, ' ');
                finalName = foswiki.String.capitalize(cleanName);
                finalName = finalName.replace(/\s+/g, '');
            }
            if (shouldConvertInput) {
                $('input[name=topic]', $form).val(finalName);
            }
            /* Update feedback field */
            if (finalName !== inputName) {
                feedbackHeader = foswiki.getPreference('webTopicCreator.nameFeedback');
                feedbackText = feedbackHeader + '<strong>' + finalName + '</strong>';
                $('.webTopicCreatorFeedback', $form).html(feedbackText);
            } else {
                $('.webTopicCreatorFeedback', $form).html('');
                $('.webTopicCreatorError', $form).html('');
            }
            if (foswiki.String.isWikiWord(finalName) || !onlyWikiName) {
                $('input[type=submit]', $form).removeClass('foswikiSubmitDisabled').attr('disabled', false);
                $('.webTopicCreatorError', $form).html('');
                return true;
            } else {
                // Don't show the error with short words, or it will show up every time you start to type
                if (finalName.length > 3) {
                    $('.webTopicCreatorError', $form).html(foswiki.getPreference('webTopicCreator.errorFeedbackNoWikiName'));
                }
            }
            // else
            $('input[type=submit]', $form).addClass('foswikiSubmitDisabled').attr('disabled', true);
            return false;
        },

        removeSpacesAndPunctuation: function (text) {
            return foswiki.String.removePunctuation(foswiki.String.removeSpaces(text));
        },

        filterSpacesAndPunctuation: function (text) {
            return foswiki.String.removeSpaces(foswiki.String.filterPunctuation(text));
        },

        loadParentList: function ($form, preload) {
            if (this.parentList !== undefined) {
                this.onParentListLoaded($form);
                return;
            }
            var parent = $('input[name=topicparent]', $form).val(),
                url = foswiki.getPreference('SCRIPTURLPATH') + '/view/' + foswiki.getPreference('SYSTEMWEB') + '/ParentList' + '?section=select' + ';web=' + foswiki.getPreference('WEB') + ';cover=text' + ';selected=' + parent,
                that = this;
            $.get(url, function (data) {
                that.parentList = data;
                if (!preload) {
                    that.onParentListLoaded($form);
                }
            });
        },

        onParentListLoaded: function ($form) {
            var parent = $('input[name=topicparent]', $form).val();
            $('input[name=topicparent]', $form).replaceWith(this.parentList);
            // get parent name value and select
            if (parent) {
                $('select[name=topicparent] option[value=' + parent + ']', $form).attr('selected', 'selected');
            }
            this.afterLoadParentList($form);
        },

        /*
    Show throbber, make input read-only.
    */
        beforeLoadParentList: function ($form) {
            $('img.processing', $form).removeClass('foswikiHidden');
            $('input[name=topicparent]', $form).attr('readonly', 'readonly');
        },

        /*
        Hide throbber.
        */
        afterLoadParentList: function ($form) {
            $('img.processing', $form).hide();
        }
    };

    $(function () {
        $('form[name=newtopicform]').each(function (index, el) {
            var $form = $(el);

            // set up behaviors
            $('input[name=topic]', $form).each(function (index, el) {
                // focus input field
                el.focus();
            }).keyup(function (e) {
                foswiki.webTopicCreator.canSubmit($form, false);
            }).change(function (e) {
                foswiki.webTopicCreator.canSubmit($form, false);
            }).blur(function (e) {
                foswiki.webTopicCreator.canSubmit($form, true);
            });

            $('input[name=onlywikiname]', $form).change(function () {
                foswiki.webTopicCreator.canSubmit($form, false);
            }).mouseup(function () {
                foswiki.webTopicCreator.canSubmit($form, false);
            });

            $('a.pickparent', $form).click(function (e) {
                $(this).hide();
                foswiki.webTopicCreator.beforeLoadParentList($form);
                foswiki.webTopicCreator.loadParentList($form);
                return false;
            });

            // start with a check
            foswiki.webTopicCreator.canSubmit($form, false);

            // preload parent list
            foswiki.webTopicCreator.loadParentList($form, true);

        }).submit(function () {
            return foswiki.webTopicCreator.canSubmit(this, true);
        });
    });
}(jQuery));
