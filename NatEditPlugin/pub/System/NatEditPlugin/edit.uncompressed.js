// to please pattern skin < 4.2
var beforeSubmitHandler, foswikiStrikeOne, tinyMCE, FoswikiTiny;

function initTextAreaHeight () { }
function handleKeyDown () { }

/* backwards compatibility */
function fixHeightOfPane () { }

(function($) {
  var editAction, $editForm;

  function showErrorMessage(msg) {
    $("#natEditMessageContainer").addClass("foswikiErrorMessage").html(msg).hide().fadeIn("slow");
    $(window).trigger("resize");
  }
  function hideErrorMessage() {
    $("#natEditMessageContainer").removeClass("foswikiErrorMessage").hide();
    $(window).trigger("resize");
  }

  // add submit handler
  $(function() {
    $("form[name=EditForm]").livequery(function() {
      var $editForm = $(this);

      function submitHandler() {
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

        return true;
      }

      if ($editForm.is("natEditFormInited")) {
        return;
      }
      $editForm.addClass("natEditFormInited");

      /* remove the second TopicTitle */
      $("input[name='TopicTitle']:eq(1)").parents(".foswikiFormStep").remove();

      /* remove the second Summary */
      $("input[name='Summary']:eq(1)").parents(".foswikiFormStep").remove();
    
      /* add click handler */
      $("#save").click(function() {
        editAction = "save";
        if (submitHandler()) {
          $editForm.submit();
        }
        return false;
      });
      $("#checkpoint").click(function() {
        var topicName = foswiki.getPreference("TOPIC") || '';
        editAction = "checkpoint";
        if ($editForm.validate().form()) {
          if (!submitHandler()) {
            return false;
          }
          if (topicName.match(/AUTOINC|XXXXXXXXXX/) || (typeof(tinyMCE) === 'object' && typeof(tinyMCE.activeEditor === 'object'))) {
            // don't ajax using wysiwyg 
            $editForm.submit();
          } else {
            // only ajax using raw 
            $editForm.ajaxSubmit({
              beforeSubmit: function() {
                hideErrorMessage();
                $.blockUI({message:'<h1> Saving ... </h1>'});
              },
              error: function(xhr, textStatus, errorThrown) {
                var message = $(xhr.response).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || textStatus;
                $.unblockUI();
                showErrorMessage(message);
              },
              success: function(data, textStatus) {
                $.unblockUI();
              }
            });
          }
        }
        return false;
      });
      $("#preview").click(function() {
        editAction = "preview";
        if ($editForm.validate().form()) {
          if (!submitHandler()) {
            return false;
          }
          $editForm.ajaxSubmit({
            beforeSubmit: function() {
              hideErrorMessage();
              $.blockUI({message:'<h1> Loading preview ... </h1>'});
            },
            error: function(xhr, textStatus, errorThrown) {
              var message = $(xhr.response).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || textStatus;
              $.unblockUI();
              showErrorMessage(message);
            },
            success: function(data, textStatus) {
              var $window = $(window),
                  height,
                  width = Math.round(parseInt($window.width() * 0.6, 10));

              $.unblockUI();
              foswiki.openDialog(data, {
                close: true,
                containerCss: {
                  width: width
                },
                onShow: function(dialog) {
                  $window.bind('resize', function() {
                    height = Math.round(parseInt($window.height() * 0.6, 10));
                    width = Math.round(parseInt($window.width() * 0.6, 10));
                    if (width < 640) {
                      width = 640;
                    }
                    dialog.container.width(width);
                    dialog.container.find(".foswikiPreviewArea").height(height);
                  });
                  $window.trigger('resize');
                }
              });
            }
          });
        }
        return false;
      });
      $("#cancel").click(function() {
        editAction = "cancel";
        hideErrorMessage();
        $("label.error").hide();
        $("input.error").removeClass("error");
        $(".jqTabGroup a.error").removeClass("error");
        submitHandler();
        $editForm.submit();
        return false;
      });
      $("#replaceform").click(function() {
        editAction = "replaceform";
        submitHandler();
        $editForm.submit();
        return false;
      });
      $("#addform").click(function() {
        editAction = "addform";
        submitHandler();
        $editForm.submit();
        return false;
      });

      // fix browser back button quirks where checked radio buttons loose their state
      $("input[checked=checked]").each(function() {
        $(this).attr('checked', 'checked');
      });

      /* add clientside form validation */
      var formRules = $.extend({}, $editForm.metadata({
        type:'attr',
        name:'validate'
      }));

      $editForm.validate({
        meta: "validate",
        invalidHandler: function(e, validator) {
          var errors = validator.numberOfInvalids(),
              $form = $(validator.currentForm);

          /* ignore a cancel action */
          if ($form.find("input[name*=action_][value=foobar]").attr("name") == "action_cancel") {
            validator.currentForm.submit();
            validator.errorList = [];
            return;
          }

          if (errors) {
            var message = errors == 1
              ? 'There\'s an error. It has been highlighted below.'
              : 'There are ' + errors + ' errors. They have been highlighted below.';
            showErrorMessage(message);
            $.each(validator.errorList, function() {
              var $errorElem = $(this.element);
              $errorElem.parents(".jqTab").each(function() {
                var id = $(this).attr("id");
                $("[data="+id+"]").addClass("error");
              });
            });
          } else {
            hideErrorMessage();
            $form.find(".jqTabGroup a.error").removeClass("error");
          }
        },
        rules: formRules,
        ignoreTitle: true,
        errorPlacement: function(error, element) {
          if (element.is("[type=checkbox],[type=radio]")) {
            // special placement if we are inside a table
            $("<td>").appendTo(element.parents("tr:first")).append(error);
          } else {
            // default
            error.insertAfter(element);
          }
        }
      });
      $.validator.addClassRules("foswikiMandatory", {
        required: true
      });
    });
  });

  // patch in tinymce
  $(window).load(function() {
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

})(jQuery);
