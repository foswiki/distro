// to please pattern skin < 4.2
function initTextAreaHeight () { }
function handleKeyDown () { }

function submitEditForm(script, action) {
  $("#savearea").val($("#topic").val());
  $(".natEditBottomBar a").each(function () {
    this.blur();
  });
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
    var foundMce = $(".mceEditor").length;
    if (foundMce) {
      $(".natEditToolBar").hide();
    }
    /*
    if (TWikiTiny) {
      TWikiTiny['switchToRaw'] = function (inst) {
        alert("switch to raw");
        TWikiTiny.switchToRaw(inst);
        $(".natEditToolBar").show();
      };
      alert("switchtoraw="+TWikiTiny['switchToRaw']);
    }
    */
  }, 1);
});
