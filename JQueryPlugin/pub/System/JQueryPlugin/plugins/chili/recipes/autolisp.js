/*
 *  Autolisp recipe for Chili syntax highlighter for jQuery
 */
{
          _name: 'autolisp'
        , _case: true
        , _main: {
                  sl_comment: { 
                          _match: /;.*/
                        , _style: 'color: green;'
                }
                , string: { 
                          _match: /(?:\'[^\'\\\n]*(?:\\.[^\'\\\n]*)*\')|(?:\"[^\"\\\n]*(?:\\.[^\"\\\n]*)*\")/
                        , _style: 'color: teal;'
                }
                , num: { 
                          _match: /\b[+-]?(?:\d*\.?\d+|\d+\.?\d*)(?:[eE][+-]?\d+)?\b/
                        , _style: 'color: red;'
                }
                , statement: { 
                          _match: /\b(cond|foreach|if|progn|repeat|while|alert|exit|nil|NIL|pi|quit|setq|setvar|t|T|abs|and|angle|angtof|angtos|atan|atof|atoi|boundp|cos|distance|eq|equal|exp|expt|fix|float|log|logand|logior|lsh|max|min|minusp|not|null|or|sqrt|zerop|append|caddr|cadr|cal|car|cdddr|cdr|cons|length|list|listp|member|nth|reverse|subst|acad_colordlg|acad_helpdlg|acad_strlsort|action_tile|add_list|ads|alloc|apply|arx|arxload|ascii|atom|atoms-family|autoarxload|autoload|autoxload|boole|client_data_tile|close|command|cvunit|dictadd|dictnext|dictremove|dictrename|dictsearch|dimxtile|dimytile|done_dialog|end_image|end_list|eval|expand|fill_image|findfile|gc|gcd|get_attr|get_tile|getangle|getcfg|getcorner|getdist|getenv|getfiled|getint|getkword|getorient|getpoint|getreal|getstring|getvar|graphscr|grclear|grdraw|grread|grtext|grvecs|handent|help|initget|inters|lambda|last|load|load_dialog|mapcar|mem|menucmd|menugroup|mode_tile|namedobjdict|new_dialog|numberp|open|osnap|pause|polar|prin1|princ|print|prompt|quote|read|read-char|read-line|redraw|regapp|rem|rtos|set|set_tile|setcfg|setfunhelp|setview|sin|slide_image|snvalid|start_app|start_dialog|start_image|start_list|tablet|term_dialog|terpri|textbox|textpage|textscr|trace|trans|type|unload_dialog|untrace|vector_image|ver|vmon|vports|wcmatch|write-char|write-line|xdroom|xdsize|xload|xunload|assoc|chr|distof|entdel|entget|entlast|entmake|entmakex|entmod|entnext|entsel|entupd|itoa|nentsel|nentselp|ssadd|ssdel|ssget|ssgetfirst|sslength|ssmemb|ssname|ssnamex|sssetfirst|strcase|strcat|strlen|substr|tblnext|tblobjname|tblsearch)\b/
                        , _style: 'color: navy; font-weight: bold;'
                }
                , property: { 
                          _match: /\b(nil|t|T|NIL)\b/
                        , _style: 'color: Purple; font-weight: bold;'
                }
        }
}

