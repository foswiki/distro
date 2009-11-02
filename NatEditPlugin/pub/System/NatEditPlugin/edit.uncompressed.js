// to please pattern skin < 4.2
function initTextAreaHeight () { }
function handleKeyDown () { }

/* backwards compatibility */
function fixHeightOfPane () { }

(function($) {
  function submitEditForm(script, action) {
    var topicText = $("#topic").val();
    $("#savearea").val(topicText);
    if (typeof(beforeSubmitHandler) == 'function') {
      if(beforeSubmitHandler(script, action) === false) {
        return false;
      }
    }
    var editForm = $("#EditForm");
    if (action == 'add form') {
      editForm.find("input[name='submitChangeForm']").val(action);
    }
    editForm.find("input[name='action_preview']").val('');
    editForm.find("input[name='action_save']").val('');
    editForm.find("input[name='action_checkpoint']").val('');
    editForm.find("input[name='action_addform']").val('');
    editForm.find("input[name='action_replaceform']").val('');
    editForm.find("input[name='action_cancel']").val('');
    editForm.find("input[name='action_"+action+"']").val('foobar');
    if (typeof(foswikiStrikeOne) != 'undefined') {
      foswikiStrikeOne(editForm[0]);
    }
    if (typeof(tinyMCE) !== 'undefined' && typeof(tinyMCE.activeEditor) !== 'undefined') {
      tinyMCE.activeEditor.onSubmit.dispatch();
    }
    editForm.submit();
    return false;
  }

  $(function() {
    /* remove the second TopicTitle */
    $("input[name='TopicTitle']:eq(1)").parents(".foswikiFormStep").remove();
    /* remove the second Summary */
    $("input[name='Summary']:eq(1)").parents(".foswikiFormStep").remove();

    /* add click handler */
    $("#save").click(function() {return submitEditForm('save', 'save')});
    $("#checkpoint").click(function() {return submitEditForm('save', 'checkpoint')});
    $("#preview").click(function() {return submitEditForm('preview', 'preview')});
    $("#cancel").click(function() {return submitEditForm('save', 'cancel')});
    $("#replaceform").click(function() {return submitEditForm('save', 'replaceform')});
    $("#addform").click(function() {return submitEditForm('save', 'addform')});


    window.setTimeout(function() {
      if ($("#topic_ifr").length) { 
        $(".natEditToolBar").hide(); /* switch off natedit toolbar */
        $("#topic_fullscreen").parent().remove(); /* remove full-screen feature ... til fixed */

        var oldSwitchToWYSIWYG = FoswikiTiny.switchToWYSIWYG;
        FoswikiTiny.switchToWYSIWYG = function(inst) {
          $(".natEditToolBar").hide();
          $("#wysiwyg").hide();
          oldSwitchToWYSIWYG(inst);
          $(window).trigger('resize.natedit');
        };

        var oldSwitchToRaw = FoswikiTiny.switchToRaw;
        var doneInit = false;
        FoswikiTiny.switchToRaw = function(inst) {
          oldSwitchToRaw(inst);
          $(window).trigger("resize"); /* to let natedit fix the textarea height */
          var oldWysiwygButton = $("#topic_2WYSIWYG");
          var newWysiwygButton = $("#wysiwyg");
          $(".natEditToolBar").show();
          if (!doneInit) {
            doneInit = true;
            var onClickHandler = oldWysiwygButton.attr('onclick');
            oldWysiwygButton.replaceWith(newWysiwygButton);
            newWysiwygButton.click(onClickHandler).show();
          } else {
            oldWysiwygButton.hide();
            newWysiwygButton.show();
          }
        };

      }
    }, 100);
  });

})(jQuery);
