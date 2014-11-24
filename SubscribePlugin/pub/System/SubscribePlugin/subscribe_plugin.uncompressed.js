/**
 * Support for SubscribePlugin
 * 
 * Copyright (c) 2013-2014 Crawford Currie http://c-dot.co.uk
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
        $('.subscribe_link').click(function() {
            var clink = $(this);
            clink.off('click');
            var url = clink.attr('href');
            var params = url.match(/\?(.+)/)[1];
            params = params.replace(/;/g, '&');
            if (typeof(StrikeOne) !== 'undefined') {
                params += "&validation_key="
                    + StrikeOne.calculateNewKey(SubscribePlugin_key);
            }
	    $.ajax({
		type: "POST",
		data: params,
		url: $(this).attr('href'),
		success: function(response) {
                    clink.text(response.message);
                    url.replace(/subscribe_remove=\d+/, '');
                    if (response.remove === 1) {
                        clink.attr('href', url + '&subscribe_remove=1');
                    }
		},
		error: function(response) {
                    alert(response.message);
		},
                complete: function(jqXHR, status) {
                    // Update the strikeone nonce
                    var nonce = jqXHR.getResponseHeader('X-Foswiki-Validation');
                    // patch in new nonce
                    if (nonce) {
                        subscribe_key = "?" + nonce;
                    }
                    clink.on('click');
                }
            });
            return false;
        });
    });
})(jQuery);
