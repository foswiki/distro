/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

/**
 * Support for the "raw text" editor.
 * Requires JQUERYPLUGIN::FOSWIKI
 */

(function($) {
    foswiki.Edit = {
        validateSuppressed: false
    };

    foswiki.Edit.validateMandatoryFields = function() {
        // Provided for use by editors that need to
        // validate form elements before navigating away
        if (foswiki.Edit.validateSuppressed) {
            return true;
        }
        
        var alerts = [];
        $('select.foswikiMandatory').each(function(index, el) {
			var one = false;
			var k;
			for (k = 0; k < el.options.length; k=k+1) {
				if (el.options[k].selected) {
					one = true;
					break;
				}
			}
			if (!one) {
				alerts.push("The required form field '"
							+ el.name +
							"' has no value.");
			}
		});

        $('textarea.foswikiMandatory, input.foswikiMandatory').each(function(index, el) {
			if (el.value === null || el.value.length === 0) {
				alerts.push("The required form field '"
							+ el.name +
							"' has no value.");
			}
		});

        if (alerts.length > 0) {
            alert(alerts.join("\n"));
            return false;
        } else {
            return true;
        }
    };

    $(function() {

		try {
			document.main.text.focus();
		} catch (er) {
			//
		}

		$(document.forms[name='main']).submit(function(e) {
			return foswiki.Edit.validateMandatoryFields();
		});

		$('.foswikiTextarea').keydown(function(e) {
			// Disables the use of ESCAPE in the edit box, because some
			// browsers will interpret this as cancel and will remove
			// all changes.
			var code;
			if (e.keyCode) {
				code = e.keyCode;
			}
			return (code !== 27); // ESC
		});

		$('.foswikiButtonCancel').click(function(e) {
			// Used to dynamically set validation suppression
			foswiki.Edit.validateSuppressed = true;
		});
	});
}(jQuery));