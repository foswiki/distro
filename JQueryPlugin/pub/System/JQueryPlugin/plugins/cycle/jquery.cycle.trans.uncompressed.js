/*
 * jQuery Cycle Plugin Transition Definitions
 * This script is a plugin for the jQuery Cycle Plugin
 * Examples and documentation at: http://malsup.com/jquery/cycle/
 * Copyright (c) 2007-2008 M. Alsup
 * Version:  2.22
 * Dual licensed under the MIT and GPL licenses:
 * http://www.opensource.org/licenses/mit-license.php
 * http://www.gnu.org/licenses/gpl.html
 */
(function($) {

//
// These functions define one-time slide initialization for the named
// transitions. To save file size feel free to remove any of these that you 
// don't need.
//

// scrollUp/Down/Left/Right
$.fn.cycle.transitions.scrollUp = function($cont, $slides, opts) {
    $cont.css('overflow','hidden');
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.top = next.offsetHeight;
        opts.animOut.top = 0-curr.offsetHeight;
    });
    opts.cssFirst = { top: 0 };
    opts.animIn   = { top: 0 };
    opts.cssAfter = { display: 'none' };
};
$.fn.cycle.transitions.scrollDown = function($cont, $slides, opts) {
    $cont.css('overflow','hidden');
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.top = 0-next.offsetHeight;
        opts.animOut.top = curr.offsetHeight;
    });
    opts.cssFirst = { top: 0 };
    opts.animIn   = { top: 0 };
    opts.cssAfter = { display: 'none' };
};
$.fn.cycle.transitions.scrollLeft = function($cont, $slides, opts) {
    $cont.css('overflow','hidden');
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.left = next.offsetWidth;
        opts.animOut.left = 0-curr.offsetWidth;
    });
    opts.cssFirst = { left: 0 };
    opts.animIn   = { left: 0 };
};
$.fn.cycle.transitions.scrollRight = function($cont, $slides, opts) {
    $cont.css('overflow','hidden');
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.left = 0-next.offsetWidth;
        opts.animOut.left = curr.offsetWidth;
    });
    opts.cssFirst = { left: 0 };
    opts.animIn   = { left: 0 };
};
$.fn.cycle.transitions.scrollHorz = function($cont, $slides, opts) {
    $cont.css('overflow','hidden').width();
//    $slides.show();
    opts.before.push(function(curr, next, opts, fwd) {
        $(this).show();
        var currW = curr.offsetWidth, nextW = next.offsetWidth;
        opts.cssBefore = fwd ? { left: nextW } : { left: -nextW };
        opts.animIn.left = 0;
        opts.animOut.left = fwd ? -currW : currW;
        $slides.not(curr).css(opts.cssBefore);
    });
    opts.cssFirst = { left: 0 };
    opts.cssAfter = { display: 'none' }
};
$.fn.cycle.transitions.scrollVert = function($cont, $slides, opts) {
    $cont.css('overflow','hidden');
//    $slides.show();
    opts.before.push(function(curr, next, opts, fwd) {
        $(this).show();
        var currH = curr.offsetHeight, nextH = next.offsetHeight;
        opts.cssBefore = fwd ? { top: -nextH } : { top: nextH };
        opts.animIn.top = 0;
        opts.animOut.top = fwd ? currH : -currH;
        $slides.not(curr).css(opts.cssBefore);
    });
    opts.cssFirst = { top: 0 };
    opts.cssAfter = { display: 'none' }
};

// slideX/slideY
$.fn.cycle.transitions.slideX = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssBefore = { zIndex: 2 };
    opts.animIn  = { width: 'show' };
    opts.animOut = { width: 'hide' };
};
$.fn.cycle.transitions.slideY = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssBefore = { zIndex: 2 };
    opts.animIn  = { height: 'show' };
    opts.animOut = { height: 'hide' };
};

