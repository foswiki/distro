/* Foswiki Markup recipe, derived from html recipe */
{
	  _name: 'tml'
	, _case: true
	, _main: {
		  doctype: { 
			  _match: /<!DOCTYPE\b[\w\W]*?>/ 
			, _style: "color: #CC6600;"
		}
		, ie_style: {
			  _match: /(<!--\[[^\]]*\]>)([\w\W]*?)(<!\[[^\]]*\]-->)/
			, _replace: function( all, open, content, close ) {
				return "<span class='ie_style'>" + this.x( open ) + "</span>" 
					  + this.x( content, '/_main' ) 
					  + "<span class='ie_style'>" + this.x( close ) + "</span>";
			}
			, _style: "color: DarkSlateGray;"
		}
		, comment: { 
			  _match: /<!--[\w\W]*?-->/ 
			, _style: "color: #4040c2;"
		}
		, script: { 
			  _match: /<script\s+[^>]*>[\w\W]*?<\/script\s*>/
			, _replace: function( all ) { 
				  return this.x( all, 'html' ); 
			} 
		}
		, style: {
			  _match: /<style\s+[^>]*>[\w\W]*?<\/style\s*>/
			, _replace: function( all ) { 
				  return this.x( all, 'html' ); 
			} 
		}
		// matches a starting tag of an element (with attrs)
		// like "<div ... >" or "<img ... />"
		, tag_start: { 
			  _match: /(<\w+)((?:[?%]>|[\w\W])*?)(\/>|>)/ 
			, _replace: function( all, open, content, close ) { 
				  return "<span class='tag_start'>" + this.x( open ) + "</span>" 
					  + this.x( content, '/_main' )
					  + "<span class='tag_start'>" + this.x( close ) + "</span>";
			}
			, _style: "color: navy;"
		} 
		// matches an ending tag
		// like "</div>"
		, tag_end: { 
			  _match: /<\/\w+\s*>|\/>/ 
			, _style: "color: navy;"
		}
		, entity: { 
			  _match: /&(?:\w+|#[0-9]+|#x[0-9a-fA-F]+);/ 
			, _style: "color: blue;"
		}
		, trailing_whitespace: {
			  _match: /([ \t]+)(\n)/
			, _replace: "<span class='trailing_whitespace'>$1</span>$2"
			, _style: "background-color: #CCCCCC;"
		}
		, set: { // only oneline setting for now
			  _match: /((?:^|\n)(?:   |\t)+)(\* )(Set|Local)([^=]+)(=)(.*?)([ \t]*)(?=\n|$)/
			, _replace: function( all, leading_space, bullet, verb, name, equals, value, trailing_whitespace ) {
				var ws = '';

        function encode(string) {
          var result = string.replace(/[\u00A0-\u00FF<>@]/g, function(c) {
            return '&#'+c.charCodeAt(0)+';';
          });
 
          return result;
        }

				if (trailing_whitespace.length > 0) {
					ws = "<span class='trailing_whitespace'>"
						+ trailing_whitespace
						+ "</span>";
				}
				return leading_space
					+ "<span class='tag_start'>"
					+ bullet
					+ verb
					+ "</span>"
					+ "<span class='tml_variable'>"
					+ name
					+ "</span>"
					+ equals
					+ encode(value)
					+ ws;
			}
		}
				// tml variable
				, tml_variable: {
				  _match: /(%|\$perce?nt)([a-zA-Z][a-zA-Z0-9_:]*)(%|\$perce?nt)/,
				  _replace: "<span class='tml_variable'>$1<!-- -->$2<!-- -->$3</span>",
				  _style: "color:#ff0000;"
				}
				, tml_tag_start: {
				  //SMELL: Doesn't cater for _DEFAULT with single quotes
				  _match: /((?:%|\$perce?nt)[a-zA-Z][a-zA-Z0-9_:]*{)([ \t\n]*)(?:(\\*")((?:\\[^%]|%[a-zA-Z][a-zA-Z0-9_:]*%|[^}"]%(?![a-zA-Z])|[^%"])*?)\3)?/,
				  _replace: function( all, start, spacing, quote, value ) {
					  var _DEFAULT = '';
					  if (quote) {
						  _DEFAULT = "<span class='attr_value'>"
							  + this.x( quote, '/tml_attrs' )
							  + this.x( value, '/_main' )
							  + this.x( quote, '/tml_attrs' )
							  + "</span>";
					  }
					  return "<span class='tml_variable'>"
						  + start
						  + "</span>"
						  + spacing
						  + _DEFAULT;
				  }
				}
				, tml_tag_end: {
				  _match: /(}(?:%|\$perce?nt))/,
				  _replace: "<span class='tml_variable'>$1</span>"
				}
				, tml_glue_tag_start: {
				  _match: /\n(%~~)( *[a-zA-Z][a-zA-Z0-9_:]*{)?/,
				  _replace: "\n<span class='tml_glue'>$1</span><span class='tml_variable'>$2</span>"
				}
				, tml_glue_tag_end: {
				  _match: /\n(~~~)( *}%)/,
				  _replace: "\n<span class='tml_glue'>$1</span><span class='tml_variable'>$2</span>"
				}
				// glue
				, tml_glue: {
				  _match: /\n(~~~|\*~~)/,
				  _replace: "\n<span class='tml_glue'>$1</span>",
				  _style: "background:#ddd; color:green; font-weight:bold;"
				}
				, tml_glue_comment: {
				  _match: /\n(#~~)(.*)/,
				  _replace: "\n<span class='tml_glue'>$1</span><span class='comment'>$2</span>"
				}
				// wikilink
				, tml_wikilink: {
				  _match: /(\[\[)(.*?(?:\]\[.*?)?)(\]\])/,
				  _replace: function( all, open, content, close ) {
					  return "<span class='tml_wikilink'>"
						  + open
						  + this.x( content, '/_main' )
						  + close
						  + "</span>";
				  },
				  _style: "padding-bottom: 1px; border-bottom-style: solid; border-bottom-color: #b5b5d1; border-bottom-width: 1px;"
				}
				// headings
				, tml_headings: {
				  _match: /---[\+#]+(!!)?/,
				  _style: "color:#4040c2; font-weight:bold;"
				}
				// tml_attrs
				, tml_attrs_single_quoted: { 
				  _match: /([\w-]+)=(\\*')((?:\\[^%]|%[a-zA-Z][a-zA-Z0-9_:]*%|[^}']%(?![a-zA-Z])|[^%'])*?)\2/ 
				  , _replace: function( all, name, quote, value ) {
						return "<span class='attr_name'>" + name + "</span>="
							  + "<span class='attr_value'>"
							  + this.x( quote, '/tml_attrs' ) 
							  + this.x( value, '/_main' )
							  + this.x( quote, '/tml_attrs' )
							  + "</span>";
				  }
				  , _style: { attr_name:  "color: green;", attr_value: "color: maroon;"}
				}
				, tml_attrs_double_quoted: { 
				  _match: /([\w-]+)=(\\*")((?:\\[^%]|%[a-zA-Z][a-zA-Z0-9_:]*%|[^}"]%(?![a-zA-Z])|[^%"])*?)\2/ 
				  , _replace: function( all, name, quote, value ) {
						return "<span class='attr_name'>" + name + "</span>="
							  + "<span class='attr_value'>"
							  + this.x( quote, '/tml_attrs' ) 
							  + this.x( value, '/_main' )
							  + this.x( quote, '/tml_attrs' )
							  + "</span>";
				  }
				}
				// pseudo vars used in format strings
				, tml_pseudovars: {
				  _match: /\$formfield\(.*?\)|\$expand\(.*?\)|\$formatTime\(.*?\)|\\"|(\$[a-z]+(\([^()]\))?)/,
				  _style: "color:orangered;"
				}
	}
	, tml_attrs: {
				// pseudo vars used in format strings
				 tml_pseudovars: {
				  _match: /\\+["']/
				}

	}
}

