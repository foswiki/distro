/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this file
as follows:

Copyright (C) Paul Johnston 1999 - 2002.

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

var md5 = {
    /**
     * Cut-down 8 bit MD5, taken from:
     * A JavaScript implementation of the RSA Data Security, Inc. MD5 Message
     * Digest Algorithm, as defined in RFC 1321.
     * Version 2.1 Copyright (C) Paul Johnston 1999 - 2002.
     * Other contributors: Greg Holt, Andrew Kepert, Ydnar, Lostinet
     * Distributed under the BSD License
     * See http://pajhome.org.uk/crypt/md5 for more info.
     */
    hex: function(s){
        return md5.binl2hex(md5.core_md5(md5.str2binl(s), s.length * 8));
    },

    /**
     * Calculate the MD5 of an array of little-endian words, and a bit length
     */
    core_md5: function(x, len) {
        /* append padding */
        x[len >> 5] |= 0x80 << ((len) % 32);
        x[(((len + 64) >>> 9) << 4) + 14] = len;

        var a =  1732584193;
        var b = -271733879;
        var c = -1732584194;
        var d =  271733878;

        for (var i = 0; i < x.length; i += 16) {
            var olda = a;
            var oldb = b;
            var oldc = c;
            var oldd = d;

            a = md5.ff(a, b, c, d, x[i+ 0], 7 , -680876936);
            d = md5.ff(d, a, b, c, x[i+ 1], 12, -389564586);
            c = md5.ff(c, d, a, b, x[i+ 2], 17,  606105819);
            b = md5.ff(b, c, d, a, x[i+ 3], 22, -1044525330);
            a = md5.ff(a, b, c, d, x[i+ 4], 7 , -176418897);
            d = md5.ff(d, a, b, c, x[i+ 5], 12,  1200080426);
            c = md5.ff(c, d, a, b, x[i+ 6], 17, -1473231341);
            b = md5.ff(b, c, d, a, x[i+ 7], 22, -45705983);
            a = md5.ff(a, b, c, d, x[i+ 8], 7 ,  1770035416);
            d = md5.ff(d, a, b, c, x[i+ 9], 12, -1958414417);
            c = md5.ff(c, d, a, b, x[i+10], 17, -42063);
            b = md5.ff(b, c, d, a, x[i+11], 22, -1990404162);
            a = md5.ff(a, b, c, d, x[i+12], 7 ,  1804603682);
            d = md5.ff(d, a, b, c, x[i+13], 12, -40341101);
            c = md5.ff(c, d, a, b, x[i+14], 17, -1502002290);
            b = md5.ff(b, c, d, a, x[i+15], 22,  1236535329);

            a = md5.gg(a, b, c, d, x[i+ 1], 5 , -165796510);
            d = md5.gg(d, a, b, c, x[i+ 6], 9 , -1069501632);
            c = md5.gg(c, d, a, b, x[i+11], 14,  643717713);
            b = md5.gg(b, c, d, a, x[i+ 0], 20, -373897302);
            a = md5.gg(a, b, c, d, x[i+ 5], 5 , -701558691);
            d = md5.gg(d, a, b, c, x[i+10], 9 ,  38016083);
            c = md5.gg(c, d, a, b, x[i+15], 14, -660478335);
            b = md5.gg(b, c, d, a, x[i+ 4], 20, -405537848);
            a = md5.gg(a, b, c, d, x[i+ 9], 5 ,  568446438);
            d = md5.gg(d, a, b, c, x[i+14], 9 , -1019803690);
            c = md5.gg(c, d, a, b, x[i+ 3], 14, -187363961);
            b = md5.gg(b, c, d, a, x[i+ 8], 20,  1163531501);
            a = md5.gg(a, b, c, d, x[i+13], 5 , -1444681467);
            d = md5.gg(d, a, b, c, x[i+ 2], 9 , -51403784);
            c = md5.gg(c, d, a, b, x[i+ 7], 14,  1735328473);
            b = md5.gg(b, c, d, a, x[i+12], 20, -1926607734);

            a = md5.hh(a, b, c, d, x[i+ 5], 4 , -378558);
            d = md5.hh(d, a, b, c, x[i+ 8], 11, -2022574463);
            c = md5.hh(c, d, a, b, x[i+11], 16,  1839030562);
            b = md5.hh(b, c, d, a, x[i+14], 23, -35309556);
            a = md5.hh(a, b, c, d, x[i+ 1], 4 , -1530992060);
            d = md5.hh(d, a, b, c, x[i+ 4], 11,  1272893353);
            c = md5.hh(c, d, a, b, x[i+ 7], 16, -155497632);
            b = md5.hh(b, c, d, a, x[i+10], 23, -1094730640);
            a = md5.hh(a, b, c, d, x[i+13], 4 ,  681279174);
            d = md5.hh(d, a, b, c, x[i+ 0], 11, -358537222);
            c = md5.hh(c, d, a, b, x[i+ 3], 16, -722521979);
            b = md5.hh(b, c, d, a, x[i+ 6], 23,  76029189);
            a = md5.hh(a, b, c, d, x[i+ 9], 4 , -640364487);
            d = md5.hh(d, a, b, c, x[i+12], 11, -421815835);
            c = md5.hh(c, d, a, b, x[i+15], 16,  530742520);
            b = md5.hh(b, c, d, a, x[i+ 2], 23, -995338651);

            a = md5.ii(a, b, c, d, x[i+ 0], 6 , -198630844);
            d = md5.ii(d, a, b, c, x[i+ 7], 10,  1126891415);
            c = md5.ii(c, d, a, b, x[i+14], 15, -1416354905);
            b = md5.ii(b, c, d, a, x[i+ 5], 21, -57434055);
            a = md5.ii(a, b, c, d, x[i+12], 6 ,  1700485571);
            d = md5.ii(d, a, b, c, x[i+ 3], 10, -1894986606);
            c = md5.ii(c, d, a, b, x[i+10], 15, -1051523);
            b = md5.ii(b, c, d, a, x[i+ 1], 21, -2054922799);
            a = md5.ii(a, b, c, d, x[i+ 8], 6 ,  1873313359);
            d = md5.ii(d, a, b, c, x[i+15], 10, -30611744);
            c = md5.ii(c, d, a, b, x[i+ 6], 15, -1560198380);
            b = md5.ii(b, c, d, a, x[i+13], 21,  1309151649);
            a = md5.ii(a, b, c, d, x[i+ 4], 6 , -145523070);
            d = md5.ii(d, a, b, c, x[i+11], 10, -1120210379);
            c = md5.ii(c, d, a, b, x[i+ 2], 15,  718787259);
            b = md5.ii(b, c, d, a, x[i+ 9], 21, -343485551);

            a = md5.add(a, olda);
            b = md5.add(b, oldb);
            c = md5.add(c, oldc);
            d = md5.add(d, oldd);
        }
        return Array(a, b, c, d);

    },

    /**
     * These functions implement the four basic operations the algorithm uses.
     */
    cmn: function(q, a, b, x, s, t) {
        return md5.add(md5.rol(md5.add(md5.add(a, q), md5.add(x, t)), s),b);
    },
    ff: function(a, b, c, d, x, s, t) {
        return md5.cmn((b & c) | ((~b) & d), a, b, x, s, t);
    },
    gg: function(a, b, c, d, x, s, t) {
        return md5.cmn((b & d) | (c & (~d)), a, b, x, s, t);
    },
    hh: function(a, b, c, d, x, s, t) {
        return md5.cmn(b ^ c ^ d, a, b, x, s, t);
    },
    ii: function(a, b, c, d, x, s, t) {
        return md5.cmn(c ^ (b | (~d)), a, b, x, s, t);
    },

    /**
     * Add integers, wrapping at 2^32. This uses 16-bit operations internally
     * to work around bugs in some JS interpreters.
     */
    add: function(x, y) {
        var lsw = (x & 0xFFFF) + (y & 0xFFFF);
        var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
        return (msw << 16) | (lsw & 0xFFFF);
    },

    /**
     * Bitwise rotate a 32-bit number to the left.
     */
    rol: function(num, cnt) {
        return (num << cnt) | (num >>> (32 - cnt));
    },

    /**
     * Convert a string to an array of little-endian words
     * If 8 is ASCII, characters >255 have their hi-byte silently ignored.
     */
    str2binl: function(str) {
        var bin = Array();
        var mask = (1 << 8) - 1;
        for(var i = 0; i < str.length * 8; i += 8) {
            bin[i>>5] |= (str.charCodeAt(i / 8) & mask) << (i%32);
        }
        return bin;
    },

    /**
     * Convert an array of little-endian words to a hex string.
     */
    binl2hex: function(binarray) {
        var hex_tab = "0123456789abcdef";
        var str = "";
        for(var i = 0; i < binarray.length * 4; i++) {
            str += hex_tab.charAt((binarray[i>>2] >> ((i%4)*8+4)) & 0xF) +
                hex_tab.charAt((binarray[i>>2] >> ((i%4)*8  )) & 0xF);
        }
        return str;
    }
};

