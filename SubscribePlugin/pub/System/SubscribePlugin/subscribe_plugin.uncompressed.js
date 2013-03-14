/**
 * Support for SubscribePlugin
 * 
 * Copyright (c) 2013 Crawford Currie http://c-dot.co.uk
 * and Foswiki Contributors.
 * All Rights Reserved. Foswiki Contributors are listed in the
 * AUTHORS file in the root of this distribution.
 * NOTE: Please extend that file, not this notice.
 * 
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version. For
 * more details read LICENSE in the root of this distribution.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * 
 * Do not remove this copyright notice.
 */
(function($) {
    $(document).ready( function () {
	$('.subscribe_button').on('click', function() {
	    var form = $(this).parents("form");
	    StrikeOne.submit(form);
	    form.addClass("subscribe_waiting");
	    form.find(".subscribe_button").text(
		form.find(".subscribe_changing").text());
	    $.ajax({
		type: "POST",
		data: form.serialize(),
		url: form.attr('action'),
		success: function(response) {
                    $("form.subscribe_waiting>.subscribe_button")
			.text(response.message);
		    $("form.subscribe_waiting>input[name='subscribe_remove']")
			.val(response.remove);
		    $("form.subscribe_waiting")
			.removeClass('subscribe_waiting');
		},
		error: function(response) {
                    $("form.subscribe_waiting>.subscribe_button")
			.text(response.message);
		    $("form.subscribe_waiting")
			.removeClass('subscribe_waiting');
		}
            })
	});
    });
})(jQuery);
