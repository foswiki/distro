jQuery(function($) {
  $(".jqButton:not(.jqInitedButton)").livequery(function() {
    var $this = $(this), 
      opts = $.extend({}, $this.metadata()),
      form;

    $this.addClass("jqInitedButton")
      .on("mouseenter", function() {
        $this.addClass("jqButtonHover");
      }).on("mouseleave", function() {
        $this.removeClass("jqButtonHover");
      });

    // submit button
    if ($this.is(".jqSubmitButton")) {
      $this.on("click", function() {
        $this.closest("form").submit();
        return false;
      });
    } 

    // save button 
    else if ($this.is(".jqSaveButton")) {
      $this.on("click", function() {
        form = $this.closest("form");
        if(typeof(foswikiStrikeOne) == "function") {
          foswikiStrikeOne(form[0]); 
        }
        form.submit();
        return false;
      });
    } 

    // reset button
    else if ($this.is(".jqResetButton")) {
      $this.on("click", function() {
        $this.closest("form").resetForm();
        return false;
      });
    }

    // clear button
    else if ($this.is(".jqClearButton")) {
      $this.on("click", function() {
        $this.closest("form").clearForm();
        return false;
      });
    }

    // custom click handler
    else if (opts.onclick) {
      $this.on("click", function() {
        return opts.onclick.call(this);
      });
    }

  });
});