// shuffle
$.fn.cycle.transitions.shuffle = function($cont, $slides, opts) {
    var w = $cont.css('overflow', 'visible').width();
    $slides.css({left: 0, top: 0});
    opts.before.push(function() { $(this).show() });
    opts.speed = opts.speed / 2; // shuffle has 2 transitions        
    opts.random = 0;
    opts.shuffle = opts.shuffle || {left:-w, top:15};
    opts.els = [];
    for (var i=0; i < $slides.length; i++)
        opts.els.push($slides[i]);

    for (var i=0; i < opts.startingSlide; i++)
        opts.els.push(opts.els.shift());

    // custom transition fn (hat tip to Benjamin Sterling for this bit of sweetness!)
    opts.fxFn = function(curr, next, opts, cb, fwd) {
        var $el = fwd ? $(curr) : $(next);
        $el.animate(opts.shuffle, opts.speedIn, opts.easeIn, function() {
            fwd ? opts.els.push(opts.els.shift()) : opts.els.unshift(opts.els.pop());
            if (fwd) 
                for (var i=0, len=opts.els.length; i < len; i++)
                    $(opts.els[i]).css('z-index', len-i);
            else {
                var z = $(curr).css('z-index');
                $el.css('z-index', parseInt(z)+1);
            }
            $el.animate({left:0, top:0}, opts.speedOut, opts.easeOut, function() {
                $(fwd ? this : curr).hide();
                if (cb) cb();
            });
        });
    };
    opts.onAddSlide = function($s) { $s.hide(); };
};

// turnUp/Down/Left/Right
$.fn.cycle.transitions.turnUp = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.top = next.cycleH;
        opts.animIn.height = next.cycleH;
    });
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssFirst  = { top: 0 };
    opts.cssBefore = { height: 0 };
    opts.animIn    = { top: 0 };
    opts.animOut   = { height: 0 };
    opts.cssAfter  = { display: 'none' };
};
$.fn.cycle.transitions.turnDown = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.animIn.height = next.cycleH;
        opts.animOut.top   = curr.cycleH;
    });
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssFirst  = { top: 0 };
    opts.cssBefore = { top: 0, height: 0 };
    opts.animOut   = { height: 0 };
    opts.cssAfter  = { display: 'none' };
};
$.fn.cycle.transitions.turnLeft = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore.left = next.cycleW;
        opts.animIn.width = next.cycleW;
    });
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssBefore = { width: 0 };
    opts.animIn    = { left: 0 };
    opts.animOut   = { width: 0 };
    opts.cssAfter  = { display: 'none' };
};
$.fn.cycle.transitions.turnRight = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.animIn.width = next.cycleW;
        opts.animOut.left = curr.cycleW;
    });
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssBefore = { left: 0, width: 0 };
    opts.animIn    = { left: 0 };
    opts.animOut   = { width: 0 };
    opts.cssAfter  = { display: 'none' };
};

// zoom
$.fn.cycle.transitions.zoom = function($cont, $slides, opts) {
    opts.cssFirst = { top:0, left: 0 }; 
    opts.cssAfter = { display: 'none' };
    
    opts.before.push(function(curr, next, opts) {
        $(this).show();
        opts.cssBefore = { width: 0, height: 0, top: next.cycleH/2, left: next.cycleW/2 };
        opts.cssAfter  = { display: 'none' };
        opts.animIn    = { top: 0, left: 0, width: next.cycleW, height: next.cycleH };
        opts.animOut   = { width: 0, height: 0, top: curr.cycleH/2, left: curr.cycleW/2 };
        $(curr).css('zIndex',2);
        $(next).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
};

// fadeZoom
$.fn.cycle.transitions.fadeZoom = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = { width: 0, height: 0, opacity: 1, left: next.cycleW/2, top: next.cycleH/2, zIndex: 1 };
        opts.animIn    = { top: 0, left: 0, width: next.cycleW, height: next.cycleH };
    });    
    opts.animOut  = { opacity: 0 };
    opts.cssAfter = { zIndex: 0 };
};

