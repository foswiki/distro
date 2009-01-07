// to please pattern skin < 4.2
function initTextAreaHeight () { }
function handleKeyDown () { }

function submitEditForm(script, action) {
  var topicText = $("#topic").val();
  $("#savearea").val(topicText);
  if (typeof(beforeSubmitHandler) != 'undefined') {
    beforeSubmitHandler(script, action);
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
  editForm.submit();
}

$(function() {
    window.setTimeout(function() {
      if (typeof(TWikiTiny) != 'undefined' || typeof(FoswikiTiny) != 'undefined') {
        $(".natEditToolBar").hide(); /* switch off natedit toolbar */

        /*
        var oldSwitchToRaw = TWikiTiny.switchToRaw;
        TWikiTiny.switchToRaw = function(inst) {
          $(".natEditToolBar").show();
          oldSwitchToRaw(inst);
        };

        TWikiTiny['switchToRaw'] = function (inst) {
          alert("switch to raw");
          TWikiTiny.switchToRaw(inst);
          $(".natEditToolBar").show();
        };
        */
      }
    }, 1);
});
