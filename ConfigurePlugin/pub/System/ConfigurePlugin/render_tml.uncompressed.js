/*
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2014 Foswiki Contributors. Foswiki Contributors
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

TML (subset) renderer. Handles a simple subset of TML:
See Foswiki::Configure::Reporter for the subset of TML that is
supported.

Author: Crawford Currie http://c-dot.co.uk
*/
var TML = {
    STYLING : [
        // {strong}
        [
            /(^|[\s(])\{(\S+?|\S[^\n]*?\S)\}($|(?=[\s,.;:!?)]))/g,
            "$1<strong><code>{$2}</code></strong>"
        ],
        [
            /(^|[\s\(])\*(\S+?|\S[^\n]*?\S)\*(?:$|(?=[\s,.;:!?\)]))/g,
            "$1<strong>$2</strong>"
        ],
        // _em_
        [
            /(^|[\s\(])\_(\S+?|\S[^\n]*?\S)\_(?:$|(?=[\s,.;:!?\)]))/g,
            "$1<em>$2</em>"
        ],
        // =code=
        [
            /(^|[\s\(])\=(\S+?|\S[^\n]*?\S)\=(?:$|(?=[\s,.;:!?\)]))/g,
            "$1<code>$2</code>"
        ],
        // [[url]]
        [
            /\[\[([^\]]+)\]\]/g,
            '<a target="_blank" href="$1">$1</a>'
        ],
        // [[url][text]]
        [
            /\[\[([^\]]+)\]\[([^\]]+)\]\]/g,
            '<a target="_blank" href="$1">$2</a>'
        ]
    ],

    // Given a block of text that contains TML, render that TML,
    // returning HTML
    render : function (text) {

        var removed, lines, in_table, in_list, list_type,
            i, j, m, line, cols;

        removed = [];
        text = text
            .replace(
                /<verbatim>((.|\n)*?)<\/verbatim>/g,
                function (m, $1) {
                    // Encode verbatim
                    $1 = $1.replace(/&/g, "&amp;")
                        .replace(/</g, "&lt;")
                        .replace(/>/g, "&gt;");
                    removed.push('<pre>' + $1 + "</pre>");
                    return "PLACEHOLDER" + (removed.length - 1) + ";";
                })
            .replace(
                /(<(button|select|option|textarea)\b(?:.|\n)*?<\/\1>)/g,
                function (m, $1) {
                    // Protect HTML types. Only <lc>...</lc> syntax supported.
                    removed.push($1);
                    return "PLACEHOLDER" + (removed.length - 1) + ";";
                })
            .replace(/^>(.*)$/gm, '<p class="one_line_report"> $1 </p>');

        lines = text.split(/\n/);

        in_table = false;
        in_list = false;
        for (i = 0; i < lines.length; i++) {
            line = lines[i];

            if (/^\s*$/.test(line)) {
                // blank line closes list and table
                if (in_list) {
                    lines.splice(i++, 0, '</' + list_type + '>');
                    in_list = false;
                } else if (in_table) {
                    lines.splice(i++, 0, '</table>');
                    in_table = false;
                }
                lines[i] = "<br />";
                continue;
            }

            for (j = 0; j < TML.STYLING.length; j++) {
                line = line.replace(TML.STYLING[j][0], TML.STYLING[j][1]);
            }
            lines[i] = line;

            m = /^(?: {3}|\t)(\*|\d) (.*)$/.exec(line);
            if (m) {
                lines[i] = line.replace(/^( {3}|\t)\*|\d /, "");

                //    * Bullet list item
                //    1 Ordered list item
                if (!in_list) {
                    list_type = (m[1] === '*') ? 'ul' : 'ol';
                    if (in_table) {
                        lines.splice(i++, 0, "</table>");
                        in_table = false;
                    }
                    lines.splice(i++, 0, "<" + list_type + ">");
                    in_list = true;
                }
                lines.splice(i++, 0, '<li>');
                lines.splice(++i, 0, '</li>');
                continue;
            }

            m = /^\|(.*)\|$/.exec(line);
            if (m) {
                // | Table row |
                cols = line.split(/\|/);
                cols.shift();
                cols.pop(); // remove empty cols

                if (in_list) {
                    lines.splice(i++, 0, "</" + list_type + ">");
                    in_list = false;
                }
                if (!in_table) {
                    lines.splice(i++, 0, '<table class="tml">');
                    in_table = true;
                }
                lines.splice(i++, 0, '<tr><td>');
                lines[i] = cols.join('</td><td>');
                lines.splice(++i, 0, '</td></tr>');
                continue;
            }

            // Not a list item or a table row
            if (in_list) {
                if (!/^( {3}|\t)/.test(line)) {
                    lines.splice(i++, 0, '</' + list_type + '>');
                    in_list = false;
                }
            } else if (in_table) {
                lines.splice(i++, 0, '</table>');
                in_table = false;
            }

            m = /^---(\++) (.*)$/.exec(line);
            if (m) {
                lines[i] = '<h' + m[1].length + '>' + m[2] + '</h' + m[1].length + '>';
            }
        }

        // Clean up
        if (in_list) {
            lines.push('</' + list_type + '>');
        } else if (in_table) {
            lines.push('</table>');
        }

        text = lines.join(' ');

        return text.replace(
            /PLACEHOLDER(\d+);/g,
            function (m, idx) {
                return removed[idx];
            }
        );
    },

    // Render a set of reports, each being a hash of
    // { level: text: }
    render_reports : function(reports) {
        var i, curClass, html = '', pending = '';

        for (i = 0; i < reports.length; i++) {
            if (reports[i].level !== curClass) {
                if (pending.length > 0) {
                    html += '<div class="' + curClass + '">' + TML.render(pending) + '</div>';
                    pending = '';
                }
                curClass = reports[i].level;
            }
            pending += reports[i].text + "\n";
        }
        if (pending.length > 0) {
            html += '<div class="' + curClass + '">' + TML.render(pending) + '</div>';
        }
        return html;
    }
};
