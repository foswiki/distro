/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010 Foswiki Contributors. Foswiki Contributors
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

This is an example of a simple AJAX comment submission.

*/
(function($) {
    $(document).ready(
        function() {
            $("textarea.commentPluginAjax")
                .blur(
                    function() {
                        if (this.value == '')
                            this.value = this.title;
                    })
                .focus(
                    function() {
                        if (this.value == this.title)
                            this.value = '';
                    })
                .keypress(
                    function() {
                        var form = $(this).parents("form")[0];
                        $(form).find(".commentPluginStatusResponse").html('');
                    });
            $("input.commentPluginAjax").click(
                function(e) {
                    var form = $(this).parents("form")[0];
                    // Remove the endpoint; we want a status report
                    $(form).find("input[name='endPoint']").remove();
                    $.post(form.action, $(form).serialize(),
                           function() {
                               $(form).find(".commentPluginStatusResponse")
                                   .html("Saved");
                           });
                });
        });
})(jQuery);
