/*jslint regexp: true, browser: true */

/* Don't use // style comments, or you'll break the stupid minifier  */
/* Hack to support nyroModal with jQuery 1.8, which removed $.curCss.
 * Upgrading to nyroModal V2 is another project - it has a different API.
 * Sigh.
 */
if (!$.curCSS) {
    $.curCSS = $.css;
}

var configure = (function ($) {

	"use strict";

	var expertsMode = '',
	    tabLinks = {},
        menuState = {
            main: undefined,
            defaultSub: {},
            defaultMain: undefined,
            allOpened: -1
        },
        infoMode = '',
        allImagesLoaded = false,

        setMain = function (inId) {
            menuState.main = inId;
        },
        getMain = function () {
            return menuState.main;
        },
        setSub = function (inMainId, inSubId) {
            menuState[inMainId] = inSubId;
        },
        getSub = function (inMainId) {
            return menuState[inMainId];
        },

        /**
        Translates a value to a readable string that makes sense in a form.
        For instance, 'false' gets translated to 'off' with checkboxes.
        
        Possible types:
        URL
        PATH
        URLPATH
        STRING
        BOOLEAN
        NUMBER
        SELECTCLASS
        SELECT
        REGEX
        OCTAL
        COMMAND
        PASSWORD
        PERL (?)
        */
        createHumanReadableValueString = function (type, value) {
            if (type === 'NUMBER') {
                /* do not convert numbers */
                return value;
            }
            if (type === 'BOOLEAN') {
                if (configure.utils.isTrue(value)) {
                    return 'on';
                }
                return 'off';
            }
            if (!value.length) {
                return '""';
            }
            /* all other cases */
            return value;
        },

        getUrlParam = function (name) {
            return decodeURIComponent((new RegExp(name + '=' + '(.+?)(&|$)').exec(location.search) || [,""])[1]);
        },

        newHideContent = function (elts, settings, callback) {
            elts.contentWrapper.hide();
            callback();
        },

        loadImage = function (el) {
            var url,
                img;
            if (!el.title || el.title === '') {
                return;
            }
            url = el.title;
            el.title = 'Click to enlarge';

            img = new Image();
            $(img).load(function () {
                var w = this.width,
                    h = this.height,
                    MAX_H = 120,
                    MAX_W = 120;
                /* set the image hidden by default */
                $(img).hide();
                /* Scale to max 64 height, max 150 width */
                if (w * MAX_H / MAX_W > h) {
                    this.height = Math.round(h * MAX_W / w);
                    this.width = MAX_W;
                } else {
                    this.width = Math.round(w * MAX_H / h);
                    this.height = MAX_H;
                }

                $(el).append(this);
                $(this).wrap("<a href='" + url + "' class='nyroModal'></a>");
                $('.nyroModal').nyroModal({
                    hideContent: newHideContent
                });
                $(this).fadeIn();
            });
            $(img).attr('src', url);
        };

	return {

		toggleInfoMode: function () {
            var antimode = infoMode;
            infoMode = (antimode === 'none' ? '' : 'none');
            $('.configureInfoText').each(function () {
                if (infoMode === 'none') {
                    $(this).addClass('foswikiMakeHidden');
                } else {
                    $(this).removeClass('foswikiMakeHidden');
                }
            });
            $('.configureNotInfoText').each(function () {
                if (antimode === 'none') {
                    $(this).addClass('foswikiMakeHidden');
                } else {
                    $(this).removeClass('foswikiMakeHidden');
                }
            });
        },

		toggleExpertsMode: function (modeName) {
		    var mode = getUrlParam(modeName),
		        antimode;
            if (mode !== undefined && mode !== '') {
                /* convert value to a css value */
                expertsMode = (mode === '1' ? '' : 'none');
            } else {
                /* toggle */
                expertsMode = (expertsMode === 'none' ? '' : 'none');
            }

            antimode = (expertsMode === 'none' ? '' : 'none');
            /* toggle table rows */
            $('tr.configureExpert').each(function () {
                $(this).css("display", expertsMode);
            });
            $('tr.configureNotExpert').each(function () {
                $(this).css("display", antimode);
            });
            /* toggle links */
            $('a.configureExpert').each(function () {
                $(this).css("display", expertsMode);
            });
            $('a.configureNotExpert').each(function () {
                $(this).css("display", antimode);
            });
        },

        getDefaultSub: function (inMainId) {
            return menuState.defaultSub[inMainId];
        },

        setDefaultSub: function (inMainId, inSubId) {
            if (menuState.defaultSub[inMainId]) {
                return;
            }
            menuState.defaultSub[inMainId] = inSubId;
        },

        /**
           Returns an object with properties:
           main: main section id
           sub: sub section id (if any)
        */
        getSectionParts: function (anchor) {
            var anchorPattern = new RegExp(/^#*(.*?)(\$(.*?))*$/),
                matches = anchor.match(anchorPattern),
                main = '',
                sub = '';
            if (matches && matches[1]) {
                main = matches[1];
            }
            if (matches && matches[3]) {
                main = matches[3];
                sub = matches[1] + '$' + main;
            }
            return {
                main: main,
                sub: sub
            };
        },

        /*
        Set the default section.
        
          sub states are stored like this:
          var sub = 'Language';
          menuState[menuState.main].sub = sub;
        */
        initSection: function () {
            var href = $(".configureRootTab > li > a").attr("href");
            if (href) {
                menuState.defaultMain = href.split("#")[1];
            }
            if (document.location.hash && document.location.hash !== '#') {
                this.showSection(document.location.hash);
            } else {
                if ($("#WelcomeBody").length) {
                    this.showSection('Welcome');
                } else {
                    this.showSection('Introduction');
                }
            }
        },

        showSection: function (anchor) {
            var sectionParts,
                mainId,
                subId,
                oldMainId,
                currentMainElement,
                newMainElement,
                oldSubId,
                oldsub,
                currentSubElement,
                sub,
                newSubElement,
                url,
                subName;

            url = document.location.toString().split("#")[0];
            sectionParts = this.getSectionParts(anchor);
            mainId = sectionParts.main;
            subId = tabLinks[mainId] ? (sectionParts.sub || getSub(mainId) || this.getDefaultSub(mainId)) : this.getDefaultSub(mainId);

            if (!tabLinks[mainId]) {
                mainId = menuState.defaultMain;
                subId = undefined;
            }

            oldMainId = getMain();
            if (oldMainId !== mainId) {
                /* hide current main section */
                currentMainElement = $("#" + oldMainId + "Body");
                currentMainElement.removeClass("configureShowSection");

                /* show new main section */
                newMainElement = $("#" + mainId + "Body");
                newMainElement.addClass("configureShowSection");

                /* set main menu highlight */
                if (tabLinks[oldMainId]) {
                    $(tabLinks[oldMainId]).removeClass("configureMenuSelected");
                }
                if (tabLinks[mainId]) {
                    $(tabLinks[mainId]).addClass("configureMenuSelected");
                }
            }

            /* hide current sub section */
            oldSubId = getSub(oldMainId);
            if (oldSubId) {
                oldsub = oldSubId;
                oldsub = oldsub.replace(/\$/g, "\\$");
                oldsub = oldsub.replace(/#/g, "\\#");
                currentSubElement = $("#" + oldsub + "Body");
                currentSubElement.removeClass('configureShowSection');
            }

            /* show new sub section */
            if (subId) {
                sub = subId;
                sub = sub.replace(/\$/g, "\\$");
                sub = sub.replace(/#/g, "\\#");
                newSubElement = $("#" + sub + "Body");
                newSubElement.addClass('configureShowSection');
            }

            /* set sub menu highlight */
            if (tabLinks[oldSubId]) {
                $(tabLinks[oldSubId]).removeClass("configureMenuSelected");
            }
            if (subId && tabLinks[subId]) {
                $(tabLinks[subId]).addClass("configureMenuSelected");
            }

            setMain(mainId);
            setSub(mainId, subId);

            if (mainId || subId) {
                if (subId !== undefined) {
                    subName = subId.split("$")[1];
                    window.history.pushState(undefined, "Configure / " + mainId + " / " + subName, url + "#" + subId);
                } else if (mainId !== undefined) {
                    window.history.pushState(undefined, "Configure / " + mainId, url + "#$" + mainId);
                } else {
                    window.history.pushState(undefined, "Configure", url);
                }
            }

            if (menuState.allOpened === 1) {
                /* we want to use anchors to jump down */
                return true;
            }
            return false;
        },

        /**
        Support for the Expand/Close All button
        
        This is the preferred way to toggle elements.
        Should be done for Expert settings and Info blocks as well.
        */
        toggleSections: function () {
            var body = $("body"),
                newMain;
            if (menuState.allOpened === -1) {
                /* open all sections */
                body.removeClass('configureShowOneSection');
            } else {
                /* hide all sections */
                body.addClass('configureShowOneSection');
                /* open current section */
                newMain = menuState.main;
                menuState.main = '';
                this.showSection(newMain);
            }

            menuState.allOpened = -menuState.allOpened;
        },

        initTabLinks: function () {
            var that = this;
            $(".tabli a").each(function () {
                var sectionParts = that.getSectionParts(this.hash);
                this.sectionId = sectionParts.main;
                if (sectionParts.sub) {
                    this.sectionId = sectionParts.sub;
                    that.setDefaultSub(sectionParts.main, sectionParts.sub);
                }
                tabLinks[this.sectionId] = $(this).parent().get(0);
            });
        },

        imgOnDemand: function () {
            if (!allImagesLoaded) {
                var p = $(window).height() + $(window).scrollTop();
                $('.loadImage').each(function () {
                    if ($(this).offset().top < p + 50) {
                        loadImage(this);
                        $(this).removeClass('loadImage');
                    }
                });
                allImagesLoaded = (p >= $(document).height());
            }
        },

        /**
        Initializes the 2 states of "reset to default" links.
        State 1: restore to default
        State 2: undo restore
        */
        initDefaultLink: function (link) {
            /* extract type */
            var type = link.className.split(" ")[0],
                label;

            link.type = type;

            /* retrieve value from title tag */
            if (link.type === 'OCTAL') {
                link.defaultValue = parseInt(unescape(link.title), 8).toString(8);
            } else {
                link.defaultValue = unescape(link.title);
            }

            /* set link label states */
            link.setDefaultLinkText = 'use default';
            link.undoDefaultLinkText = 'use stored value';

            /* set defaults */
            link.title = '';

            label = $('.configureDefaultValueLinkLabel', link)[0];
            if (label) {
                label.innerHTML = link.setDefaultLinkText;
            }
        },

        showDefaultLinkToolTip: function (link) {
            var template = $("#configureToolTipTemplate").html(),
                contents;

            template = template.replace(/VALUE/g, createHumanReadableValueString(link.type, link.defaultValue));
            template = template.replace(/TYPE/g, link.type);

            contents = $('.configureDefaultValueLinkValue', link)[0];
            $(contents).html(template);
        }

	};
}(jQuery));


configure.utils = (function () {
    "use strict";

    return {

        /**
        Checks if a value can be considered true.
        */
        isTrue: function (v) {
            if (v === 1 || v === '1' || v === 'on' || v === 'true') {
                return 1;
            }
            return 0;
        },

        /*
        Quote a name per CSS quoting rules so that it can be used as a JQuery selecto
        */
        quoteName: function (name) {
            var instr = name.split(""),
                out = '',
                i,
                c;
            for (i = 0; i < name.length; i = i + 1) {
                c = instr[i];
                if ("!\"#$%&'()*+,./:;<=>?@[\\]^`{|} ~".indexOf(c) >= 0) {
                    out = out + '\\' + (c === ':' ? '\\3a' : c);
                } else {
                    out = out + c;
                }
            }
            return out;
        }
    };

}());

/**
Global function
Called from "reset to default" link.
Values are set in UIs/Value.pm
*/
function resetToDefaultValue(inLink, inFormType, inName, inValue) {
    "use strict";
    var name = unescape(inName),
        elem = document.forms.update[name],
        value,
        oldValue,
        type,
        label,
        index,
        i;

    if (!elem) {
        return false;
    }

    value = unescape(inValue);
    if (inLink.oldValue) {
        value = inLink.oldValue;
    }

    type = elem.type;

    if (type === 'checkbox') {
        oldValue = elem.checked;
        elem.checked = value;
    } else if (type === 'select-one') {
        /* find selected element */
        for (i = 0; i < elem.options.length; i = i + 1) {
            if (elem.options[i].value === value) {
                index = i;
                break;
            }
        }
        oldValue = elem.options[elem.selectedIndex].value;
        elem.selectedIndex = index;
    } else if (type === 'radio') {
        oldValue = elem.checked;
        elem.checked = value;
    } else {
        /* including type='text'  */
        if (inLink.type === 'OCTAL') {
            oldValue = parseInt(elem.value, 8).toString(8);
            elem.value = parseInt(value, 8).toString(8);
        } else {
            oldValue = elem.value;
            elem.value = value;
        }
    }

    label = $('.configureDefaultValueLinkLabel', inLink)[0];
    if (!inLink.oldValue) {
        /* we have just set the default value */
        /* prepare undo link */
        label.innerHTML = inLink.undoDefaultLinkText;
        inLink.oldValue = oldValue;
    } else {
        /* we have just set the old value */
        label.innerHTML = inLink.setDefaultLinkText;
        inLink.oldValue = null;
    }

    return false;
}

/**
Global function.
Opens/closes all info blocks.
*/
function toggleInfo(inId) {
    "use strict";
    var twistyElement = $("#info_" + inId);
    if (twistyElement) {
        if (twistyElement.hasClass("foswikiMakeHidden")) {
            twistyElement.removeClass("foswikiMakeHidden");
        } else {
            twistyElement.addClass("foswikiMakeHidden");
        }
    }
    return false;
}

/* SELECTORS */

var enableWhenSomethingChangedElements = [];
var showWhenNothingChangedElements = [];

/*
Global fuction
Value changes. Event when a value is edited; enables the save changes
button. Also clicks feedback request button(s) for auto-feedback items.
The ^= is because 'feedreq' is followed by a button number.
 */
function valueChanged(el) {
    "use strict";
    switch (el.type.toLowerCase()) {
    case "select-one":
    case "select-multiple":
    case "textarea":
    case "text":
    case "password":
    case "radio":
    case "checkbox":
       if( $('[id^="' + configure.utils.quoteName(el.name) + 'feedreq"]').filter('[value="~"]').click().size() > 0 ) {
           break;
       }
        /* No feedback button found, fall through to default */
    default:
        var unsaved = { id:'{ConfigureGUI}{Unsaved}status', value:'Not a button' };
        doFeedback(unsaved);
        break;
    }
    $(el).addClass('foswikiValueChanged');

    $(showWhenNothingChangedElements).each(function () {
        $(this).addClass('foswikiHidden');
    });

    $(enableWhenSomethingChangedElements).each(function () {
        var controlTypes = ['Submit', 'Button', 'InputField'],
            jlen = controlTypes.length,
            j,
            ct;
        $(this).removeClass('foswikiHidden');
        for (j = 0; j < jlen; j = j + 1) {
            ct = 'foswiki' + controlTypes[j];
            if ($(this).hasClass(ct + 'Disabled')) {
                $(this).removeClass(ct + 'Disabled');
                $(this).addClass(ct);
            }
        }
        $(this).disabled = false;
    });
}

function valueOf($el) {
    "use strict";
    if ($el.attr("type") === "checkbox") {
        return $el.is(":checked");
    }
    return $el.val();
}

function submitform() {
    "use strict";
    document.update.submit();
}

/**
 * jquery init 
 */
$(document).ready(function () {
    "use strict";
    $(".enableWhenSomethingChanged").each(function () {
        enableWhenSomethingChangedElements.push(this);
        if (this.tagName.toLowerCase() === 'input') {
            /* disable the Save Changes button until a change has been made */
            /* we won't use this until an AJAX call has been implemented to make
	       this fault proof
	       $(this).attr('disabled', 'disabled');
	       $(this).addClass('foswikiSubmitDisabled');
	       $(this).removeClass('foswikiSubmit');
	    */
            var placeholder = 1;
        } else {
            $(this).addClass('foswikiHidden');
        }
    });
    configure.initTabLinks();

    $(".showWhenNothingChanged").each(function () {
        showWhenNothingChangedElements.push(this);
    });
    $(".tabli a").click(function () {
        return configure.showSection(this.sectionId);
    });
    $("a.configureExpert").click(function () {
        configure.toggleExpertsMode();
        return false;
    });
    $("a.configureNotExpert").click(function () {
        configure.toggleExpertsMode();
        return false;
    });
    $("a.configureInfoText").click(function () {
        configure.toggleInfoMode();
        return false;
    });
    $("a.configureNotInfoText").click(function () {
        configure.toggleInfoMode();
        return false;
    });
    $("a.configureDefaultValueLink").each(function () {
        configure.initDefaultLink(this);
    });
    $("a.configureDefaultValueLink", $("div.configureRootSection")).mouseover(function () {
        configure.showDefaultLinkToolTip(this);
    });
    $(".configureToggleSections a").click(function () {
        configure.toggleSections();
    });
    $("input.foswikiFocus").each(function () {
        this.focus();
    });
    $(".configureRootSection table.configureSectionValues div.configureError").each(function () {
        var row = $(this).closest('tr').get(0);
        if (row) {
            $(row).removeClass('configureExpert');
        }
    });
    $(".configureRootSection table.configureSectionValues div.configureWarning").each(function () {
        var row = $(this).closest('tr').get(0);
        if (row) {
            $(row).removeClass('configureExpert');
        }
    });
    $("#closeMessages").click(function () {
        $("#messages").hide();
        return false;
    });
    var add_dependency = function ($el, name, cb) {
        var test = $el.attr("data-" + name);
        //$el.attr("data-" + name, "");
        // Add change handlers to all vars, identified by {\w+}{... syntax
        test = test.replace(/((?:\{\w+\})+)/g, function (str, p1, offset) {
            var selector = '[name="' + p1 + '"]';
            $(selector).change(function () {
                $el.triggerHandler(name + '_change');
            });
            return "valueOf($('" + selector + "'))";
        });
        // Bind a change event handler to this dependent, which will be fired if any of
        // the things it depends on changes.
        $el.bind(name + '_change', function (e) {
            cb($el, eval('(' + test + ')') ? true : false);
        });
        // Set up initial conditions by triggering the handler
        $el.triggerHandler(name + '_change');
    };

    $("[data-displayif]").each(function () {
        add_dependency($(this), "displayif", function ($el, tf) {
            $el.toggle(tf);
        });
    });
    $("[data-enableif]").each(function () {
        add_dependency($(this), "enableif", function ($el, tf) {
            if (tf) {
                $el.find("input,textarea").removeAttr('disabled').removeClass('foswikiSubmitDisabled');
            } else {
                $el.find("input,textarea").attr('disabled', 'disabled').addClass('foswikiSubmitDisabled');
            }
        });
    });

    // make sticky
    $('.navigation').affix({
      offset: {
        top: 0,
        bottom: 50
      }
    });
    
    $(".extensionsHelp").click(function() {
        $(".configureExtensionsHelp").toggleClass("foswikiHidden");
    });

    configure.toggleExpertsMode('expert');
    configure.toggleInfoMode();
    configure.initSection();
    $(window).scroll(function () {
        configure.imgOnDemand();
    });
    configure.imgOnDemand();
});

function setSubmitAction(button,action) {
    "use strict";
    $(button.form).find('input[type="hidden"][name="action"]').val(action? action:button.value);
    return true;
}

/* ---------------------------- FEEDBACK -------------------------- */

function doFeedback(key, pathinfo) {

    "use strict";

    /* Make (and post) an http(s) request for feedback.
     *
     * First, some private infrastructure:
     */

    /* multipart/form-data item and body construction */

    var boundary = '------Foswiki-formboundary' + (new Date()).getTime() + Math.floor(Math.random() * 1073741826).toString(),
        dashdash = '--',
        crlf = '\x0d\x0a',
        requestData = "",
        quoteKeyId = configure.utils.quoteName(key.id), /* Selector-encoded id of button that was clicked */
        KeyIdSelector = '#' + quoteKeyId,
        posturl = document.location.pathname, /* Where to post form */
        working,
        stsWindowId;

    /* Add a named item from a form to the POST data */

    function postFormItem(name, value) {
        requestData = requestData + (dashdash + boundary + crlf) + 'Content-Disposition: form-data; name="' + name + '"' + crlf + crlf + value + crlf;
        return;
    }

    /* Effectively alert(), but supporting HTML content.  */
    function errorMessage(m) {
        if (m.length <= 0) {
            m = "Unknown error encountered";
        }
        /* nyroModal has wierd styles on <pre> that shrink to unreadability, 
         * switch to <code> as <pre> s used by CGI::Carp.
         */
        m = m.replace(/<(\/)?pre>/gi, "<$1code>").replace(/\n/g, '<br />');

        var contents = '<div id="configureFeedbackErrorWindow" class="configureFeedbackError" style="display:none">' + m + '</div>';
        /* If we already have the necessary DOM, re-use it.  Otherwise, we'll put it after the
         * last button pressed.  It's just a place we know how to find; the DOM is not visible.
         * It would be good to remove the DOM on close, but the various versions and states of
         * nyroModal make that more trouble than it's worth.  The wrapping div is for CSS.
         *
         * An invisible link is made modal.  That link's hashtag points tothe *id* of an invisible
         * div, which holds the content.  The *div* isn't modal.  The link is clicked once the 
         * div is created (or replaced), and nyroModal handles things from there.
         * Somewhat arcane, but that's the way nyroModal works.
         */

        if ($('#configureFeedbackErrorWindow').size() === 0) { /* Don't have error window */
            $(KeyIdSelector).after('<a href="#configureFeedbackErrorWindow" class="configureFeedbackError" id="configureFeedbackErrorLink"></a>' + contents);
            $('#configureFeedbackErrorLink').nyroModal().click();
        } else { /* Re-use the window and link */
            $('#configureFeedbackErrorWindow').replaceWith(contents);
            $('#configureFeedbackErrorLink').click();
        }
    }

    /* Error window - could go to status bar, but this seems to be effective. 
     * Extract content for a div, stripping page overhead.
     */

    function errorMessageFromHTML(m) {
        errorMessage(m.replace(/\r?\n/mgi, '<crlf>').replace(/^.*<body>/mgi, '').replace(/<\/body>.*$/mgi, '').replace(/<\/?html>/mgi, '').replace(/<crlf>/mg, "\n"));
    }

    /* Request handling:
     */

    if (posturl === undefined || !posturl.length) {
        posturl = $(KeyIdSelector).closest('form').attr('action');
    }

    /* Used for pathinfo testing */

    if (pathinfo !== undefined && pathinfo.length) {
        posturl = posturl + pathinfo;
    }

    /* Scan all the input controls in the form containing the button,
     * Include successful controls.  Skip disabled and nameless controls.
     */

    $(KeyIdSelector).closest('form').find(":input").each(function (index) {
        var opts,
            i,
            ilen,
            ctlName,
            txt;
        if (this.disabled) {
            return true;
        }
        ctlName = this.name;
        if (!this.name.length) {
            return true;
        }
        switch (this.type.toLowerCase()) {
        /* Ignore these */
        case "file":
        case "submit":
            /* Submit buttons weren't clicked, so don't report them */
        case "reset":
            /* Reset controls are never submitted, local action only */
            return true;

        case "select-one":
        case "select-multiple":
            /* Select sends the value of each selected option */
            opts = this.options;
            ilen = opts.length;
            for (i = 0; i < ilen; i = i + 1) {
                if (opts[i].selected && !opts[i].disabled) {
                    postFormItem(ctlName, opts[i].value);
                }
            }
            return true;

        case "textarea":
            /* Deal with end of line variations - must normalize to <cr><lf> */
            txt = this.value.replace(/([^\r])\n/mg, "$1\r\n").replace(/\r([^\n])/mg, "\r\n$1").replace(/\r\n/, crlf);
            postFormItem(ctlName, txt);
            return true;

        case "hidden":
        case "text":
        case "password":
            postFormItem(ctlName, this.value);
            return true;

        case "radio":
        case "checkbox":
            if (this.checked) {
                postFormItem(ctlName, this.value);
            }
            return true;

        default:
            break;
        }
        /* Ignore all other controls */
        return true;
    });

    /* Mark as feedback request */

    postFormItem('FeedbackRequest', key.id);
    postFormItem('FeedbackButtonValue', key.value);
    postFormItem('action', 'feedbackUI');

    /* End of post boundary */

    requestData = requestData + dashdash + boundary + dashdash + crlf;

    /* Update message area with busy status. I18n note:  hidden disabled field in pagebegin.tmpl with desired
     * text for internationalization.  E.g. <input type="hidden" disabled="disabled"
     * id="configureFeedbackWorkingText" value="Nous travaillons sur votre demande...">
     */

    if( key.id !== '{ConfigureGUI}{Unsaved}status' ) {
        working = $('#configureFeedbackWorkingText').filter(':hidden').filter(':disabled');
        if (working.size() === 1) {
            working = working.get(0).value;
        } else {
            working = 'Working...';
        }
        stsWindowId = key.id.replace(/feedreq\d+$/, 'status');
        $('#' + configure.utils.quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedbackPending configureInfo\"><span class=\"configureFeedbackPendingMessage\">" + working + "</span></div>");
    }

    /* Make the request
     * ** N.B. Definitely broken with jQuery 1.3 (unreliable selectors), 1.8.2 used.
     */

    $.ajax({
        url: posturl,
        cache: false,
        dataType: "text",
        type: "POST",
        global: false,
        contentType: "multipart/form-data; boundary=\"" + boundary + '"; charset=UTF-8',
        accepts: {
            text: "application/octet-stream; q=1, text/plain; q=0.8, text/html q=0.5"
        },
        headers: {
            'X-Foswiki-FeedbackRequest': 'V1.0'
        },
        processData: false,
        data: requestData,
        error: function (xhr, status, err) {
            if (!xhr.getAllResponseHeaders()) {
                /* User abort (no server response)
                 * There is no reliable status code to detect this, which
                 * happens when an AJAX request is cancelled by navigation.
                 */
                return true;
            }

            /* Clear "working" status */

            if( stsWindowId ) {
                $('#' + configure.utils.quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedback\"></div>");
            }

            /* Perhaps this should go to the status bar? */

            errorMessage('<h1>' + xhr.status.toString() + " " + xhr.statusText + "</h1>" + xhr.responseText);
            return true;
        },
        /* Using complete ensures that jQuery provides xhr on success.
         */

        complete: function (xhr, status) {
            if (status !== 'success') {
                return true;
            }

            /* Make sure this is a feedback response, as some browsers
             * seem to sometimes return other data...
             */
            if (xhr.getResponseHeader('X-Foswiki-FeedbackResponse') !== 'V1.0') {
                return true;
            }

            var data = xhr.responseText,
                items,
                i,
                kpair,
                sloc,
                delims,
                d,
                newval,
                opts,
                v,
                ii;

            /* Clear "working" status in case of errors or updates that don't target
             * the original status div.  This also updates the class.
             */
            if( stsWindowId ) {
                $('#' + configure.utils.quoteName(stsWindowId)).replaceWith("<div id=\"" + stsWindowId + "\" class=\"configureFeedback\"></div>");
            }

            /* Decide what kind of response we got. */

            if (data.charAt(0) !== '{') { /* Probably an error page with OK status */
                if (data.charAt(0) !== "\x7f") { /* Ignore no data response */
                    if (data.length <= 0) {
                        data = "Empty response received from feedback request";
                    }
                    errorMessageFromHTML(data);
                }
                return true;
            }

            /* Distribute response for each key to its status div or value */
            /* Hex constants used rather than octal for JSLint issue. */

            items = data.split("\x01");
            for (i = 0; i < items.length; i = i + 1) {
                /* IE sometimes doesn't do capturing split, so simulate one. */
                kpair = [];
                delims = ["\x02", "\x03"];
                for (d = 0; d < delims.length; d = d + 1) {
                    sloc = items[i].indexOf(delims[d]);
                    if (sloc >= 0) {
                        kpair[0] = items[i].substr(0, sloc);
                        kpair[1] = delims[d];
                        kpair[2] = items[i].substr(sloc + 1);
                        break;
                    }
                }
                if (d >= delims.length) {
                    errorMessage("Invalid opcode in feedback response");
                    return true;
                }
                if (kpair[1] === "\x02") {
                    $("#" + configure.utils.quoteName(kpair[0]) + "status").html(kpair[2]);
                } else if (kpair[1] === "\x03") {
                    newval = kpair[2].split(/\x04/);
                    $('[name="' + configure.utils.quoteName(kpair[0]) + '"]').each(function (idx, ele) {
                        switch (this.type.toLowerCase()) {
                        /* Ignore these for now (why update labels?) */
                        case "button":
                        case "file":
                        case "submit":
                        case "reset":
                            return true;

                        case "select-one":
                            opts = this.options;
                            var selected = -1;

                            for (i = 0; i < opts.length; i = i + 1) {
                                if (opts[i].value === newval[0]) {
                                    opts[i].selected = true;
                                    this.selectedIndex = i;
                                    selected = i;
                                } else {
                                    opts[i].selected = false;
                                }
                            }
                            if (selected < 0) {
                                errorMessage("Invalid value \"" + newval[0] + "\" for " + kpair[0]);
                            }
                            return true;

                        case "select-multiple":
                            opts = this.options;

                            for (i = 0; i < opts.length; i = i + 1) {
                                opts[i].selected = false;
                            }
                            this.selectedIndex = -1;
                            for (v = 0; v < newval.length; v = v + 1) {
                                for (ii = 0; ii < opts.length; ii = ii + 1) {
                                    if (opts[ii].value === newval[v]) {
                                        opts[ii].selected = true;
                                        if (v === 0) {
                                            this.selectedIndex = ii;
                                        }
                                        break;
                                    }
                                }
                                if (i >= opts.length) {
                                    errorMessage("Invalid value \"" + newval[v] + "\" for " + kpair[0]);
                                }
                            }
                            return true;

                        case "textarea":
                        case "hidden":
                        case "text":
                        case "password":
                            this.value = newval.join("");
                            return true;

                        case "radio":
                        case "checkbox":
                            this.checked = configure.utils.isTrue(newval[0]);
                            return true;
                        default:
                            break;
                        }
                        /* Ignore all other controls */
                        return true;
                    });

                } else { /* This is not possible */
                    errorMessage("Invalid opcode2 in feedback response");
                }
            }
            return true;
        }
    });

    /* Consume the button click */

    return false;
}
