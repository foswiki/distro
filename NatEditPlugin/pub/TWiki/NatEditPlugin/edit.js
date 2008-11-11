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
  if (action == 'add form') {
    document.EditForm.elements['submitChangeForm'].value = action;
  }
  document.EditForm.elements['action_preview'].value = '';
  document.EditForm.elements['action_save'].value = '';
  document.EditForm.elements['action_checkpoint'].value = '';
  document.EditForm.elements['action_addform'].value = '';
  document.EditForm.elements['action_replaceform'].value = '';
  document.EditForm.elements['action_cancel'].value = '';
  document.EditForm.elements['action_' + action].value = 'foobar';
  document.EditForm.submit();
}
