(function($) {
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

          // Replace illegal characters in the name with spaces. This is
          // always done, irrespective of whether we are non-wikiwording
          // or not.
          var inputName = inForm.topic.value,
              nameFilterRegex = foswiki.getPreference('NAMEFILTER'),
              re = new RegExp(nameFilterRegex, 'g'),
              userAllowsNonWikiWord = true,
              finalName,
              feedbackHeader,
              feedbackText;
          
          /* Topic names of zero length are not allowed */
          if (inputName.length === 0) {
              $(inForm.submit).addClass('foswikiSubmitDisabled')
              .attr('disabled', true);
              /* Update feedback field */
              $('#webTopicCreatorFeedback').html('');
              return false;
          }

          $('#nonwikiword').each(
              function(index, el) {
                  userAllowsNonWikiWord = el.checked;
              });

          var cleanName = foswiki.String.trimSpaces(inputName);
          if (cleanName.length === 0) {
              return false;
          }
        
          if (userAllowsNonWikiWord) {
              // Take out all illegal chars
              cleanName = inputName.replace(re, '');
              // Capitalize just the first character
              finalName = cleanName.substr(0,1).toLocaleUpperCase() + cleanName.substr(1);
          } else {
              // Replace illegal chars with spaces
              cleanName = inputName.replace(re, ' ');
              finalName = foswiki.String.capitalize(cleanName);
              finalName = finalName.replace(/\s+/g, '');
          }

          
          if (inShouldConvertInput) {
              inForm.topic.value = finalName;
          }
          
          /* Update feedback field */
          if (finalName != inputName) {
              feedbackHeader = '<strong>' + TEXT_FEEDBACK_HEADER + '</strong>';
              feedbackText = feedbackHeader + finalName;
              $('#webTopicCreatorFeedback').html(feedbackText);
          } else {
              $('#webTopicCreatorFeedback').html('');
          }
          
          if (foswiki.String.isWikiWord(finalName) || userAllowsNonWikiWord) {
              $(inForm.submit).removeClass('foswikiSubmitDisabled')
              .attr('disabled', false);
              return true;
          } else {
              $(inForm.submit).addClass('foswikiSubmitDisabled')
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
          url = url.split('?')[0];
          // read values from form
          var params = '';
          var newtopic = document.forms.newtopicform.topic.value;
          params += ';newtopic=' + newtopic;
          var topicparent = document.forms.newtopicform.topicparent.value;
          params += ';topicparent=' + topicparent;
          var templatetopic = document.forms.newtopicform.templatetopic.value;
          params += ';templatetopic=' + templatetopic;
          var pickparent = URL_PICK_PARENT;
          params += ';pickparent=' + pickparent;
          params += ';template=' + URL_TEMPLATE;
          url += '?' + params;
          document.location.href = url;
          return false;
      }
  };

  $(function() {
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
