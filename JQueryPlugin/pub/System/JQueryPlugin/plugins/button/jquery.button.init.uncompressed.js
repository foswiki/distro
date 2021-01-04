"use strict";
jQuery(function($) {

  $(".jqButton:not(.jqInitedButton)").livequery(function() {
    var $this = $(this), $form;

    $this.addClass("jqInitedButton")
      .on("mouseenter", function() {
        $this.addClass("jqButtonHover");
      }).on("mouseleave", function() {
        $this.removeClass("jqButtonHover");
      })
      .on("click", function() {
        $form = $this.closest("form");

        if ($this.is(".jqButtonDisabled")) {
          return false;
        } 
        // submit button
        if ($this.is(".jqSubmitButton")) {
          $form.trigger("submit");
          return false;
        } 

        // save button 
        if ($this.is(".jqSaveButton")) {
          if(typeof(foswikiStrikeOne) == "function") {
            foswikiStrikeOne($form[0]); 
          }
          $form.trigger("submit");
          return false;
        } 

        // reset button
        if ($this.is(".jqResetButton")) {
          $form.resetForm();
          return false;
        }

        // clear button
        if ($this.is(".jqClearButton")) {
          $form.clearForm();
          return false;
        }
      });
  });
});


