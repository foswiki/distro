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
					  + this.x( content, '//style' ) 
					  + "<span class='ie_style'>" + this.x( close ) + "</span>";
			}
			, _style: "color: DarkSlateGray; font-weight: bold;"
		}
		, comment: { 
			  _match: /<!--[\w\W]*?-->/ 
			, _style: "color: #4040c2;"
		}
		, script: { 
			  _match: /(<script\s+[^>]*>)([\w\W]*?)(<\/script\s*>)/
			, _replace: function( all, open, content, close ) { 
				  return this.x( open, '//tag_start' ) 
					  + this.x( content, 'js' ) 
					  + this.x( close, '//tag_end' );
			} 
		}
		, style: { 
			  _match: /(<style\s+[^>]*>)([\w\W]*?)(<\/style\s*>)/
			, _replace: function( all, open, content, close ) { 
				  return this.x( open, '//tag_start' ) 
					  + this.x( content, 'css' ) 
					  + this.x( close, '//tag_end' );
			} 
		}
		// matches a starting tag of an element (with attrs)
		// like "<div ... >" or "<img ... />"
		, tag_start: { 
			  _match: /(<\w+)((?:[?%]>|[\w\W])*?)(\/>|>)/ 
			, _replace: function( all, open, content, close ) { 
				  return "<span class='tag_start'>" + this.x( open ) + "</span>" 
					  + this.x( content, '/tag_attrs' ) 
					  + "<span class='tag_start'>" + this.x( close ) + "</span>";
			}
			, _style: "color: navy; font-weight: bold;"
		} 
		// matches an ending tag
		// like "</div>"
		, tag_end: { 
			  _match: /<\/\w+\s*>|\/>/ 
			, _style: "color: navy; font-weight: bold;"
		}
		, entity: { 
			  _match: /&\w+?;/ 
			, _style: "color: blue;"
		}
                // tml variable
                , tml_variable: {
                  _match: /(?:%|\$percnt)[a-zA-Z][a-zA-Z0-9_:]*(?:%|\$percnt)/,
                  _style: "color:#ff0000;"
                }
                , tml_tag: {
                  _match: /((?:%|\$percnt)[a-zA-Z][a-zA-Z0-9_:]*{|}(?:%|\$percnt))/,
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
                  _match: /\n(#~~|~~~|\*~~)/,
                  _replace: "\n<span class='tml_glue'>$1</span>",
                  _style: "background:#ddd; color:green; font-weight:bold;"
                }
                // wikilink
                , tml_wikilink: {
                  _match: /\[\[.*?(\]\[.*?)?\]\]/,
                  _style: "text-decoration:underline"
                }
                // headings
                , tml_headings: {
                  _match: /---[\+#]+(!!)?/,
                  _style: "color:#4040c2; font-weight:bold;"
                }
                // tml_attrs
                , tml_attrs: {
                    _match: /([\w-]+)=(\".*\")/ 
                  , _replace: "<span class='attr_name'>$1</span>=<span class='attr_value'>$2</span>"
                  , _style: { attr_name:  "color: green;", attr_value: "color: maroon;" }
                }
                // pseudo vars used in format strings
                , tml_pseudovars: {
                  _match: /\$formfield\(.*?\)|\$expand\(.*?\)|\$formatTime\(.*?\)|\\"|(\$[a-z]+|\$nop\(.*?\))/,
                  _style: "color:black;"
               }
	}
	, tag_attrs: {
		// matches a name/value pair
		attr: {
			// before in $1, name in $2, between in $3, value in $4
			  _match: /(\W*?)([\w-]+)(\s*=\s*)((?:\'[^\']*(?:\\.[^\']*)*\')|(?:\\?\"[^\"]*(?:\\.[^\"]*)*\\?\"))/ 
			, _replace: "$1<span class='attr_name'>$2</span>$3<span class='attr_value'>$4</span>"
			, _style: { attr_name:  "color: green;", attr_value: "color: maroon;" }
		}
	}
}

