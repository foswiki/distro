// to please pattern skin < 4.2
var beforeSubmitHandler, foswikiStrikeOne, tinyMCE, FoswikiTiny;

function initTextAreaHeight () { }
function handleKeyDown () { }

/* backwards compatibility */
function fixHeightOfPane () { }

(function($) {
  var editAction, $editForm;

  $(function() {
    $editForm = $("#EditForm");

    /* remove the second TopicTitle */
    $("input[name='TopicTitle']:eq(1)").parents(".foswikiFormStep").remove();
    /* remove the second Summary */
    $("input[name='Summary']:eq(1)").parents(".foswikiFormStep").remove();
  
    /* add click handler */
    $("#save").click(function() {
      editAction = "save";
      $editForm.submit();
      return false;
    });
    $("#checkpoint").click(function() {
      editAction = "checkpoint";
      $editForm.submit();
      return false;
    });
    $("#preview").click(function() {
      editAction = "preview";
      $editForm.submit();
      return false;
    });
    $("#cancel").click(function() {
      editAction = "cancel";
      $editForm.submit();
      return false;
    });
    $("#replaceform").click(function() {
      editAction = "replaceform";
      $editForm.submit();
      return false;
    });
    $("#addform").click(function() {
      editAction = "addform";
      $editForm.submit();
      return false;
    });

    // fix browser back button quirks where checked radio buttons loose their state
    $("input[checked=checked]").each(function() {
      $(this).attr('checked', 'checked');
    });

    // add submit handler
    $editForm.submit(function() {
      var topicParentField = $editForm.find("input[name=topicparent]");

      if (typeof(beforeSubmitHandler) == 'function') {
        if(beforeSubmitHandler("save", editAction) === false) {
          return false;
        }
      }


      if (topicParentField.val() === "") {
        topicParentField.val("none"); // trick in unsetting the topic parent
      }

      if (editAction === 'addform') {
        $editForm.find("input[name='submitChangeForm']").val(editAction);
      }
      $editForm.find("input[name='action_preview']").val('');
      $editForm.find("input[name='action_save']").val('');
      $editForm.find("input[name='action_checkpoint']").val('');
      $editForm.find("input[name='action_addform']").val('');
      $editForm.find("input[name='action_replaceform']").val('');
      $editForm.find("input[name='action_cancel']").val('');
      $editForm.find("input[name='action_"+editAction+"']").val('foobar');

      if (typeof(foswikiStrikeOne) != 'undefined') {
        foswikiStrikeOne($editForm[0]);
      }

      if ((typeof(tinyMCE) === 'object') && 
        (typeof(tinyMCE.activeEditor) === 'object') &&
        (tinyMCE.activeEditor !== null)) {
        tinyMCE.activeEditor.onSubmit.dispatch();
      }
    });

    jQuery(window).load(function() {
      if ((typeof(tinyMCE) === 'object') && typeof(tinyMCE.activeEditor === 'object')) {
        $(".natEditToolBar").hide(); /* switch off natedit toolbar */
        $("#topic_fullscreen").parent().remove(); /* remove full-screen feature ... til fixed */
        /* Thanks to window.load event, TinyMCEPlugin has already done 
        ** switchToWYSIWYG(); our new switchToWYSIWYG() routine below wasn't 
        ** called. So force a TMCE resize. */
        $(window).trigger('resize.natedit');
  
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
    });
  });

})(jQuery);
