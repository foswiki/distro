/*
 * jQuery NatEdit plugin 1.0
 *
 * Copyright (c) 2008 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */

(function($) {

/****************************************************************************
 * for debugging 
 */
function writeDebug(msg) {
  if ($.natedit.defaults.debug) {
    var msg = "DEBUG: NatEdit - "+msg;
    if (window.console && window.console.log) { // firebug console
      window.console.log(msg);
    } else {
      //$("#natExtraDiv4").append(msg+"<br />");
      //alert(msg);
    }
  }
};

/*****************************************************************************
 * plugin definition
 */
$.natedit = {

  /***************************************************************************
   * widget constructor
   */
  build: function(options) {
    writeDebug("called natedit()");

    // build main options before element iteration
    var opts = $.extend({}, $.natedit.defaults, options);

    // We use a helper div to measure text. We wrap it an overflow: hidden
    // container to avoid lengthening the page scrollbar.

    // iterate and reformat each matched element
    return this.each(function() {

      var textarea = this;

      // build element specific options. 
      // note you may want to install the Metadata plugin
      var thisOpts = $.meta ? $.extend({}, opts, $(textarea).data()) : opts;

      // don't do both: disable autoMaxExpand if we autoExpand
      if (thisOpts.autoExpand) {
        thisOpts.autoMaxExpand = false;
      }

      $.natedit.initGui(textarea, thisOpts);
 
      /* establish auto max expand */
      if (thisOpts.autoMaxExpand) {
        $(textarea).addClass("natEditAutoMaxExpand");
        window.setTimeout(function() {$.natedit.autoMaxExpand(textarea)}, 1);
      }

      /* establish auto expand */
      if (thisOpts.autoExpand) {

        var $helper = $('<div class="natEditHelper" style="position: absolute; top: 0; left: 0;"></div>');
        $('body').append(
          $('<div style="position: absolute; top: 0; left: 0; width: 100px; height: 100px; overflow: hidden; visibility: hidden;"></div>').
          append($helper));

        var args = {
          textarea: textarea,
          height: $(textarea).height(),
          width: $(textarea).width(),
          helper: $helper
        };

        $(textarea).css('overflow', 'hidden');
        $(textarea).keydown(function() {
          $.natedit.autoExpand(args)
        }).keypress(function() {;
          $.natedit.autoExpand(args)
        });
        $.natedit.autoExpand(args);
      }
    });
  },

  /***************************************************************************
   * plugin defaults
   */
  defaults: {
    h1Button: '<li class="natEditH1Button"><a href="javascript:void(0)" title="Level 1 headline"><span>H1</span></a></li>',
    h2Button: '<li class="natEditH2Button"><a href="javascript:void(0)" title="Level 2 headline"><span>H2</span></a></li>',
    h3Button: '<li class="natEditH3Button"><a href="javascript:void(0)" title="Level 3 headline"><span>H3</span></a></li>',
    h4Button: '<li class="natEditH4Button"><a href="javascript:void(0)" title="Level 4 headline"><span>H4</span></a></li>',
    boldButton: '<li class="natEditBoldButton"><a href="javascript:void(0)" title="Bold"><span>Bold</span></a></li>',
    italicButton: '<li class="natEditItalicButton"><a href="javascript:void(0)" title="Italic"><span>Italic</span></a></li>',
    monoButton: '<li class="natEditMonoButton"><a href="javascript:void(0)" title="Monospace"><span>Monospace</span></a></li>',
    underlineButton: '<li class="natEditUnderlineButton"><a href="javascript:void(0)" title="Underline"><span>Underline</span></a></li>',
    strikeButton: '<li class="natEditStrikeButton"><a href="javascript:void(0)" title="Strike"><span>Strike</span></a></li>',
    leftButton: '<li class="natEditLeftButton"><a href="javascript:void(0)" title="Align left"><span>Left</span></a></li>',
    centerButton: '<li class="natEditCenterButton"><a href="javascript:void(0)" title="Center align"><span>Center</span></a></li>',
    rightButton: '<li class="natEditRightButton"><a href="javascript:void(0)" title="Align right"><span>Right</span></a></li>',
    justifyButton: '<li class="natEditJustifyButton"><a href="javascript:void(0)" title="Justify text"><span>Justify</span></a></li>',
    numberedButton: '<li class="natEditNumberedButton"><a href="javascript:void(0)" title="Numbered List"><span>Numbered List</span></a></li>',
    bulletButton: '<li class="natEditBulletButton"><a href="javascript:void(0)" title="Bullet List"><span>Bullet List</span></a></li>',
    indentButton: '<li class="natEditIndentButton"><a href="javascript:void(0)" title="Indent"><span>Indent</span></a></li>',
    outdentButton: '<li class="natEditOutdentButton"><a href="javascript:void(0)" title="Outdent"}%"><span>Outdent</span></a></li>',
    extButton: '<li class="natEditExtButton"><a href="javascript:void(0)" title="External link"><span>Ext.link</span></a></li>',
    intButton: '<li class="natEditIntButton"><a href="javascript:void(0)" title="Internal link"><span>Int.link</span></a></li>',
    mathButton: '<li class="natEditMathButton"><a href="javascript:void(0)" title="Mathematical formula (<nop>LaTeX)"><span>Math</span></a></li>',
    imageButton: '<li class="natEditImageButton"><a href="javascript:void(0)" title="Embed image"><span>Image</span></a></li>',
    verbatimButton: '<li class="natEditVerbatimButton"><a href="javascript:void(0)" title="Ignore wiki formatting"><span>Verbatim</span></a></li>',
    signatureButton: '<li class="natEditSignatureButton"><a href="javascript:void(0)" title="Your signature with timestamp"><span>Sign</span></a></li>',
    h1Markup: ['---+ ','%TOPIC%',''],
    h2Markup: ['---++ ','Headline text',''],
    h3Markup: ['---+++ ','Headline text',''],
    h4Markup: ['---++++ ','Headline text',''],
    boldMarkup: ['*', 'Bold text', '*'],
    italicMarkup: ['_', 'Italic text', '_'],
    monoMarkup: ['=', 'Monospace text', '='],
    underlineMarkup: ['<u>', 'Underlined text', '</u>'],
    strikeMarkup: ['<strike>', 'Strike through text', '</strike>'],
    leftMarkup: ['<div style="text-align:left">\n','Align left','\n</div>\n'],
    centerMarkup: ['<div style="text-align:center">\n','Center text','\n</div>\n'],
    rightMarkup: ['<div style="text-align:right">\n','Align right','\n</div>\n'],
    justifyMarkup: ['<div style="text-align:justify">\n','Justify text','\n</div>\n'],
    numberedListMarkup: ['   1 ','enumerated item',''],
    bulletListMarkup: ['   * ','bullet item',''],
    indentMarkup: ['   ','',''],
    outdentMarkup: ['','',''],
    extMarkup: ['[[http://...][','link text',']]'],
    intMarkup: ['[[','web.topic][link text',']]'],
    imagePluginMarkup: ['%IMAGE{"','Example.jpg','|400px|Caption text|frame|center"}%'],
    imageMarkup: ['<img src="%<nop>ATTACHURLPATH%/','Example.jpg','" title="Example" />'],
    mathMarkup: ['<latex title="Example">\n','\\sum_{x=1}^{n}\\frac{1}{x}','\n</latex>'],
    verbatimMarkup: ['<verbatim>\n','Insert non-formatted text here','\n</verbatim>\n'],
    signatureMarkup: ['-- ', '%WIKINAME%, ' - '%DATE%'],
    autoHideToolbar: false,
    hideToolbar: false,
    gotImagePlugin: false,
    gotMathModePlugin: false,
    autoMaxExpand:false,
    autoExpand:false,
    debug:false
  },

  /*************************************************************************
   * init the gui
   */
  initGui: function(textarea, opts) {
    writeDebug("called initGui");
    var $textarea = $(textarea);
    var $natEdit = $textarea.wrap('<div class="natEdit"></div>').parent();

    if (opts.hideToolbar) {
      writeDebug("no toolbar");
      return;
    }

    var width = $(textarea).width();

    // toolbar
    var $headlineTools = $('<ul class="natEditButtonBox"></ul>').
      append(
        $(opts.h1Button).click(function() {
          $.natedit.insertLineTag(textarea, opts.h1Markup);
        })).
      append(
        $(opts.h2Button).click(function() {
          $.natedit.insertLineTag(textarea, opts.h2Markup);
        })).
      append(
        $(opts.h3Button).click(function() {
          $.natedit.insertLineTag(textarea, opts.h3Markup);
        })).
      append(
        $(opts.h4Button).click(function() {
          $.natedit.insertLineTag(textarea, opts.h4Markup);
        }));

    var $textTools = $('<ul class="natEditButtonBox"></ul>').
      append(
        $(opts.boldButton).click(function() {
          $.natedit.insertTag(textarea, opts.boldMarkup);
        })).
      append(
        $(opts.italicButton).click(function() {
          $.natedit.insertTag(textarea, opts.italicMarkup);
        })).
      append(
        $(opts.monoButton).click(function() {
          $.natedit.insertTag(textarea, opts.monoMarkup);
        })).
      append(
        $(opts.underlineButton).click(function() {
          $.natedit.insertTag(textarea, opts.underlineMarkup);
        })).
      append(
        $(opts.strikeButton).click(function() {
          $.natedit.insertTag(textarea, opts.strikeMarkup);
        }));

    var $paragraphTools = $('<ul class="natEditButtonBox"></ul>').
      append(
        $(opts.leftButton).click(function() {
          $.natedit.insertTag(textarea, opts.leftMarkup);
        })).
      append(
        $(opts.centerButton).click(function() {
          $.natedit.insertTag(textarea, opts.centerMarkup);
        })).
      append(
        $(opts.rightButton).click(function() {
          $.natedit.insertTag(textarea, opts.rightMarkup);
        })).
      append(
        $(opts.justifyButton).click(function() {
          $.natedit.insertTag(textarea, opts.justifyMarkup);
        }));

    var $listTools = $('<ul class="natEditButtonBox"></ul>').
      append(
        $(opts.numberedButton).click(function() {
          $.natedit.insertLineTag(textarea, opts.numberedListMarkup);
        })).
      append(
        $(opts.bulletButton).click(function() {
          $.natedit.insertLineTag(textarea, opts.bulletListMarkup);
        })).
      append(
        $(opts.indentButton).click(function() {
          $.natedit.insertLineTag(textarea, opts.indentMarkup);
        })).
      append(
        $(opts.outdentButton).click(function() {
          $.natedit.insertLineTag(textarea, opts.outdentMarkup);
        }));


    var $objectTools = $('<ul class="natEditButtonBox"></ul>').
      append(
        $(opts.extButton).click(function() {
          $.natedit.insertTag(textarea, opts.extMarkup);
        })).
      append(
        $(opts.intButton).click(function() {
          $.natedit.insertTag(textarea, opts.intMarkup);
        })).
      append(
        $(opts.imageButton).click(function() {
          if (opts.gotImagePlugin) {
            $.natedit.insertTag(textarea, opts.imagePluginMarkup);
          } else {
            $.natedit.insertTag(textarea, opts.imageMarkup);
          }
        }));

    if (opts.gotMathModePlugin) {
      $objectTools.
        append(
          $(opts.mathButton).click(function() {
            $.natedit.insertTag(textarea, opts.mathMarkup);
          }));
    }

    $objectTools.
      append(
        $(opts.verbatimButton).click(function() {
          $.natedit.insertTag(textarea, opts.verbatimMarkup);
        })).
      append(
        $(opts.signatureButton).click(function() {
          $.natedit.insertTag(textarea, opts.signatureMarkup);
        }));
      
    var $toolbar = 
      $('<div class="natEditToolBar"></div>').
      append($headlineTools).
      append($textTools).
      append($listTools).
      append($paragraphTools).
      append($objectTools);

    if (width) {
      $toolbar.width(width);
    }

    if (opts.autoHideToolbar) {
      writeDebug("toggling toolbar on hover event");
      $toolbar.hide();

      var toolbarState = 0;
      function toggleToolbarState () {
        if (toolbarState < 0) 
          return;
        var tmp = textarea.value;
        if (toolbarState) {
          //writeDebug("slide down");
          $toolbar.slideDown("fast");
          //$toolbar.show();
          textarea.value = tmp;
        } else {
          //writeDebug("slide up");
          $toolbar.slideUp("fast");
          //$toolbar.hide();
          textarea.value = tmp;
        }
        if (opts.autoMaxExpand) {
          $.natedit.autoMaxExpand(textarea);
        }
        toolbarState = -1;
      }
      
      $textarea.focus(
        function() {
          toolbarState = 1;
          window.setTimeout(toggleToolbarState, 100);
        }
      );
      $textarea.blur(
        function() {
          toolbarState = 0;
          window.setTimeout(toggleToolbarState, 100);
        }
      );
    }

    $natEdit.prepend($toolbar);
  },

  /*************************************************************************
   * work horse 1
   */
  insertTag: function(txtarea, markup) {
    var tagOpen = markup[0];
    var sampleText = markup[1];
    var tagClose = markup[2];
    writeDebug("called insertTag("+tagOpen+", "+sampleText+", "+tagClose+")");
    txtarea.focus();
      
    $.natedit.getSelectionRange(txtarea);

    var startPos = txtarea.selectionStart;
    var endPos = txtarea.selectionEnd;
    var text = txtarea.value;
    var scrollTop = txtarea.scrollTop;
    var theSelection = text.substring(startPos, endPos);

    writeDebug("startPos="+startPos+" endPos="+endPos);

    if (!theSelection) {
      theSelection = sampleText;
    }

    if (theSelection.charAt(theSelection.length - 1) == " ") { 
      // exclude ending space char, if any
      subst = 
        tagOpen + 
        theSelection.substring(0, (theSelection.length - 1)) + 
        tagClose + " ";
    } else {
      subst = tagOpen + theSelection + tagClose;
    }

    txtarea.value = 
      text.substring(0, startPos) + subst +
      text.substring(endPos, text.length);

    // set new selection
    startPos += tagOpen.length;
    endPos = startPos + theSelection.length;
    txtarea.scrollTop = scrollTop;
    $.natedit.setSelectionRange(txtarea, startPos, endPos);
    $(txtarea).trigger("keypress");
  },

  /*************************************************************************
   * compatibility method for IE: this sets txtarea.selectionStart and
   * txtarea.selectionEnd of the current selection in the given textarea 
   */
  getSelectionRange: function(txtarea) {
     writeDebug("called getSelectionRange()");

     if (document.selection && !$.browser.opera) {    // IE
      writeDebug("IE");
      txtarea.focus();

      var text = txtarea.value;
      var c = "\001";
      var range = document.selection.createRange();
      var selection = range.text || "";
      var rangeCopy = range.duplicate();
      rangeCopy.moveToElementText(txtarea);
      range.text = c;
      var pos = (rangeCopy.text.indexOf(c));

      range.moveStart("character", -1);
      range.text = selection;


      if (pos < 0) {
        pos = text.length;
        selection = "";
      }

      txtarea.selectionStart = pos;

      if (selection == "") {
        txtarea.selectionEnd = pos;
      } else {
        txtarea.selectionEnd = pos + selection.length;
      }

    }
  },

  /*************************************************************************
   * set the selection
   */
  setSelectionRange: function(txtarea, start, end) {
    txtarea.focus();
    if (txtarea.createTextRange && !$.browser.opera) {
      var lineFeeds = txtarea.value.substring(0, start).replace(/[^\r]/g, "").length;
      var range = txtarea.createTextRange();
      range.collapse(true);
      range.moveStart('character', start-lineFeeds);
      range.moveEnd('character', end-start);
      range.select();
    } else { 
      txtarea.selectionStart = start;
      txtarea.selectionEnd = end;
    }
  },
 
  /*************************************************************************
   * work horse 2:
   * used for line oriented tags - like bulleted lists
   * if you have a multiline selection, the tagOpen/tagClose is added to each line
   * if there is no selection, select the entire current line
   * if there is a selection, select the entire line for each line selected
   */
  insertLineTag: function(txtarea, markup) {
    writeDebug("called inisertLineTag("+txtarea+", "+markup+")");
    var tagOpen = markup[0];
    var sampleText = markup[1];
    var tagClose = markup[2];

    $.natedit.getSelectionRange(txtarea);

    var startPos = txtarea.selectionStart
    var endPos = txtarea.selectionEnd;
    var text = txtarea.value;

    writeDebug("startPos="+startPos+" endPos="+endPos);

    // at this point we need to expand the selection to the \n before the startPos, and after the endPos
    while (startPos > 0 && 
      text.charCodeAt(startPos-1) != 13 &&
      text.charCodeAt(startPos-1) != 10) 
    {
      startPos--;
    }

    while (endPos < text.length && 
      text.charCodeAt(endPos) != 13 && 
      text.charCodeAt(endPos) != 10) 
    {
      endPos++;
    }

    writeDebug("startPos="+startPos+" endPos="+endPos);

    var scrollTop = txtarea.scrollTop;
    var theSelection = text.substring(startPos, endPos);

    if (!theSelection) {
      theSelection = sampleText;
    }

    var pre = text.substring(0, startPos);
    var post = text.substring(endPos, text.length);

    // test if it is a multi-line selection, and if so, add tagOpen&tagClose to each line
    var lines = theSelection.split(/\r?\n/);
    var isMultiline = lines.length>1?true:false;
    var modifiedSelection = '';
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      var subst;
      
      if (line.match(/^\s*$/)) {
        // don't append tagOpen to empty lines
        subst = line;
      } else {
        // special case - undent (remove 3 spaces, and bullet or numbered list if outdenting away)
        if ((tagOpen == '') && (sampleText == '') && (tagClose == '')) {
          subst = line.replace(/^   (\* |\d+ |\d+\. )?/, '');
        } else {
          subst = tagOpen + line + tagClose;
        }
      }

      modifiedSelection += subst;
      if (i+1 < lines.length) 
        modifiedSelection += '\n';
    }

    txtarea.value = pre + modifiedSelection + post;

    startPos += (isMultiline?0:tagOpen.length);
    endPos = startPos + modifiedSelection.length - (isMultiline?0:tagOpen.length-tagClose.length);

    $.natedit.setSelectionRange(txtarea, startPos, endPos);
    txtarea.scrollTop = scrollTop;
  },

  /*************************************************************************
   * adjust height of textarea to window height
   */
  autoMaxExpand: function(textarea) {
    //writeDebug("called autoMaxExpand("+textarea+")");
    var $textarea = $(textarea);


    // get new window height
    var windowHeight = $(window).height();
    if (!windowHeight) {
      windowHeight = window.innerHeight;
    }
    //writeDebug("windowHeight="+windowHeight);

    var offset = $textarea.offset({scroll:false});
    //writeDebug("offset="+offset.top);

    var newHeight = windowHeight-offset.top-90;
    //writeDebug("newHeight="+newHeight);

    $textarea.height(newHeight);
    
    window.setTimeout(function() {
      $(window).one("resize", function() {
        $.natedit.autoMaxExpand(textarea)
      });
    }, 100); 
  },

  /*************************************************************************
   * adjust height of textarea according to content
   */
  autoExpand: function(args) {
    //writeDebug("called autoExpand()");

    var now = new Date();
    //
    // don't do it too often
    if (args.time && now.getTime() - args.time.getTime() < 100) {
      //writeDebug("suppressing events within 100ms");
      return;
    }
    args.time = now;

    window.setTimeout(function() {
      var text = args.textarea.value+'x';
      if (text == args.lastText) {
        //writeDebug("suppressing events for same text");
        return
      };
      args.lastText = text;
      text = $.natedit.htmlEntities(text);
     

      // Get text styles and apply them to the helper.
      var style = {
        fontFamily: $(args.textarea).css('fontFamily')||'',
        fontSize: $(args.textarea).css('fontSize')||'',
        fontWeight: $(args.textarea).css('fontWeight')||'',
        fontStyle: $(args.textarea).css('fontStyle')||'',
        fontStretch: $(args.textarea).css('fontStretch')||'',
        fontVariant: $(args.textarea).css('fontVariant')||'',
        letterSpacing: $(args.textarea).css('letterSpacing')||'',
        wordSpacing: $(args.textarea).css('wordSpacing')||'',
        lineHeight: $(args.textarea).css('lineHeight')||'',
        textWrap: 'unrestricted'
      };
      args.helper.css(style);
      args.helper.width(args.width);

      //writeDebug("helper text="+text);
      args.helper.html(text);
      var height = args.helper.height() + 12;
      height = Math.max(args.height, height);
      //writeDebug("helper height="+height);
      $(args.textarea).height(height).width(args.width);
    },1);
  },

  /*************************************************************************
   * replace entities with real html
   */
  htmlEntities: function(text) { 
    var entities = {
      '&':'&amp;',
      '<':'&lt;',
      '>':'&gt;',
      '"':'&quot;',
      "\\n": "<br />"
    };
    for(i in entities) {
      text = text.replace(new RegExp(i,'g'),entities[i]);
    }
    return text;
  }
};

$.fn.natedit = $.natedit.build;

})(jQuery);


