// initializer for foswiki
jQuery(document).ready(function($) {
   
	var PUBURL = foswiki.getPreference('PUBURLPATH') + '/' + foswiki.getPreference('SYSTEMWEB') + '/' + 'JQueryPlugin/plugins/facebox/';

	$('a[rel*=facebox]').livequery(function () {
	
		$(this).facebox({
			loadingImage : PUBURL + 'loading.gif',
			closeImage   : PUBURL + 'closelabel.png'
		});

	});

});