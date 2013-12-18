/**
 * Singleton class.
 */
var foswiki;
if (!foswiki) foswiki = {};

(function($) {
  
    foswiki.TwistyPlugin = new function () {
        var self = this;

        /**
         * Retrieves the name of the twisty from an HTML element id.
         * For example 'demotoggle' will return 'demo'.
         * @param inId : (String) HTML element id
         * @return String
         * @privileged
         */
        this._getName = function (inId) {
            var re = new RegExp('(.*)(hide|show|toggle)', 'g');
            var m = re.exec(inId);
            var name = (m && m[1]) ? m[1] : '';
            return name;
        };

        /**
         * Retrieves the type of the twisty from an HTML element id.
         * For example 'demotoggle' will return 'toggle'.
         * @param inId : (String) HTML element id
         * @return String
         * @privileged
         */
        this._getType = function (inId) {
            var re = new RegExp('(.*)(hide|show|toggle)', 'g');
            var m = re.exec(inId);
            var type = (m && m[2]) ? m[2] : '';
            return type;
        }

        /**
         * Toggles the collapsed state. Calls _update().
         * @privileged
         */
        this._toggleTwisty = function (ref) {
            if (!ref) return;
            ref.state = (ref.state == foswiki.TwistyPlugin.CONTENT_HIDDEN)
            ? foswiki.TwistyPlugin.CONTENT_SHOWN
            : foswiki.TwistyPlugin.CONTENT_HIDDEN;
            self._update(ref, true);
        }

        /**
         * Updates the states of UI trinity 'show', 'hide' and 'content'.
         * Saves new state in a cookie if one of the elements has CSS
         * class 'twistyRememberSetting'.
         * @param ref : (Object) foswiki.TwistyPlugin.Storage object
         * @privileged
         */
        this._update = function (ref, inMaySave) {
            var showControl = ref.show;
            var hideControl = ref.hide;
            var contentElem = ref.toggle;
            if (ref.state == foswiki.TwistyPlugin.CONTENT_SHOWN) {
                // show content
                if (inMaySave && ref.speed != 0) {
                    foswiki.TwistyPlugin.showAnimation(contentElem, ref);
                } else {
                    foswiki.TwistyPlugin.show(contentElem, ref);
                }
                $(showControl).hide();
                $(hideControl).show();
            } else {
                // hide content
                if (inMaySave && ref.speed != 0) {
                    foswiki.TwistyPlugin.hideAnimation(contentElem, ref);
                } else {
                    foswiki.TwistyPlugin.hide(contentElem, ref);
                }
                $(showControl).show();
                $(hideControl).hide();
            }
            if (inMaySave && ref.saveSetting) {
                foswiki.Pref.setPref(foswiki.TwistyPlugin.COOKIE_PREFIX
                                     + ref.name, ref.state);
            }
            if (ref.clearSetting) {
              if (foswiki.Pref.clearPref) {
                // Foswiki >= 1.1.4
                foswiki.Pref.clearPref(foswiki.TwistyPlugin.COOKIE_PREFIX + ref.name);
              } else {
                // Foswiki < 1.1.4
                foswiki.Pref.setPref(foswiki.TwistyPlugin.COOKIE_PREFIX + ref.name, '');
              }
            }
        }
        
        /**
         * Stores a twisty HTML element (either show control, hide
         * control or content 'toggle').
         * @param e : (Object) HTMLElement
         * @privileged
         */
        this._register = function (e) {
            if (!e) return;
            var name = self._getName(e.id);
            var ref = self._storage[name];
            if (!ref) {
                ref = new foswiki.TwistyPlugin.Storage();
            }
            if ($(e).hasClass('twistyRememberSetting')) 
                ref.saveSetting = true;
            if ($(e).hasClass('twistyForgetSetting')) 
                ref.clearSetting = true;
            if ($(e).hasClass('twistyStartShow')) 
                ref.startShown = true;
            if ($(e).hasClass('twistyStartHide')) 
                ref.startHidden = true;
            if ($(e).hasClass('twistyFirstStartShow'))
                ref.firstStartShown = true;
            if ($(e).hasClass('twistyFirstStartHide')) 
                ref.firstStartHidden = true;

            ref.name = name;
            var type = self._getType(e.id);
            ref[type] = e;
            self._storage[name] = ref;
            switch (type) {
              case 'show': // fall through
              case 'hide':
                e.onclick = function() {
                  self._toggleTwisty(ref);
                  return false;
                }
              break;
            }
            return ref;
        }

        /**
         * Key-value set of foswiki.TwistyPlugin.Storage objects.
         * The value is accessed by twisty id identifier name.
         * @example var ref = self._storage['demo'];
         * @privileged
         */
        this._storage = {};
    };

    /**
     * Show the twisty content
     */
    foswiki.TwistyPlugin.show = function (elem, ref) {
        $(elem).show();
    }
    
    /**
     * Hide the twisty content
     */
    foswiki.TwistyPlugin.hide = function (elem, ref) {
      $(elem).hide();
    }
    
    /**
     * Show callback when animating the twisty
     */
    foswiki.TwistyPlugin.showAnimation = function (elem, ref) {
        $(elem).animate({
          height:'show',
          opacity:'show'
        },
        ref.speed
      );
    };
    
    /**
     * Hide callback when animating the twisty
     */
    foswiki.TwistyPlugin.hideAnimation = function (elem, ref) {
        $(elem).animate({
          height:'hide',
          opacity:'hide'
        },
        ref.speed
      );
    };


    /**
     * Public constants.
     */
    foswiki.TwistyPlugin.CONTENT_HIDDEN = 0;
    foswiki.TwistyPlugin.CONTENT_SHOWN = 1;
    foswiki.TwistyPlugin.COOKIE_PREFIX = 'TwistyPlugin_';
    
    /**
     * The cached full preference cookie string so the data has to
     * be read only once during init.
     */
    foswiki.TwistyPlugin.prefList;

    /**
     * Initializes a twisty HTML element (either show control, hide
     * control or content 'toggle') by registering and setting the
     * visible state.
     * Calls _register() and _update().
     * @public
     * @param inId : (String) id of HTMLElement
     * @return The stored foswiki.TwistyPlugin.Storage object.
     * */
    foswiki.TwistyPlugin.init = function(e) {
        if (!e)
            return;

        // check if already inited
        var name = this._getName(e.id);
        var ref = this._storage[name];
        if (ref && ref.show && ref.hide && ref.toggle)
            return ref;

        // else register
        ref = this._register(e);

        if (ref.show && ref.hide && ref.toggle) {
            // all Twisty elements present

            if ($(e).hasClass('twistyInited1')) {
                ref.state = foswiki.TwistyPlugin.CONTENT_SHOWN;
                this._update(ref, false);
                return ref;
            }
            if ($(e).hasClass('twistyInited0')) {
                ref.state = foswiki.TwistyPlugin.CONTENT_HIDDEN;
                this._update(ref, false);
                return ref;
            }

            if (foswiki.TwistyPlugin.prefList == null) {
                // cache complete cookie string
                foswiki.TwistyPlugin.prefList = foswiki.Pref.getPrefList();
            }
            var cookie = foswiki.Pref.getPrefValueFromPrefList(
                foswiki.TwistyPlugin.COOKIE_PREFIX + ref.name,
                foswiki.TwistyPlugin.prefList);
            if (ref.firstStartHidden)
                ref.state = foswiki.TwistyPlugin.CONTENT_HIDDEN;
            if (ref.firstStartShown)
                ref.state = foswiki.TwistyPlugin.CONTENT_SHOWN;
            // cookie setting may override firstStartHidden and firstStartShown
            if (cookie && cookie == '0')
                ref.state = foswiki.TwistyPlugin.CONTENT_HIDDEN;
            if (cookie && cookie == '1')
                ref.state = foswiki.TwistyPlugin.CONTENT_SHOWN;
            // startHidden and startShown may override cookie
            if (ref.startHidden)
                ref.state = foswiki.TwistyPlugin.CONTENT_HIDDEN;
            if (ref.startShown)
                ref.state = foswiki.TwistyPlugin.CONTENT_SHOWN;

            this._update(ref, false);
        }
        return ref;
    }

    foswiki.TwistyPlugin.toggleAll = function(inState) {
        for (var i in this._storage) {
            var e = this._storage[i];
            e.state = inState;
            this._update(e, true);
        }
    }

    /**
     * Storage container for properties of a twisty HTML element:
     * show control, hide control or toggle content.
     */
    foswiki.TwistyPlugin.Storage = function () {
        this.name; // String
        this.state = foswiki.TwistyPlugin.CONTENT_HIDDEN; // Number
        this.hide; // HTMLElement
        this.show; // HTMLElement
        this.toggle; // HTMLElement (content element)
        this.saveSetting = false; // Boolean; default not saved
        this.clearSetting = false; // Boolean; default not cleared
        this.startShown; // Boolean
        this.startHidden; // Boolean
        this.firstStartShown; // Boolean
        this.firstStartHidden; // Boolean
        this.marginTop;
        this.marginBottom;
        this.paddingTop;
        this.paddingBottom;
        this.speed;
    }

    /**
     * jquery init 
     */
    $(function() {
          // Hide anything so marked
          $('.twistyStartHide').livequery(function() {
            $(this).hide();
          });
          $('.foswikiMakeVisible').livequery(function() {
            $(this).removeClass('foswikiMakeVisible');
          });
            $('.twistyContent').livequery(function() {
            var ref = foswiki.TwistyPlugin.init(this), 
                $this = $(this), speed;
            if ($this.get(0).tagName == 'SPAN') {
              // do not animate spans because the animation turns inline display into block
              speed = 0;
            } else {
              speed = 200;
            }
            ref.speed = speed;
          });
          $('.twistyTrigger').livequery(function() {
            foswiki.TwistyPlugin.init(this);
          });

          $(document).on('click', '.twistyExpandAll', function() {
            foswiki.TwistyPlugin.toggleAll(foswiki.TwistyPlugin.CONTENT_SHOWN);
          });
          $(document).on('click', '.twistyCollapseAll', function() {
            foswiki.TwistyPlugin.toggleAll(foswiki.TwistyPlugin.CONTENT_HIDDEN);
          });
      });
})(jQuery);