// blindX
$.fn.cycle.transitions.blindX = function($cont, $slides, opts) {
    var w = $cont.css('overflow','hidden').width();
    $slides.show();
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',1);
    });    
    opts.cssBefore = { left: w, zIndex: 2 };
    opts.cssAfter = { zIndex: 1 };
    opts.animIn = { left: 0 };
    opts.animOut  = { left: w };
};
// blindY
$.fn.cycle.transitions.blindY = function($cont, $slides, opts) {
    var h = $cont.css('overflow','hidden').height();
    $slides.show();
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',1);
    });    
    opts.cssBefore = { top: h, zIndex: 2 };
    opts.cssAfter = { zIndex: 1 };
    opts.animIn = { top: 0 };
    opts.animOut  = { top: h };
};
// blindZ
$.fn.cycle.transitions.blindZ = function($cont, $slides, opts) {
    var h = $cont.css('overflow','hidden').height();
    var w = $cont.width();
    $slides.show();
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',1);
    });    
    opts.cssBefore = { top: h, left: w, zIndex: 2 };
    opts.cssAfter = { zIndex: 1 };
    opts.animIn = { top: 0, left: 0 };
    opts.animOut  = { top: h, left: w };
};

// growX - grow horizontally from centered 0 width
$.fn.cycle.transitions.growX = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = { left: this.cycleW/2, width: 0, zIndex: 2 };
        opts.animIn = { left: 0, width: this.cycleW };
        opts.animOut = { left: 0 };
        $(curr).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide().css('zIndex',1); };
};
// growY - grow vertically from centered 0 height
$.fn.cycle.transitions.growY = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = { top: this.cycleH/2, height: 0, zIndex: 2 };
        opts.animIn = { top: 0, height: this.cycleH };
        opts.animOut = { top: 0 };
        $(curr).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide().css('zIndex',1); };
};

// curtainX - squeeze in both edges horizontally
$.fn.cycle.transitions.curtainX = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = { left: next.cycleW/2, width: 0, zIndex: 1, display: 'block' };
        opts.animIn = { left: 0, width: this.cycleW };
        opts.animOut = { left: curr.cycleW/2, width: 0 };
        $(curr).css('zIndex',2);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssAfter = { zIndex: 1, display: 'none' };
};
// curtainY - squeeze in both edges vertically
$.fn.cycle.transitions.curtainY = function($cont, $slides, opts) {
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = { top: next.cycleH/2, height: 0, zIndex: 1, display: 'block' };
        opts.animIn = { top: 0, height: this.cycleH };
        opts.animOut = { top: curr.cycleH/2, height: 0 };
        $(curr).css('zIndex',2);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssAfter = { zIndex: 1, display: 'none' };
};

// cover - curr slide covered by next slide
$.fn.cycle.transitions.cover = function($cont, $slides, opts) {
    var d = opts.direction || 'left';
    var w = $cont.css('overflow','hidden').width();
    var h = $cont.height();
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore = opts.cssBefore || {};
        opts.cssBefore.zIndex = 2;
        opts.cssBefore.display = 'block';
        
        if (d == 'right') 
            opts.cssBefore.left = -w;
        else if (d == 'up')    
            opts.cssBefore.top = h;
        else if (d == 'down')  
            opts.cssBefore.top = -h;
        else
            opts.cssBefore.left = w;
        $(curr).css('zIndex',1);
    });    
    if (!opts.animIn)  opts.animIn = { left: 0, top: 0 };
    if (!opts.animOut) opts.animOut = { left: 0, top: 0 };
    opts.cssAfter = opts.cssAfter || {};
    opts.cssAfter.zIndex = 2;
    opts.cssAfter.display = 'none';
};