var StrikeOne = {
    /**
     * Action on form submission (called outside this file for HTML Form submits)
     */
    submit: function(form) {
        //console.debug("Submit "+form.name);
        var input = form.validation_key;
        if (input && input.value && input.value.charAt(0) == '?') {
            input.value = StrikeOne.calculateNewKey(input.value);
        }
    },

    /**
     * calculate a new key response to validate the SUBMIT (called
     * outside this file for non HTML Form submits)
     */
    calculateNewKey: function(input) {
        if (input && input.charAt(0) == '?') {
            // Read the cookie to get the secret
            var secret = StrikeOne.readCookie('FOSWIKISTRIKEONE');
            // combine the validation key with the secret in a way
            // that can't easily be reverse-engineered, but can be
            // duplicated on the server (which also knows the secret)
            var key = input.substring(1);
            var newkey = md5.hex(key + secret);
            return newkey;
            //console.debug("Revise "+key+" + "+secret+" -> "+newkey);
        }
    },

    /**
     * Get and parse a document cookie value
     */
    readCookie: function(name) {
        var nameEQ = name + "=";
        var ca = document.cookie.split(';');
        for (var i = 0; i < ca.length; i++) {
            var c = ca[i];
            while (c.charAt(0) === ' ') {
                c = c.substring(1, c.length);
            }
            if (c.indexOf(nameEQ) === 0) {
                return c.substring(nameEQ.length, c.length);
            }
        }
        return null;
    }
};

/**
 * The parts of the message in validate.tmpl that are to be shown when
 * JS is available must be surrounded with a DIV that has the css class
 * 's1js_available' (meaning "show this when js is available").
 * Sections that must be shown when JS is *not* available use
 * <noscript>.
 * It is done this way because inline <script> tags may be taken out
 * by security.
 */
if (typeof jQuery != "undefined") {
    jQuery(function($) {
            $('.s1js_available').show();
        });
} else {
    var oldonload = window.onload;
    window.onload = function() {
        // Use the browser getElementsByClassName implementation if available
        if (document.getElementsByClassName != null) {
            var js_ok = document.getElementsByClassName('s1js_available');
            for (i = 0; i < js_ok.length; i++)
                js_ok[i].style.display = '';
        } else {
            // SMELL: use return jquery means instead
            var divs = document.getElementsByTagName('DIV');
            for (var i = 0; i < divs.length; i++) {
                if (/\bs1js_available\b/.test(divs[i].className))
                    divs[i].style.display = '';
            }
        }
        if (typeof oldonload == 'function')
            oldonload();
    };
}

// Maintained for compatibility - do not use
function foswikiStrikeOne(form) {
    return StrikeOne.submit(form);
}
