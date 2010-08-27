/*
===============================================================================
Chili is the jQuery code highlighter plugin
...............................................................................
LICENSE: http://www.opensource.org/licenses/mit-license.php
WEBSITE: http://noteslog.com/chili/

Copyright 2009 / Sven Vetter, Trivadis AG
===============================================================================
*/

{
	  _name: "bash"
	, _case: true
	, _main: {
		com: {
			  _match: /#.*/ 
			, _style: "color: green;"
		}
		, string: {
			  _match: /([\"\'])(?:(?:[^\1\\\r\n]*?(?:\1\1|\\.))*[^\1\\\r\n]*?)\1/ 
			, _style: "color: purple;"
		}
		, number: {
			  _match: /\b[+-]?(\d*\.?\d+|\d+\.?\d*)([eE][+-]?\d+)?\b/ 
			, _style: "color: red;"
		}
		, hexnum: {
			  _match: /\b0[xX][\dA-Fa-f]+\b|\b[xX]([\'\"])[\dA-Fa-f]+\1/ 
			, _style: "color: red;"
		}
		, variable: {
			  _match: /@([$.\w]+|([`\"\'])(?:(?:[^\2\\\r\n]*?(?:\2\2|\\.))*[^\2\\\r\n]*?)\2)/
			, _replace: '<span class="keyword">@</span><span class="variable">$1</span>'
			, _style: "color: #4040c2;"
		}
		, keyword: {
			  _match: /\b(?:alias|break|continue|export|for|in|case|esac|done|exit|function|if|then|else|elif|fi|do|return|local|unalias|unset|typeset|true|false|printf|pwd|let|echo|eval|bg|fg|kill|read|type|until)\b/
			, _style: "color: navy;"
		}
		, 'function': {
			  _match: /\b(?:cat|rm|mv|cp|cd|mkdir|rmdir|chmod|chgrp|grep|tar|sed|awk)\b/
			, _style: "color: #e17100;"
		}
		, id: {
			  _match: /[$\w]+/ 
			, _style: "color: maroon;"
		}
	}
}