// uncover - curr slide moves off next slide
$.fn.cycle.transitions.uncover = function($cont, $slides, opts) {
    var d = opts.direction || 'left';
    var w = $cont.css('overflow','hidden').width();
    var h = $cont.height();
    opts.before.push(function(curr, next, opts) {
        opts.cssBefore.display = 'block';
        if (d == 'right') 
            opts.animOut.left = w;
        else if (d == 'up')    
            opts.animOut.top = -h;
        else if (d == 'down')  
            opts.animOut.top = h;
        else
            opts.animOut.left = -w;
        $(curr).css('zIndex',2);
        $(next).css('zIndex',1);
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    if (!opts.animIn)  opts.animIn = { left: 0, top: 0 };
    opts.cssBefore = opts.cssBefore || {};
    opts.cssBefore.top = 0;
    opts.cssBefore.left = 0;
    
    opts.cssAfter = opts.cssAfter || {};
    opts.cssAfter.zIndex = 1;
    opts.cssAfter.display = 'none';
};

// toss - move top slide and fade away
$.fn.cycle.transitions.toss = function($cont, $slides, opts) {
    var w = $cont.css('overflow','visible').width();
    var h = $cont.height();
    opts.before.push(function(curr, next, opts) {
        $(curr).css('zIndex',2);
        opts.cssBefore.display = 'block'; 
        // provide default toss settings if animOut not provided
        if (!opts.animOut.left && !opts.animOut.top)
            opts.animOut = { left: w*2, top: -h/2, opacity: 0 };
        else
            opts.animOut.opacity = 0;
    });    
    opts.onAddSlide = function($s) { $s.hide(); };
    opts.cssBefore = { left: 0, top: 0, zIndex: 1, opacity: 1 };
    opts.animIn = { left: 0 };
    opts.cssAfter = { zIndex: 2, display: 'none' };
};

// wipe - clip animation
$.fn.cycle.transitions.wipe = function($cont, $slides, opts) {
    var w = $cont.css('overflow','hidden').width();
    var h = $cont.height();
    opts.cssBefore = opts.cssBefore || {};
    var clip;
    if (opts.clip) {
        if (/l2r/.test(opts.clip))
            clip = 'rect(0px 0px '+h+'px 0px)';
        else if (/r2l/.test(opts.clip))
            clip = 'rect(0px '+w+'px '+h+'px '+w+'px)';
        else if (/t2b/.test(opts.clip))
            clip = 'rect(0px '+w+'px 0px 0px)';
        else if (/b2t/.test(opts.clip))
            clip = 'rect('+h+'px '+w+'px '+h+'px 0px)';
        else if (/zoom/.test(opts.clip)) {
            var t = parseInt(h/2);
            var l = parseInt(w/2);
            clip = 'rect('+t+'px '+l+'px '+t+'px '+l+'px)';
        }
    }
    
    opts.cssBefore.clip = opts.cssBefore.clip || clip || 'rect(0px 0px 0px 0px)';
    
    var d = opts.cssBefore.clip.match(/(\d+)/g);
    var t = parseInt(d[0]), r = parseInt(d[1]), b = parseInt(d[2]), l = parseInt(d[3]);
    
    opts.before.push(function(curr, next, opts) {
        if (curr == next) return;
        var $curr = $(curr).css('zIndex',2);
        var $next = $(next).css({
            zIndex:  3,
            display: 'block'
        });
        
        var step = 1, count = parseInt((opts.speedIn / 13)) - 1;
        function f() {
            var tt = t ? t - parseInt(step * (t/count)) : 0;
            var ll = l ? l - parseInt(step * (l/count)) : 0;
            var bb = b < h ? b + parseInt(step * ((h-b)/count || 1)) : h;
            var rr = r < w ? r + parseInt(step * ((w-r)/count || 1)) : w;
            $next.css({ clip: 'rect('+tt+'px '+rr+'px '+bb+'px '+ll+'px)' });
            (step++ <= count) ? setTimeout(f, 13) : $curr.css('display', 'none');
        }
        f();
    });    
    opts.cssAfter  = { };
    opts.animIn    = { left: 0 };
    opts.animOut   = { left: 0 };
};

})(jQuery);
