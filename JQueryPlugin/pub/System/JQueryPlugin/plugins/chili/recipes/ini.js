/*
 *  ini recipe for Chili syntax highlighter for jQuery
 */
{
          _name: 'ini'
        , _case: true
        , _main: {
                  sl_comment: { 
                          _match: /^\w*;.*/
                        , _style: 'color: green;'
                }
                , string: { 
                          _match: /(?:\'[^\'\\\n]*(?:\\.[^\'\\\n]*)*\')|(?:\"[^\"\\\n]*(?:\\.[^\"\\\n]*)*\")/
                        , _style: 'color: teal;'
                }
                , section: { 
                          _match: /\[.*\]/
                        , _style: 'color: maroon; font-weight: bold;'
                }
                , property: { 
                          _match: /\b(None|True|False)\b/
                        , _style: 'color: Purple; font-weight: bold;'
                }
        }
}

