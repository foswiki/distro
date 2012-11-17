/*jslint regexp: true, browser: true */

/* *** Update VERSION (below) on any change so browser/perl can cross-check.
 *
 * Don't use // style comments, or you'll break the stupid minifier
 */

var configure = (function ($) {

	"use strict";

        var VERSION = "v3.101";
        /* Do not merge, move or change format of VERSION, parsed by perl.
         */

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
/* Not with V2??      hideContent: newHideContent */
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
                /* IE doesn't do window.history.pushState.  https://github.com/balupton/history.js is an alternative,
                 * but it comes it a lot of baggage.  For now, just skip this for browsers that don't support
                 * window.history.
                 */
                if( window.history && window.history.pushState ) {
                    if (subId !== undefined) {
                        subName = subId.split("$")[1];
                        window.history.pushState(undefined, "Configure / " + mainId + " / " + subName, url + "#" + subId);
                    } else if (mainId !== undefined) {
                        window.history.pushState(undefined, "Configure / " + mainId, url + "#$" + mainId);
                    } else {
                        window.history.pushState(undefined, "Configure", url);
                    }
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
        },

        /* Update the tab summary icons and status summary line from the item error values.
         * Each item has a corresponding (key){s}errors hidden value, containing the item's
         * error and warning counts.  These are initally set with checker results with the
         * main page is built, and updated when changed by feedback.  updateIndicators
         * pushes the values up to the tabs and status line, mostly by adjusting classes.
         */

        updateIndicators: function () {
            /* Clear all existing indicators.
             * The first scan finds all tab links with error classes and removes them.
             * The second finds all visible Alerts divs and hides them.
             * This is done because there should be many fewer items with errors than
             * without.  Visiting only the items with errors minimizes work.
             */

            $('ul li a.configureWarn,ul li a.configureError,ul li a.configureWarnAndError').removeClass('configureWarn configureError configureWarnAndError' );
            $('div[id$="Alerts"].foswikiAlert').not('.foswikiAlertInactive').addClass('foswikiAlertInactive');

            /* Find each item's error value & propagate it upwards.
             * Items with neither errors nor warnings are disabled & can't contribute.
             */

            var totalErrors = 0,
                totalWarnings = 0,
                id,
                itemClass,
                alertDiv,
                alerts = [],
                alertIds = [],
                tab,
                tabName,
                tabNames,
                subTab,
                statusLine;

            $( '[name$="\\}errors"]:enabled' ).each(function (index) {
                var errors = this.value.split(' ');
                if( errors.length !== 2 ) {
                    return true;
                }
                /* N.B. All items processed have 1 or more issues */

                errors[0] = parseInt(errors[0],10);
                totalErrors += errors[0];
                errors[1] = parseInt(errors[1],10);
                totalWarnings += errors[1];

                /* Select this item's contribution to the tab's classes */

                if( (errors[0] !== 0) && (errors[1] !== 0) ) {
                    itemClass = 'configureWarnAndError';
                } else { if (errors[0] !== 0) {
                    itemClass = 'configureError';
                } else {
                    itemClass = 'configureWarn';
                }}
                var root;
                var tab = $( this ).parents('div.configureSubSection').last();
                if( tab.size() == 1 ) {
                    tabName = tab.find('a').get(0).name;
                    tabNames = tabName.split('$' );

                    /* Update subtab, if any */
                    if( tabNames.length === 2 ) {
                       root = $(tab).closest('div.configureRootSection');
                       subTab = $(root).find('ul.configureSubTab li a[href="' +
                                                configure.utils.quoteName('#' +
                                                                  tabName ) + '"]' );
                        if( subTab.size() == 1 ) {
                            if( !subTab.hasClass( 'configureWarnAndError' ) ) {
                                if( itemClass === 'configureWarnAndError' ) {
                                    subTab.removeClass('configureError configureWarn').addClass(itemClass);
                                } else { if( !subTab.hasClass( itemClass ) ) {
                                    subTab.addClass(itemClass);
                                    if( subTab.hasClass('configureWarn') &&
                                        subTab.hasClass('configureError') ) {
                                        subTab.removeClass('configureError configureWarn').addClass('configureWarnAndError');
                                    }
                                }}
                            }
                        }
                    }
                    /* Update main navigation tab */
                    tab = $('ul.configureRootTab li a[href="' +
                                         configure.utils.quoteName('#'+tabNames[1]) +'"]');
                } else {
                    tab =  $( this ).closest('div.configureRootSection');
                    root = tab;
                    if( tab.size() == 1 ) {
                        tabName = tab.find('a').get(0).name;
                         tab = $('ul.configureRootTab li a[href="' +
                                 configure.utils.quoteName('#'+tabName) +'"]');
                    }
                }

                if( tab.size() == 1 ) {
                    if( !tab.hasClass( 'configureWarnAndError' ) ) {
                        if( itemClass === 'configureWarnAndError' ) {
                            tab.removeClass('configureError configureWarn').addClass(itemClass);
                        } else { if( !tab.hasClass( itemClass ) ) {
                            tab.addClass(itemClass);
                            if( tab.hasClass('configureWarn') &&
                                tab.hasClass('configureError') ) {
                                tab.removeClass('configureError configureWarn').addClass('configureWarnAndError');
                            }
                        }}
                    }
                }

                /* Update section's Alert <div> error/warning counts */

                alertDiv = $(root).find('div[id$="Alerts"].foswikiAlert').first();
                if( alertDiv.size() == 1 ) {
                    id = alertDiv.attr('id');
                    if( alerts.hasOwnProperty(id) ) {
                        alerts[id].errors += errors[0];
                        alerts[id].warnings += errors[1];
                    } else {
                        alerts[id] = { errors: errors[0], warnings: errors[1] };
                        alertIds.push(id);
                    }
                }
                return true;
            }); /* enabled errorItem */

            /* Section summaries - only sections with errors or warnings are in alertIds.
             * Stale statusLines were hidden by foswikiAlertInactive before the scans.
             */

            for (id = 0; id < alertIds.length; id++) {
                alertDiv = alertIds[id];
                statusLine = '';
                if( alerts[alertDiv].errors !== 0 ) {
                    statusLine += "<span class='configureStatusErrors'>" + alerts[alertDiv].errors;
                    if( alerts[alertDiv].errors == 1 ) {
                        statusLine += " error";
                    } else {
                        statusLine += " errors";
                    }
                    statusLine += "</span>";
                }
                if( alerts[alertDiv].warnings !== 0 ) {
                    statusLine += "<span class='configureStatusWarnings'>" + alerts[alertDiv].warnings;
                    if( alerts[alertDiv].warnings == 1 ) {
                        statusLine += " warning";
                    } else {
                        statusLine += " warnings";
                    }
                    statusLine += "</span>";
                }
                $('#' + configure.utils.quoteName(alertDiv)).html(statusLine).removeClass('foswikiAlertInactive');
            }

            /* Finally, the summary status bar
             * Keep in sync with UIs/Section.pm, ModalTemplates.pm
             # and the templates...
             */

            statusLine = '';
            if( totalWarnings || totalErrors ) {
                if( totalErrors ) {
                    statusLine += 
                    '<button id="{ConfigureGUI}{Modals}{DisplayErrors}feedreq1" class="foswikiButton" onclick="return doFeedback(this);" value="1" type="button">' +
                        '<span class="configureStatusErrors">' + 
                        totalErrors + " Error";
                    if( totalErrors !== 1 ) { statusLine += 's'; }
                    statusLine += '</span></button>';
                }
                if( totalWarnings ) {
                    if( !totalErrors ) {
                        statusLine += 
                            '<button id="{ConfigureGUI}{Modals}{DisplayErrors}feedreq1" class="foswikiButton" onclick="return doFeedback(this);" value="1" type="button">';
                    }
                    statusLine += '<span class="configureStatusWarnings">' +
                        totalWarnings + " Warning";
                    if( totalWarnings !== 1 ) { statusLine += 's'; }
                    statusLine += '</span>';
                    if( !totalErrors ) { statusLine += '</button>'; }
                }
            } else {
                statusLine += '<span class="configureStatusOK">No problems detected</span>';
                $('#configureFixSoon').remove();
            }
            $('#configureErrorSummary').html(statusLine);
            return true;
        },
        getVERSION: function () {
            return VERSION;
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
        Quote a name per CSS quoting rules so that it can be used as a JQuery selector
        */
        quoteName: function (name) {
            var out = '',
                i,
                c;
            for (i = 0; i < name.length; i++) {
                c = name.charAt(i);
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
        for (i = 0; i < elem.options.length; i++) {
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

var unsaved = { id:'{ConfigureGUI}{Unsaved}status', value:'Not a button' },
    statusTimer = undefined,
    statusTimeout = 1500,
    statusDeferred = 0,
    statusImmediate = 0,
    statusDeferrals = [ 0, 0, 0, 0, 0],
    errorKeyRe = /^\{.*\}errors$/;

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
        if( statusTimer == undefined ) {
            statusImmediate++;
            doFeedback(unsaved);
        } else {
            statusDeferred++;
        }
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
        for (j = 0; j < jlen; j++) {
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

var feedback = ( function ($) {
    "use strict";

    var modalObject;

    return {
        /* Initialize */
        init: function () {
            modalObject =  $('#activateConfigureModalWindow').data('nmObj');
        },

        /* Modal window state */

        modalObject: function () {
            return modalObject;
        },
        modalIsOpen: function () {
            return modalObject._open;
        },

        /* modal window for errors, modal forms */

        modalWindow: function (m) {
            if( !m.length ) {
                m = "[Empty window]"; /* Debug this */
            }

            /* There is currently one modal window defined in pageend.
             * We replace its contents and make it display.  Feedback also uses it.
             */
            if( $('#configureModalContents').html(m).size() ) {
                if( feedback.modalIsOpen() ) {
                    modalObject.resize(true);
                } else {
                    $('#activateConfigureModalWindow').click();
                }
            } else { /* Must be on a page without modal infrastructure, say something */
                alert( m );
            }
        },

        /* Error window - could go to status bar, but this seems to be effective. 
         * Extract content for a div, stripping page overhead.
         */

        modalWindowFromHTML: function (m) {
            if (m.length <= 0) {
                m = "Unknown error encountered";
            }
            if( !/<\w+/.test(m) ) {
                feedback.modalWindow(m);
                return;
            }
            /* nyroModal has wierd styles on <pre> that shrink to unreadability, 
             * switch to <code> as <pre> s used by CGI::Carp.  This should be removed
             * once the nyroModal CSS is fixed.
             */
            m = m.replace(/<(\/)?pre>/gi, "<$1code>").replace(/\n/g, '<br />');

            feedback.modalWindow(m.replace(/\r?\n/mgi, '<crlf>').replace(/^.*<body[^>]*>/mgi, '').replace(/<\/body>.*$/mgi, '').replace(/<\/?html>/mgi, '').replace(/<crlf>/mg, "\n"));
        },
        sendFeedbackRequest: function ( posturl, requestData, boundary, stsWinId ) {

            var stsWindowId = stsWinId,
            request = $.ajax({
                url: posturl,
                cache: false,
                dataType: "text",
                type: "POST",
                global: false,
                contentType: (boundary?
                              "multipart/form-data; boundary=\"" + boundary + '"; charset=UTF-8' :
                              "application/octect-stream; charset=UTF-8"),
                accepts: {
                    text: "application/octet-stream; q=1, text/plain; q=0.8, text/html q=0.5"
                },
                headers: {
                    'X-Foswiki-FeedbackRequest': 'V1.0',
                    'X-Foswiki-ScriptVersion': configure.getVERSION()
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

                    feedback.modalWindow('<h1>' + xhr.status.toString() + " " + xhr.statusText + "</h1>" + xhr.responseText);
                    return true;
                },
                /* Using complete ensures that jQuery provides xhr on success.
                 */

                complete: function (xhr, status) {
                   if (status !== 'success') {
                        return true;
                    }

                    /* Make sure this is a feedback response.
                     */
                    if (xhr.getResponseHeader('X-Foswiki-FeedbackResponse') !== 'V1.0') {
                        return true;
                    }

                    var data = xhr.responseText,
                    item,
                    items,
                    i,
                    kpair = [],
                    sloc,
                    delims,
                    v,
                    modalIsOpen = feedback.modalIsOpen(),
                    openModal = false,
                    errorsChanged = false;

                    /* Validate that this script is the version that configure expects.
                     * An empty response should only be the reply to our initial version check.
                     */
                    v = xhr.getResponseHeader('X-Foswiki-ScriptVersionRequired');
                    if (v !== configure.getVERSION()) {
                        if( data.length && data.charAt(0) === '<' ) {
                            feedback.modalWindowFromHTML(data);
                        } else {
                            feedback.modalWindow( "Client javascript is version " + configure.getVERSION() + ", but configure requires " + (v && v.length? v : 'an unknown version') );
                        }
                        return true;
                    }
                    if( xhr.getResponseHeader('Content-Length') === '0' ) {
                        return true;
                    }

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
                            feedback.modalWindowFromHTML(data);
                        }
                        return true;
                    }

                    /* Distribute response for each key to its status div or value */
                    /* Hex constants used rather than octal for JSLint issue. */
                    
                    items = data.split("\x01");
                    data = undefined;
                    for (item = 0; item < items.length; item++) {
                        /* IE sometimes doesn't do capturing split, so simulate one. */
                        delims = ["\x02", "\x03","\x05"];
                        for (i = 0; i < delims.length; i++) {
                            sloc = items[item].indexOf(delims[i]);
                            if (sloc >= 0) {
                                kpair[0] = items[item].substr(0, sloc);
                                kpair[1] = delims[i];
                                kpair[2] = items[item].substr(sloc + 1);
                                break;
                            }
                        }
                        if (i >= delims.length) {
                            feedback.modalWindow("Invalid opcode in feedback response");
                            return true;
                        }
                        if (kpair[1] === "\x02") {
                            if( $("#" + configure.utils.quoteName(kpair[0]) + "status").html(kpair[2]).size() < 1 ) {
                                /* Missing status window - probably template creating modal failed,
                                 * unless it's a status update on another page.
                                 */
                                if( kpair[0] !== '{ConfigureGUI}{Unsaved}' ) {
                                    feedback.modalWindow(kpair[2]);
                                }
                            }
                        } else if (kpair[1] === "\x03") {
                            errorsChanged = feedback.decodeSetValueMessage( kpair );
                        } else if (kpair[1] === "\x05") {
                            openModal = feedback.decodeModalMessage( kpair );
                        } else { /* This is not possible */
                            feedback.modalWindow("Invalid opcode2 in feedback response");
                        }
                    }

                    /* Resize if open to account for any content changes
                     * Otherwise, open if requested.  Must not open more
                     * than once, as this creates duplicate DOM.
                     */

                    if( modalIsOpen ) {
                        modalObject.resize(true);
                    } else {
                        if( openModal ) {
                            $('#activateConfigureModalWindow').click();
                        }}

                    /* Responses with just unsaved items updates or with no error count
                     * changes need no more processing.  Otherwise, update the indicators.
                     */

                    if( stsWindowId && errorsChanged ) {
                        configure.updateIndicators();
                    }

                    return true;
                } /* complete */
            }); /* Ajax */

            /* Return request handle */

            return request;
        },
        decodeSetValueMessage: function (kpair) {
            var newval = kpair[2].split(/\x04/),
            errorsChanged = false;
            
            $('[name="' + configure.utils.quoteName(kpair[0]) + '"]').each(function (idx, ele) {
                var i,
                v,
                opts,
                selected,
                eleDisabled = this.disabled;
                
                this.disabled = false;
                switch (this.type.toLowerCase()) {
                    /* Ignore these for now (why update labels?) */
                case "button":
                case "file":
                case "submit":
                case "reset":
                    break;

                case "select-one":
                    opts = this.options;
                    selected = -1;

                    for (i = 0; i < opts.length; i++) {
                        if (opts[i].value === newval[0]) {
                            opts[i].selected = true;
                            this.selectedIndex = i;
                            selected = i;
                        } else {
                            opts[i].selected = false;
                        }
                    }
                    if (selected < 0) {
                        feedback.modalWindow("Invalid value \"" + newval[0] + "\" for " + kpair[0]);
                    }
                    break;

                case "select-multiple":
                    opts = this.options;

                    for (i = 0; i < opts.length; i++) {
                        opts[i].selected = false;
                    }
                    this.selectedIndex = -1;
                    for (v = 0; v < newval.length; v++) {
                        for (i = 0; i < opts.length; i++) {
                            if (opts[i].value === newval[v]) {
                                opts[i].selected = true;
                                if (v === 0) {
                                    this.selectedIndex = i;
                                }
                                break;
                            }
                        }
                        if (i >= opts.length) {
                            feedback.modalWindow("Invalid value \"" + newval[v] + "\" for " + kpair[0]);
                        }
                    }
                    break;

                case "hidden":
                    v = newval.join("");
                    if( errorKeyRe.test(this.name) ) {
                        errorsChanged = true;
                        if( v === "0 0" ) {
                            eleDisabled = true; /* Do not POST */
                        } else {
                            eleDisabled = false;
                        }
                    }
                    this.value = v;
                    break;

                case "textarea":
                case "text":
                case "password":
                    this.value = newval.join("");
                    break;

                case "radio":
                case "checkbox":
                    this.checked = configure.utils.isTrue(newval[0]);
                    break;
                default:
                    break;
                }
                this.disabled = eleDisabled;
                /* Continue to next control */
                return true;
            });

            return errorsChanged;
        },
        decodeModalMessage: function (kpair) {
            var opts,
            i,
            v,
            sloc,
            newval,
            openModal = false;

            opts = kpair[0].replace(/^\{ModalOptions\}/,'').split(',');
            for( i = 0; i < opts.length; i++ ) {
                switch( opts[i] ) {
                case 's':
                    v = '';
                    while( kpair[2].length ) { /* substitute <4>DOMref)*/
                        sloc = kpair[2].indexOf("\x04");
                        if( sloc < 0 ) {
                            v += kpair[2];
                            break;
                        }
                        v += kpair[2].substr(0, sloc);
                        kpair[2] = kpair[2].substr( sloc+1 );
                        newval = kpair[2].indexOf(')');
                        if( newval > 0 ) { /* 1 char token required */
                            newval = kpair[2].substr( 0, newval );
                            v += $('#' + configure.utils.quoteName(newval)).html();
                            kpair[2] = kpair[2].substr(newval.length+1);
                        }
                    }
                    kpair[2] = v;
                    break;
                case 'r':
                    $('#configureModalContents').html(kpair[2]);
                    break;
                case 'a':
                    $('#configureModalContents').append(kpair[2]);
                    break;
                case 'p':
                    $('#configureModalContents').prepend(kpair[2]);
                    break;
                case 'o':
                    openModal = true;
                    break;
                case 'u':
                    window.location.assign( kpair[2] );
                    return false;
                default:
                    if( opts[i].charAt(0) === '#' ) {
                        $('#'+ configure.utils.quoteName(opts[i].substr(1))).html(kpair[2]);
                        break;
                    }
                    feedback.modalWindow("Invalid modal window option " + opts[i]);
                    return false;
                }
            }
            return openModal;
        }
    };
}(jQuery));

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
    $(":input.foswikiFocus").each(function () {
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
                
    $('.configureModalActivator').nyroModal( { callbacks: { 
        afterShowCont: function (nm) {
            nm.elts.cont.find(":input.foswikiFocus:first").focus();
            return true;
        }
    }} );

    /* Provide version before anything else happens */

    feedback.init();
    feedback.sendFeedbackRequest( document.location.pathname, '' );

    configure.updateIndicators();

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
        itemStart1 =  (dashdash + boundary + crlf + 'Content-Disposition: form-data; name="'),
        itemStart2 = ('"' + crlf + crlf),
        requestData = "",
        quoteKeyId = configure.utils.quoteName(key.id), /* Selector-encoded id of button that was clicked */
        KeyIdSelector = '#' + quoteKeyId,
        posturl = document.location.pathname, /* Where to post form */
        working,
        stsWindowId;

    /* Add a named item from a form to the POST data */

    function postFormItem(name, value) {
        requestData += itemStart1 + name + itemStart2 + value + crlf;
        return;
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

    /* Scan all the input controls  This could be simply the closest form
     * to the button - except that with modal forms, we have multiple forms
     * on the page.  So we scan them all - fortunately only the main
     * form is large.  It's important not to have conflicting names.
     * Note that POSTS that submit directly (non-feedback) do not merge controls
     * across forms.  Here, feedback needs the full state.
     * Include successful controls.  Skip disabled and nameless controls.
     */

/*    $(KeyIdSelector).closest('form').find(":input:enabled").not(':file,:submit,:reset,:button').each(function (index) {
*/

    $('form').find(":input:enabled").not(':file,:submit,:reset,:button').each(function (index) {
        var opts,
            i,
            ilen,
            ctlName,
            txt;

        ctlName = this.name;
        if (!ctlName.length) {
            return true;
        }
        switch (this.type.toLowerCase()) {
        /* Ignore these */
        /* case "file": */
        /* case "submit": */
            /* Submit buttons weren't clicked, so don't report them */
        /* case "reset": */
            /* Reset controls are never submitted, local action only */
            /* return true; */

        case "select-one":
        case "select-multiple":
            /* Select sends the value of each selected option */
            opts = this.options;
            ilen = opts.length;
            for (i = 0; i < ilen; i++) {
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
     * status updates do not provide busy status, and !stsWindowId indicates a status update.
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

        if( feedback.modalIsOpen() ) {
            feedback.modalObject().resize(true);
        }
    }

    /* Make the request
     * ** N.B. Definitely broken with jQuery 1.3 (unreliable selectors), 1.8.2 used.
     */

    /* Block unsaved status updates for a while after any feedback request.
     * This allows for bursts to merge, and helps to keep things seemingly responsive.
     * Adjust timeout based on a weighted moving average with exponential decay.
     */

    if( statusTimer != undefined ) {
        window.clearTimeout(statusTimer);
    }
    statusTimer = window.setTimeout(function () {
        var avgDelay,
            weight,
            sIdx,
            nHist;

        statusDeferrals.pop();

        /* The magic numbers are all pulled out of my hat, with some thought.
         * We adjust the holdoff in the range 800msec to 3sec based on the
         * recent average net delay.  We adjust in increments of 100 msec, with
         * an idle bias of -50 (toward shorter delays), and a 10% penalty for blocking.
         *
         * Net delay for this interval: penalize any delay, bonus for idle
         */
        avgDelay = statusDeferred + statusImmediate;
        avgDelay = avgDelay? ((statusDeferred * 1.1) - statusImmediate) : -0.5;

        statusDeferrals.unshift(avgDelay);

        nHist = statusDeferrals.length;
        avgDelay = 0;
        sIdx = 0;
        weight = 1.0;
        while( sIdx < nHist ) { /* The obvious for() loop didn't work with FF 16.0.2 */
            avgDelay += statusDeferrals[sIdx] * weight;
            weight *= 0.8;
            sIdx++;
        }
        avgDelay /= nHist;
        statusTimeout = Math.max( 800, Math.min( 3000, statusTimeout + (avgDelay * 100) ) );

        statusTimer = undefined;

        if( statusDeferred ) {
            doFeedback(unsaved);
        }
        statusDeferred = 0;
        statusImmediate = 0;
    }, Math.round( statusTimeout ));

    feedback.sendFeedbackRequest( posturl, requestData, boundary, stsWindowId );
    return false;
}
