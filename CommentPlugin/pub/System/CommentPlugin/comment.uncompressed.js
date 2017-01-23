/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2010-2017 Foswiki Contributors. Foswiki Contributors
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
    $(document).ready( function() {
        // Handle focus and typing operations in a prompt textarea
        $("textarea.commentPluginPromptBox")
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

        // Given a response to an AJAX REST comment save operation,
        // insert the returned comment in the appropriate place in the
        // text.
        var addComment = function(position, html, form) {
            var relto;
            if (position == 'TOP') {
                // There's no standard
                relto = $('.patternContent');
                if (relto.length == 0)
                    relto = $('body');
                relto.prepend(html);
                position = '';
            } else if (position == 'BOTTOM') {
                relto = $('.patternContent');
                if (relto.length == 0)
                    relto = $('body');
                relto.append(html);
                position = '';
            } else if (form.comment_location) {
                relto = $('*:contains("' + form.comment.location.value
                          + '")')[0];
            } else if (form.comment_anchor) {
				var anchor = form.comment_anchor.value.slice(1);
                relto = $("a[name='" + anchor
                          + "'],*[id='" + anchor + "']");
            } else {
                relto = $(".commentPluginForm")[form.comment_index.value];
                if (relto)
                    relto = $(relto);
            }

            if (relto && position == 'BEFORE') {
                relto.before(html);
            } else if ( relto && position == 'AFTER' ) {
                relto.after(html);
            } else if (position != '') {
                $('body').append(html);
            }
        };

        // Handler for when an AJAXed "Add Comment" button is clicked
        // Compose and send off a rest request to save the new comment.
        $("input.commentPluginAjax").click(
            function(e) {
                var form = $(this).parents("form")[0];
                $("body").css("cursor", "wait");
                if (typeof(StrikeOne) !== 'undefined')
                    StrikeOne.submit(form);
                $.ajax({
                    url: form.action,
                    type: "POST",
                    data: $(form).serialize(),
                    beforeSend: function() {
                        $(form).find("input[type=text], textarea").attr('disabled', 'disabled');
                        $(form).find('[type=submit]').attr('disabled', 'disabled');
                        $(form).find('[type=submit]').addClass('foswikiButtonDisabled');
                    },
                    success: function(data, textStatus, jqXHR) {
                        var position = jqXHR.getResponseHeader(
                            'X-Foswiki-Comment');
                        addComment(position, data, form);
                        $(form).find("input[type=text], textarea").removeAttr('disabled', 'disabled');
                        $(form).find('[type=submit]').removeAttr('disabled', 'disabled');
                        $(form).find('[type=submit]').removeClass('foswikiButtonDisabled');
                        $("body").css("cursor", "default");
                        form.reset();
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        if (jqXHR.responseText)
                            alert("Error: " + jqXHR.responseText);
                        else
                            alert("Error: " + errorThrown);
                        $(form).find("input[type=text], textarea").removeAttr('disabled', 'disabled');
                        $(form).find('[type=submit]').removeAttr('disabled', 'disabled');
                        $(form).find('[type=submit]').removeClass('foswikiButtonDisabled');
                        $("body").css("cursor", "default");
                    },
                    complete: function(jqXHR) {
                        // Update the strikeone nonce
                        var nonce = jqXHR.getResponseHeader('X-Foswiki-Validation');
                        // patch in new nonce
                        if (nonce) {
                            $("input[name='validation_key']").each(function() {
                                $(this).val("?" + nonce);
                            });
                        }
                    }
                });
                return false;
            });
    });
})(jQuery);
