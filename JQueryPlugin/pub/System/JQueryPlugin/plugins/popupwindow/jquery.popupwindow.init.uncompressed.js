var profiles =
{
	foswiki:
	{
		width:600,
		height:480,
		status:1
	}

};

jQuery(function($) {
  $(".foswikiPopUp:not(.jqInitedPopUpWindow),.jqPopUpWindow:not(.jqInitedPopUpWindow)").livequery(function() {

    var $this = $(this);
    $this.addClass('jqInitedPopUpWindow');

    // set defaults when not using %POPUPWINDOW%
    if (!$this.attr('rel'))
		$this.attr('rel', 'foswiki');
	
    $this.popupwindow(profiles);
    
  });
});



