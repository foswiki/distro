// to please pattern skin < 4.2
var foswikiStrikeOne, tinyMCE, FoswikiTiny;
function handleKeyDown () { }

/* foswiki integration */
(function($) {
  "use strict";

  var editAction, $editForm;

  function showErrorMessage(msg) {
    $("#natEditMessageContainer").addClass("foswikiErrorMessage").html(msg).hide().fadeIn("slow");
    $(window).trigger("resize");
  }
  function hideErrorMessage() {
    $("#natEditMessageContainer").removeClass("foswikiErrorMessage").hide();
    $(window).trigger("resize");
  }

  function setPermission(type, rules) {
    $(".permset_"+type).each(function() { 
      $(this).val("undefined");
    });
    for (var key in rules) {
      if (1) {
        var val = rules[key];
        $.log("EDIT: setting #"+key+"_"+type+"="+val); 
        $("#"+key+"_"+type).val(val);
      }
    }
  }

  function switchOnDetails(type) {
    $("#details_"+type+"_container").slideDown(300);
    var names = [];
    $("input[name='Local+PERMSET_"+type.toUpperCase()+"_DETAILS']").each(function() {
      var val = $(this).val();
      if (val && val != '') {
        names.push(val);
      }
    });
    names = names.join(', ');
    $.log("EDIT: switchOnDetails - names="+names);
    setPermission(type, {
      allow: names
    });
  }

  function switchOffDetails(type) {
    $("#details_"+type+"_container").slideUp(300);
    setPermission(type, {
      allow: ""
    });
  }

  function setPermissionSet(permSet) {
    $.log("EDIT: called setPermissionSet "+permSet);
    var wikiName = foswiki.getPreference("WIKINAME");
    switch(permSet) {
      /* change rules */
      case 'default_change':
        switchOffDetails("change");
        setPermission("change", {
        });
        break;
      case 'nobody_change':
        switchOffDetails("change");
        setPermission("change", {
          allow: 'AdminUser',
          deny: 'undefined'
        });
        break;
      case 'registered_users_change':
        switchOffDetails("change");
        setPermission("change", {
          deny: 'WikiGuest'
        });
        break;
      case 'just_author_change':
        switchOffDetails("change");
        setPermission("change", {
          allow: wikiName
        });
        break;
      case 'details_change':
      case 'details_change_toggle':
        switchOnDetails("change");
        break;
      /* view rules */
      case 'default_view':
        switchOffDetails("view");
        setPermission("view");
        break;
      case 'everybody_view':
        switchOffDetails("view");
        setPermission("view", {
          deny: ' '
        });
        break;
      case 'nobody_view':
        switchOffDetails("view");
        setPermission("view", {
          allow: 'AdminUser',
          deny: 'undefined'
        });
        break;
      case 'registered_users_view':
        switchOffDetails("view");
        setPermission("view", {
          deny: 'WikiGuest'
        });
        break;
      case 'just_author_view':
        switchOffDetails("view");
        setPermission("view", {
          allow: wikiName
        });
        break;
      case 'details_view':
      case 'details_view_toggle':
        switchOnDetails("view");
        break;
      default:
        alert("unregistered permission-set '"+permSet+"'");
        break;
    }
  }

  $(function() {

    // add submit handler
    $("form[name=EditForm]").livequery(function() {
      var $editForm = $(this);

      function submitHandler() {
        var topicParentField = $editForm.find("input[name=topicparent]"),
            actionValue = 'foobar';

        if (topicParentField.val() === "") {
          topicParentField.val("none"); // trick in unsetting the topic parent
        }

        if (editAction === 'addform') {
          $editForm.find("input[name='submitChangeForm']").val(editAction);
        }

        // the action_... field must be set to a specific value in newer foswikis
        if (editAction === 'save') {
          actionValue = 'Save';
        } else if (editAction === 'cancel') {
          actionValue = 'Cancel';
        }

        $editForm.find("input[name='action_preview']").val('');
        $editForm.find("input[name='action_save']").val('');
        $editForm.find("input[name='action_checkpoint']").val('');
        $editForm.find("input[name='action_addform']").val('');
        $editForm.find("input[name='action_replaceform']").val('');
        $editForm.find("input[name='action_cancel']").val('');
        $editForm.find("input[name='action_"+editAction+"']").val(actionValue);

        if (typeof(foswikiStrikeOne) != 'undefined') {
          foswikiStrikeOne($editForm[0]);
        }

        if ((typeof(tinyMCE) === 'object') && (typeof(tinyMCE.editors) === 'object')) {
          $.each(tinyMCE.editors, function(index, editor) {
              editor.onSubmit.dispatch();});
        }
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
        submitHandler();
        $.blockUI({message:'<h1> Saving ... </h1>'});
        $editForm.submit();
        return false;
      });
    
      $("#checkpoint").click(function(el) {
        var topicName = foswiki.getPreference("TOPIC") || '';
        editAction = el.currentTarget.id;
        if ($editForm.validate().form()) {
          submitHandler();
          if (topicName.match(/AUTOINC|XXXXXXXXXX/)) {// || (typeof(tinyMCE) !== 'object')) {
            // don't ajax when we don't know the resultant URL (can change this if the server tells it to us..)
            $editForm.submit();
          } else {
            $editForm.ajaxSubmit({
              url: foswiki.getPreference('SCRIPTURL')+'/rest/NatEditPlugin/save', // SMELL: use this one for REST as long as the normal save can't cope with REST
              beforeSubmit: function() {
                hideErrorMessage();
                $.blockUI({message:'<h1> Saving ... </h1>'});
              },
              error: function(xhr, textStatus, errorThrown) {
                var message = $(xhr.response).find(".natErrorMessage").text().replace(/\s+/g, ' ').replace(/^\s+/, '') || textStatus;
                $.unblockUI();
                showErrorMessage(message);
              },
              success: function(data, textStatus, xhr) {
                var nonce = xhr.getResponseHeader('X-Foswiki-Nonce');
                // patch in new nonce
                $("input[name='validation_key']").each(function() {
                  $(this).val("?"+nonce);
                });
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
          submitHandler();
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
                  height = Math.round(parseInt($window.height() * 0.6, 10));
                  width = Math.round(parseInt($window.width() * 0.6, 10));

              $.unblockUI();

              if (width < 640) {
                width = 640;
              }

              data = data.replace(/%width%/g, width).replace(/%height%/g, height);
              $("body").append(data);
            }
          });
        }
        return false;
      });


      // TODO: only use this for foswiki engines < 1.20
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
          if ($form.find("input[name*='action_'][value='Cancel']").attr("name") == "action_cancel") {
            validator.currentForm.submit();
            validator.errorList = [];
            return;
          }

          if (errors) {
            var message = errors == 1
              ? 'There\'s an error. It has been highlighted below.'
              : 'There are ' + errors + ' errors. They have been highlighted below.';
            $.unblockUI();
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

    // init permissions tab
    if (0) { /* debugging */
      $(".permset_view, .permset_change").each(function() {
        $(this).wrap("<div></div>").parent().prepend("<b>"+$(this).attr('name')+": </b>");
      });
    }
    var scriptUrl = foswiki.getPreference('SCRIPTURL');
    var systemWeb = foswiki.getPreference('SYSTEMWEB');

    $("#details_change, #details_view").textboxlist({
      onSelect: function(input) {
        var currentValues = input.currentValues;
        $.log("EDIT: currentValues="+currentValues);
        var type = (input.opts.inputName=="Local+PERMSET_CHANGE_DETAILS")?"change":"view";
        setPermission(type, {
          allow: currentValues.join(", ")
        });
      },
      autocomplete:scriptUrl+"/view/"+systemWeb+"/JQueryAjaxHelper?section=user;contenttype=text/plain;skin=text;contenttype=application/json"
    });
    $("input[type=radio], input[type=checkbox]").click(function() {
      $(this).blur();
    });
    $("#permissionsForm input[type=radio]").click(function() {
      setPermissionSet($(this).attr('id'));
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

      var oldSwitchToWYSIWYG = FoswikiTiny.switchToWYSIWYG,
          oldSwitchToRaw = FoswikiTiny.switchToRaw;

      FoswikiTiny.switchToWYSIWYG = function(inst) {
        $(".natEditToolBar").hide();
        oldSwitchToWYSIWYG(inst);
        $(window).trigger('resize');
      };


      FoswikiTiny.switchToRaw = function(inst) {
        oldSwitchToRaw(inst);
        $(".natEditToolBar").show();
        $(window).trigger("resize"); 

      };
    }
  });

})(jQuery);
