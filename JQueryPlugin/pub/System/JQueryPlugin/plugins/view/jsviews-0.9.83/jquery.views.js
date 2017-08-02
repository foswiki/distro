/*! jquery.views.js v0.9.83 (Beta): http://jsviews.com/ */
/*
 * Interactive data-driven views using JsRender templates.
 * Subcomponent of JsViews
 * Requires jQuery and jsrender.js (Best-of-breed templating in browser or on Node.js)
 *   See JsRender at http://jsviews.com/#download and http://github.com/BorisMoore/jsrender
 * Also requires jquery.observable.js
 *   See JsObservable at http://jsviews.com/#download and http://github.com/BorisMoore/jsviews
 *
 * Copyright 2016, Boris Moore
 * Released under the MIT License.
 */

//jshint -W018, -W041

(function(factory, global) {
	// global var is the this object, which is window when running in the usual browser environment
	var $ = global.jQuery;

	if (typeof exports === "object") { // CommonJS e.g. Browserify
		module.exports = $
			? factory(global, $)
			: function($) { // If no global jQuery, take jQuery passed as parameter (with JsRender and JsObservable): require("jquery.views")(jQuery)
				return factory(global, $);
			};
	} else if (typeof define === "function" && define.amd) { // AMD script loader, e.g. RequireJS
		define(["jquery", "./jsrender", "./jquery.observable"], function($, jsr, jso) {
			return factory(global, $, jsr, jso);
		}); // Require jQuery, JsRender, JsObservable
	} else { // Browser using plain <script> tag
		factory(global, false);
	}
} (

// factory (for jquery.views.js)
function(global, $, jsr, jso) {
"use strict";

//========================== Top-level vars ==========================

// global var is the this object, which is window when running in the usual browser environment
var setGlobals = $ === false; // Only set globals if script block in browser (not AMD and not CommonJS)

jsr = jsr || setGlobals && global.jsrender;
$ = $ || global.jQuery;

var versionNumber = "v0.9.83",
	requiresStr = "JsViews requires ";

if (!$ || !$.fn) {
	// jQuery is not loaded.
	throw requiresStr + "jQuery"; // We require jQuery
}

if (jsr && !jsr.fn) {
	jsr.views.sub._jq($); // map over from jsrender namespace to jQuery namespace
}

var $observe, $observable,
	$isArray = $.isArray,
	$views = $.views;

if (!$views || !$views.map) {
		// JsRender is not loaded.
	throw requiresStr + "JsRender"; // jsrender.js must be loaded before JsViews and after jQuery
}

var document = global.document,
	$viewsSettings = $views.settings,
	$sub = $views.sub,
	$subSettings = $sub.settings,
	$extend = $sub.extend,
	$isFunction = $.isFunction,
	$expando = $.expando,
	$converters = $views.converters,
	$tags = $views.tags,
	$subSettingsAdvanced = $subSettings.advanced,

	// These two settings can be overridden on settings after loading jsRender, and prior to loading jquery.observable.js and/or JsViews
	propertyChangeStr = $sub.propChng = $sub.propChng || "propertyChange",
	arrayChangeStr = $sub.arrChng = $sub.arrChng || "arrayChange",

	HTML = "html",
	syntaxError = $sub.syntaxErr,
	rFirstElem = /<(?!script)(\w+)[>\s]/,
	error = $sub._er,
	onRenderError = $sub._err,
	delimOpenChar0, delimOpenChar1, delimCloseChar0, delimCloseChar1, linkChar, topView,
	rEscapeQuotes = /['"\\]/g; // Escape quotes and \ character
if ($.link) { return $; } // JsViews is already loaded

$subSettings.trigger = true;
var activeBody, rTagDatalink, $view, $viewsLinkAttr, linkViewsSel, wrapMap, viewStore, oldAdvSet,
	jsvAttrStr = "data-jsv",
	elementChangeStr = "change.jsv",
	onBeforeChangeStr = "onBeforeChange",
	onAfterChangeStr = "onAfterChange",
	onAfterCreateStr = "onAfterCreate",
	CHECKED = "checked",
	CHECKBOX = "checkbox",
	RADIO = "radio",
	NONE = "none",
	SCRIPT = "SCRIPT",
	TRUE = "true",
	closeScript = '"></script>',
	openScript = '<script type="jsv',
	deferAttr = jsvAttrStr + "-df",
	bindElsSel = "script,[" + jsvAttrStr + "]",
	fnSetters = {
		value: "val",
		input: "val",
		html: HTML,
		text: "text"
	},
	valueBinding = {from: "value", to: "value"},
	isCleanCall = 0,
	oldCleanData = $.cleanData,
	oldJsvDelimiters = $viewsSettings.delimiters,
	safeFragment = document.createDocumentFragment(),
	qsa = document.querySelector,

	// elContent maps tagNames which have only element content, so may not support script nodes.
	elContent = {ol: 1, ul: 1, table: 1, tbody: 1, thead: 1, tfoot: 1, tr: 1, colgroup: 1, dl: 1, select: 1, optgroup: 1, svg: 1, svg_ns: 1},
	badParent = {tr: "table"},
	voidElems = {br: 1, img: 1, input: 1, hr: 1, area: 1, base: 1, col: 1, link: 1, meta: 1,
		command: 1, embed: 1, keygen: 1, param: 1, source: 1, track: 1, wbr: 1},
	displayStyles = {},
	bindingStore = {},
	bindingKey = 1,
	rViewPath = /^#(view\.?)?/,
	rConvertMarkers = /((\/>)|<\/(\w+)>|)(\s*)([#\/]\d+(?:_|(\^)))`(\s*)(<\w+(?=[\s\/>]))?|\s*(?:(<\w+(?=[\s\/>]))|<\/(\w+)>(\s*)|(\/>)\s*|(>)|$)/g,
	rOpenViewMarkers = /(#)()(\d+)(_)/g,
	rOpenMarkers = /(#)()(\d+)([_^])/g,
	rViewMarkers = /(?:(#)|(\/))(\d+)(_)/g,
	rOpenTagMarkers = /(#)()(\d+)(\^)/g,
	rMarkerTokens = /(?:(#)|(\/))(\d+)([_^])([-+@\d]+)?/g,
	rSplitBindings = /&(\d+)\+?/g,
	getComputedStyle = global.getComputedStyle;

$observable = $.observable;

if (!$observable) {
	// JsObservable is not loaded.
	throw requiresStr + "JsObservable"; // jquery.observable.js must be loaded before JsViews
}

$observe = $observable.observe;

//========================== Top-level functions ==========================

//===============
// Event handlers
//===============

function elemChangeHandler(ev, params, sourceValue) {
	var setter, cancel, fromAttr, linkCtx, cvtBack, cnvtName, target, $source, view, binding,
		oldLinkCtx, onBeforeChange, onAfterChange, tag, to, eventArgs, exprOb, contextCb,
		source = ev.target,
		bindings = source._jsvBnd;

	// _jsvBnd is a string with the syntax: "&bindingId1&bindingId2"
	while (binding = rSplitBindings.exec(bindings)) {
		if (binding = bindingStore[binding[1]]) {
			if (to = binding.to) {
				// The binding has a 'to' field, which is of the form [[targetObject, toPath], cvtBack]
				linkCtx = binding.linkCtx;
				view = linkCtx.view;
				tag = linkCtx.tag || view.tag;
				$source = $(source);
				onBeforeChange = view.hlp(onBeforeChangeStr); // TODO Can we optimize this and other instances of same?
				onAfterChange = view.hlp(onAfterChangeStr); // TODO Can we optimize this and other instances of same
				fromAttr = defaultAttr(source);
				setter = fnSetters[fromAttr];
				if (sourceValue === undefined) {
					sourceValue = $isFunction(fromAttr)
						? fromAttr(source)
						: setter
							? $source[setter]()
							: $source.attr(fromAttr);
				}
				cnvtName = to[1];
				to = to[0]; // [object, path]
				to = to + "" === to ? [linkCtx.data, to] : to;
				if (cnvtName) {
					if ($isFunction(cnvtName)) {
						cvtBack = cnvtName;
					} else {
						cvtBack = view.getRsc("converters", cnvtName);
					}
				}
				if (linkCtx.elem.nodeName === "SELECT") {
					linkCtx.elem._jsvSel = sourceValue = sourceValue || (linkCtx.elem.multiple ? [] : sourceValue);
					// data-link <select> to string or (multiselect) array of strings
				}
				if (cvtBack) {
					sourceValue = cvtBack.call(tag, sourceValue);
				}

				// Set linkCtx on view, dynamically, just during this handler call
				oldLinkCtx = view.linkCtx;
				view.linkCtx = linkCtx;
				eventArgs = {
					change: "change",
					oldValue: linkCtx._val,
					value: sourceValue
				};
				if ((!onBeforeChange || !(cancel = onBeforeChange.call(linkCtx, ev, eventArgs) === false)) &&
						(!tag || !tag.onBeforeChange || !(cancel = tag.onBeforeChange(ev, eventArgs) === false)) &&
						sourceValue !== undefined) {
					target = to[0]; // [object, path]
					if (sourceValue !== undefined && target) {
						if (target._jsv) {
							contextCb = linkCtx._ctxCb; // This is a computed value
							exprOb = target;
							target = linkCtx.data;
							if (exprOb._cpCtx) { // Computed value for a contextual parameter
								target = exprOb.data; // The data for the contextual view (where contextual param expression evaluated/assigned)
								contextCb = exprOb._cpCtx; // Context callback for contextual view
							}
							while (exprOb && exprOb.sb) { // Step through chained computed values to leaf one...
								target = contextCb(exprOb, target);
								exprOb = exprOb.sb;
							}
						}
						if (tag) {
							tag._.chging = true; // marker to prevent tag change event triggering its own refresh
						}
						$observable(target).setProperty(to[1], sourceValue); // 2way binding change event - observably updating bound object
						if (onAfterChange) {
							onAfterChange.call(linkCtx, ev, eventArgs);
						}
						if (tag) {
							if (tag.onAfterChange) {
								tag.onAfterChange(ev, eventArgs);
							}
							tag._.chging = undefined; // clear the marker
						}
						linkCtx._val = sourceValue;
					}
				}
				view.linkCtx = oldLinkCtx;
			}
		}
	}
}

function propertyChangeHandler(ev, eventArgs, linkFn) {
	var attr, sourceValue, noUpdate, forceUpdate, hasError, onError,
		linkCtx = this,
		tag = linkCtx.tag,
		source = linkCtx.data,
		target = linkCtx.elem,
		cvt = linkCtx.convert,
		parentElem = target.parentNode,
		view = linkCtx.view,
		oldLinkCtx = view.linkCtx,
		onEvent = view.hlp(onBeforeChangeStr);

	// Set linkCtx on view, dynamically, just during this handler call
	view.linkCtx = linkCtx;

	if (parentElem && (!onEvent || !(eventArgs && onEvent.call(linkCtx, ev, eventArgs) === false))
			// If data changed, the ev.data is set to be the path. Use that to filter the handler action...
			&& !(eventArgs && ev.data.prop !== "*" && ev.data.prop !== eventArgs.path)) {

		if (eventArgs) {
			linkCtx.eventArgs = eventArgs;
		}
		if (eventArgs || linkCtx._toLk) {
			// If eventArgs are defined, this is a data update
			// Otherwise this is the initial data-link rendering call. Bind on this the first time it get called
			linkCtx._toLk = 0; // Remove flag to skip unneccessary rebinding next time
			if (linkFn._er) {
				// data-link="exprUsingTagOrCvt with onerror=..." - e.g. {tag ... {cvt:... {:... convert='cvt'
				try {
					sourceValue = linkFn(source, view);
				} catch (e) {
					hasError = linkFn._er;
					onError = onRenderError(e,view,(new Function("data,view", "return " + hasError + ";"))(source, view));
					sourceValue = [{props: {}, args: [onError]}];
				}
			} else {
				sourceValue = linkFn(source, view, $sub);
			}
			// Compiled link expression for linkTag: return value for data-link="{:xxx}" with no cvt or cvtBk, otherwise tagCtx or tagCtxs

			attr = getTargetVal(sourceValue, linkCtx, tag = linkCtx.tag,
					linkCtx.attr || defaultAttr(target, true, cvt !== undefined)
				);

			if (tag) {
				// Existing tag instance
				forceUpdate = hasError || tag._er;
				// If the new tagCtxs hasError or the previous tagCtxs had error, then force update
				sourceValue = sourceValue[0] ? sourceValue : [sourceValue];
				noUpdate = !forceUpdate && eventArgs && tag.onUpdate && tag.onUpdate(ev, eventArgs, sourceValue) === false;

				mergeCtxs(tag, sourceValue, forceUpdate);

				if (noUpdate || attr === NONE) {
					// onUpdate returned false, or attr === "none", or this is an update coming from the tag's own change event
					// - so don't refresh the tag: we just use the new tagCtxs merged from the sourceValue,
					// (which may optionally have been modifed in onUpdate()...) and then bind, and we are done
					callAfterLink(tag, ev, eventArgs);
					observeAndBind(linkCtx, source, target);
					view.linkCtx = oldLinkCtx;
					return;
				}
				if (tag._.chging) {
					return;
				}

				if (tag.onUnbind) {
					tag.onUnbind(tag.tagCtx, linkCtx, tag.ctx, ev, eventArgs);
				}

				sourceValue = tag.tagName === ":" // Call convertVal if it is a {{cvt:...}} - otherwise call renderTag
					? $sub._cnvt(tag.cvt, view, sourceValue[0])
					: $sub._tag(tag, view, view.tmpl, sourceValue, true, onError);
			} else if (linkFn._tag) {
				// For {{: ...}} without a convert or convertBack, we already have the sourceValue, and we are done
				// For {{: ...}} with either cvt or cvtBack we call convertVal to get the sourceValue and instantiate the tag
				// If cvt is undefined then this is a tag, and we call renderTag to get the rendered content and instantiate the tag
				cvt = cvt === "" ? TRUE : cvt; // If there is a cvtBack but no cvt, set cvt to "true"
				sourceValue = cvt // Call convertVal if it is a {{cvt:...}} - otherwise call renderTag
					? $sub._cnvt(cvt, view, sourceValue[0] || sourceValue) // convertVal
					: $sub._tag(linkFn._tag, view, view.tmpl, sourceValue, true, onError); // renderTag

				addLinkMethods(tag = linkCtx.tag, true); // In both convertVal and renderTag we have instantiated a tag
				attr = linkCtx.attr || attr; // linkCtx.attr may have been set to tag.attr during tag instantiation in renderTag
			}

			if (updateContent(sourceValue, linkCtx, attr, tag)
					&& eventArgs
					&& (onEvent = view.hlp(onAfterChangeStr))) {
				onEvent.call(linkCtx, ev, eventArgs);
			}
			linkCtx._noUpd = 0; // For data-link="^{...}" remove _noUpd flag so updates on subsequent calls

			if (tag) {
				tag._er = hasError;
				callAfterLink(tag, ev, eventArgs);
			}
		}

		observeAndBind(linkCtx, source, target);

		// Remove dynamically added linkCtx from view
		view.linkCtx = oldLinkCtx;
	}
}

function getTargetVal(sourceValue, linkCtx, tag, attr) {
	var currentValue, setter, css, $target,
		target = tag && tag.parentElem || linkCtx.elem;

	if (sourceValue !== undefined) {
		$target = $(target);
		attr = tag && tag.attr || attr;
		if ($isFunction(sourceValue)) {
			error(linkCtx.expr + ": missing parens");
		}

		if (css = /^css-/.test(attr) && attr.slice(4)) {
			currentValue = $.style(target, css);
			if (+sourceValue === sourceValue) {
				// Optimization for perf on integer values - e.g. css-width{:width+'px'}
				currentValue = parseInt(currentValue);
			}
		} else if (attr !== "link") { // attr === "link" is for tag controls which do data binding but have no rendered output or target
			if (attr === "value") {
				if (target.type === CHECKBOX) {
					currentValue = $target.prop(attr = CHECKED);
				}
			} else if (attr === RADIO) {
				if (target.value === ("" + sourceValue)) {
					currentValue = $target.prop(CHECKED);
				} else {
					return attr;
				}
			}

			if (currentValue === undefined) {
				setter = fnSetters[attr];
				currentValue = setter ? $target[setter]() : $target.attr(attr);
			}
		}
		linkCtx._val = currentValue;
	}
	return attr;
}

function setDefer(elem, value) {
	elem._df = value; // Use both an expando and an attribute to track defered tokens. Attribute is needed for querySelectorAll for getViewInfos (childTags)
	elem[(value ? "set" : "remove") + "Attribute"](deferAttr, "");
}

function updateContent(sourceValue, linkCtx, attr, tag) {
	// When called for a tag, either in tag.refresh() or propertyChangeHandler(), returns a promise (and supports async)
	// When called (in propertyChangeHandler) for target HTML returns true
	// When called (in propertyChangeHandler) for other targets returns boolean for "changed"
	var setter, prevNode, nextNode, promise, nodesToRemove, useProp, tokens, id, openIndex, closeIndex, testElem, nodeName, cStyle, jsvSel,
		renders = attr !== NONE && sourceValue !== undefined && !linkCtx._noUpd, // For data-link="^{...}", don't update the first time (no initial render) - e.g. to leave server rendered values.
		source = linkCtx.data,
		target = tag && tag.parentElem || linkCtx.elem,
		targetParent = target.parentNode,
		$target = $(target),
		view = linkCtx.view,
		targetVal = linkCtx._val,
		oldLinkCtx = view.linkCtx,
		// If not a tag we can use the ._val obtained from getTargetVal()
		// and only update when the new value (sourceValue) has changed from the previous one
		change = tag;

	if (tag) {
		// Initialize the tag with element references
		tag._.unlinked = true; // Set to unlinked, so initialization is triggered after re-rendering, e.g. for setting linkedElem, and calling onBind
		tag.parentElem = tag.parentElem || (linkCtx.expr || tag._elCnt) ? target : targetParent;
		prevNode = tag._prv;
		nextNode = tag._nxt;
	}
	if (!renders) {
		return;
	}

	if (attr === "visible") {
		attr = "css-display";
	}
	if (/^css-/.test(attr)) {
		if (linkCtx.attr === "visible") {
			// Get the current display style
			cStyle = (target.currentStyle || getComputedStyle.call(global, target, "")).display;

			if (sourceValue) {
				// We are showing the element.
				// Get the cached 'visible' display value from the -jsvd expando
				sourceValue = target._jsvd
					// Or, if not yet cached, get the current display value
					|| cStyle;
				if (sourceValue === NONE && !(sourceValue = displayStyles[nodeName = target.nodeName])) {
					// Currently display value is 'none', and the 'visible' style has not been cached.
					// We create an element to find the correct 'visible' display style for this nodeName
					testElem = document.createElement(nodeName);
					document.body.appendChild(testElem);

					// Get the default style for this HTML tag to use as 'visible' style
					sourceValue
						// and cache it as a hash against nodeName
						= displayStyles[nodeName]
						= (testElem.currentStyle || getComputedStyle.call(global, testElem, "")).display;
					document.body.removeChild(testElem);
				}
			} else {
				// We are hiding the element.
				// Cache the current display value as 'visible' style, on _jsvd expando, for when we show the element again
				target._jsvd = cStyle;
				sourceValue = NONE; // Hide the element
			}
		}
		if (change = change || targetVal !== sourceValue) {
			$.style(target, attr.slice(4), sourceValue);
		}
	} else if (attr !== "link") { // attr === "link" is for tag controls which do data binding but have no rendered output or target
		if (/^data-/.test(attr)) {
			$.data(target, attr.slice(5), sourceValue); // Support for binding to data attributes: data-foo{:expr}: data-foo attribute will be
			// expr.toString(), but $.data(element, "foo") and $(element).data("foo") will actually return value of expr, even if of type object
		}
		if (attr === CHECKED) {
			useProp = true;
			sourceValue = sourceValue && sourceValue !== "false";
			// The string value "false" can occur with data-link="checked{attr:expr}" - as a result of attr, and hence using convertVal()
			// We will set the "checked" property
			// We will compare this with the current value
		} else if (attr === RADIO) {
			// This is a special binding attribute for radio buttons, which corresponds to the default 'to' binding.
			// This allows binding both to value (for each input) and to the default checked radio button (for each input in named group,
			// e.g. binding to parent data).
			// Place value binding first: <input type="radio" data-link="value{:name} {:#get('data').data.currency:} " .../>
			// or (allowing any order for the binding expressions):
			// <input type="radio" value="{{:name}}" data-link="{:#get('data').data.currency:} value^{:name}" .../>
			useProp = true;
			attr = CHECKED;
			sourceValue = target.value === ("" + sourceValue);
			// If the data value corresponds to the value attribute of this radio button input, set the checked property to true
			// Otherwise set the checked property to false
		} else if (attr === "selected" || attr === "disabled" || attr === "multiple" || attr === "readonly") {
			sourceValue = (sourceValue && sourceValue !== "false") ? attr : null;
			// Use attr, not prop, so when the options (for example) are changed dynamically, but include the previously selected value,
			// they will still be selected after the change
		} else if (attr === "value" && target.nodeName === "SELECT") {
			target._jsvSel = $isArray(sourceValue)
				? sourceValue
				: "" + sourceValue; // If not array, coerce to string
		}

		if (setter = fnSetters[attr]) {
			if (attr === HTML) {
				// Set linkCtx on view, dynamically, just during this handler call
				view.linkCtx = linkCtx;
				if (tag && tag._.inline) {
					nodesToRemove = tag.nodes(true);
					if (tag._elCnt) {
						if (prevNode && prevNode !== nextNode) {
							// This prevNode will be removed from the DOM, so transfer the view tokens on prevNode to nextNode of this 'viewToRefresh'
							transferViewTokens(prevNode, nextNode, target, tag._tgId, "^", true);
						} else if (tokens = target._df) { // This occurs when there is no nextNode, and so the target._df may include tokens referencing
							// view and tag bindings contained within the open and close tokens of the updated tag control. They need to be processed (disposed)
							id = tag._tgId + "^";
							openIndex = tokens.indexOf("#" + id) + 1;
							closeIndex = tokens.indexOf("/" + id);

							if (openIndex && closeIndex > 0) {
								openIndex += id.length;
								if (closeIndex > openIndex) {
									setDefer(target, tokens.slice(0, openIndex) + tokens.slice(closeIndex));
									disposeTokens(tokens.slice(openIndex, closeIndex));
								}
							}
						}
						prevNode = prevNode
							? prevNode.previousSibling
							: nextNode
								? nextNode.previousSibling
								: target.lastChild;
					}
					// Remove HTML nodes
					$(nodesToRemove).remove(); // Note if !tag._elCnt removing the nodesToRemove will process and dispose view and tag bindings contained within the updated tag control

					// Insert and link new content
					promise = view.link(view.data, target, prevNode, nextNode, sourceValue, tag && {tag: tag._tgId, lazyLink: tag.tagCtx.props.lazyLink});
				} else {
					// data-linked value targeting innerHTML: data-link="html{:expr}" or contenteditable="true"
					renders = renders && targetVal !== sourceValue;
					if (renders) {
						$target.empty();
					}
					if (renders) {
						promise = view.link(source, target, prevNode, nextNode, sourceValue, tag && {tag: tag._tgId});
					}
				}
				// Remove dynamically added linkCtx and ctx from view
				view.linkCtx = oldLinkCtx;
			} else {
				if (change = change || targetVal !== sourceValue) {
					if (attr === "text" && target.children && !target.children[0]) {
						// This code is faster then $target.text()
						if (target.textContent !== undefined) {
							target.textContent = sourceValue;
						} else {
							target.innerText = sourceValue === null ? "" : sourceValue;
						}
					} else {
						$target[setter](sourceValue);
					}
				}
				if ((jsvSel = targetParent._jsvSel)
					// Setting value of <option> element
					&& (attr === "value" || !$target.attr("value"))) { // Setting value attribute, or setting textContent if attribute is null
					// Set/unselect selection based on value set on parent <select>. Works for multiselect too
					target.selected = $.inArray("" + sourceValue, $isArray(jsvSel) ? jsvSel : [jsvSel]) > -1;
				}
			}
		} else if (change = change || targetVal !== sourceValue) {
			// Setting an attribute to undefined should remove the attribute
			$target[useProp ? "prop" : "attr"](attr, sourceValue === undefined && !useProp ? null : sourceValue);
		}
		linkCtx._val = sourceValue;
	}
	return promise || change;
}

function arrayChangeHandler(ev, eventArgs) {
	var self = this,
		onBeforeChange = self.hlp(onBeforeChangeStr),
		onAfterChange = self.hlp(onAfterChangeStr);
	if (!onBeforeChange || onBeforeChange.call(this, ev, eventArgs) !== false) {
		if (eventArgs) {
			// This is an observable action (not a trigger/handler call from pushValues, or similar, for which eventArgs will be null)
			var action = eventArgs.change,
				index = eventArgs.index,
				items = eventArgs.items;
			self._.srt = eventArgs.refresh; // true if part of a 'sort' on refresh
			switch (action) {
				case "insert":
					self.addViews(index, items);
					break;
				case "remove":
					self.removeViews(index, items.length);
					break;
				case "move":
					self.removeViews(eventArgs.oldIndex, items.length, undefined, true); // remove
					self.addViews(index, items); // re-insert
					break;
				case "refresh":
					self._.srt = undefined;
					self.fixIndex(0);
					// Other cases: (e.g.undefined, for setProperty on observable object) etc. do nothing
			}
		}
		if (onAfterChange) {
			onAfterChange.call(this, ev, eventArgs);
		}
	}
}

//=============================
// Utilities for event handlers
//=============================

function setArrayChangeLink(view) {
	// Add/remove arrayChange handler on view
	var handler, arrayBinding,
		type = view.type, // undefined if view is being removed
		data = view.data,
		bound = view._.bnd; // true for top-level link() or data-link="{for}", or the for tag instance for {^{for}} (or for any custom tag that has an onArrayChange handler)

	if (!view._.useKey && bound) {
		// This is an array view. (view._.useKey not defined => data is array), and is data-bound to collection change events

		if (arrayBinding = view._.bndArr) {
			// First remove the current handler if there is one
			$([arrayBinding[1]]).off(arrayChangeStr, arrayBinding[0]);
			view._.bndArr = undefined;
		}
		if (bound !== !!bound) {
			// bound is not a boolean, so it is the data-linked tag that 'owns' this array binding - e.g. {^{for...}}
			if (type) {
				bound._.arrVws[view._.id] = view;
			} else {
				delete bound._.arrVws[view._.id]; // if view.type is undefined, view is being removed
			}
		} else if (type && data) {
			// If this view is not being removed, but the data array has been replaced, then bind to the new data array
			handler = function(ev) {
				if (!(ev.data && ev.data.off)) {
					// Skip if !!ev.data.off: - a handler that has already been removed (maybe was on handler collection at call time - then removed by another handler)
					// If view.type is undefined, do nothing. (Corresponds to case where there is another handler on the same data whose
					// effect was to remove this view, and which happened to precede this event in the trigger sequence. So although this
					// event has been removed now, it is still called since already on the trigger sequence)
					arrayChangeHandler.apply(view, arguments);
				}
			};
			$([data]).on(arrayChangeStr, handler);
			view._.bndArr = [handler, data];
		}
	}
}

function defaultAttr(elem, to, linkGetVal) {
	// to: true - default attribute for setting data value on HTML element; false: default attribute for getting value from HTML element
	// Merge in the default attribute bindings for this target element
	var nodeName = elem.nodeName.toLowerCase(),
		attr =
			$subSettingsAdvanced._fe[nodeName] // get form element binding settings for input textarea select or optgroup
			|| elem.contentEditable === TRUE && {to: HTML, from: HTML}; // Or if contentEditable set to "true" set attr to "html"
	return attr
		? (to
			? ((nodeName === "input" && elem.type === RADIO) // For radio buttons, bind from value, but bind to 'radio' - special value.
				? RADIO
				: attr.to)
			: attr.from)
		: to
			? linkGetVal ? "text" : HTML // Default innerText for data-link="a.b.c" or data-link="{:a.b.c}" (with or without converters)- otherwise innerHTML
			: ""; // Default is not to bind from
}

//==============================
// Rendering and DOM insertion
//==============================

function renderAndLink(view, index, tmpl, views, data, context, refresh) {
	var html, linkToNode, prevView, nodesToRemove, bindId,
		parentNode = view.parentElem,
		prevNode = view._prv,
		nextNode = view._nxt,
		elCnt = view._elCnt;

	if (prevNode && prevNode.parentNode !== parentNode) {
		error("Missing parentNode");
		// Abandon, since node has already been removed, or wrapper element has been inserted between prevNode and parentNode
	}

	if (refresh) {
		nodesToRemove = view.nodes();
		if (elCnt && prevNode && prevNode !== nextNode) {
			// This prevNode will be removed from the DOM, so transfer the view tokens on prevNode to nextNode of this 'viewToRefresh'
			transferViewTokens(prevNode, nextNode, parentNode, view._.id, "_", true);
		}
		// Remove child views
		view.removeViews(undefined, undefined, true);
		linkToNode = nextNode;

		if (elCnt) {
			prevNode = prevNode
				? prevNode.previousSibling
				: nextNode
					? nextNode.previousSibling
					: parentNode.lastChild;
		}

		// Remove HTML nodes
		$(nodesToRemove).remove();

		for (bindId in view._.bnds) {
			// The view bindings may have already been removed above in: $(nodesToRemove).remove();
			// If not, remove them here:
			removeViewBinding(bindId);
		}
	} else {
		// addViews. Only called if view is of type "array"
		if (index) {
			// index is a number, so indexed view in view array
			prevView = views[index - 1];
			if (!prevView) {
				return false; // If subview for provided index does not exist, do nothing
			}
			prevNode = prevView._nxt;
		}
		if (elCnt) {
			linkToNode = prevNode;
			prevNode = linkToNode
				? linkToNode.previousSibling         // There is a linkToNode, so insert after previousSibling, or at the beginning
				: parentNode.lastChild;              // If no prevView and no prevNode, index is 0 and the container is empty,
				// so prevNode = linkToNode = null. But if prevView._nxt is null then we set prevNode to parentNode.lastChild
				// (which must be before the prevView) so we insert after that node - and only link the inserted nodes
		} else {
			linkToNode = prevNode.nextSibling;
		}
	}
	html = tmpl.render(data, context, view._.useKey && refresh, view, refresh || index, true);
	// Pass in view._.useKey as test for noIteration (which corresponds to when self._.useKey > 0 and self.data is an array)

	// Link the new HTML nodes to the data
	view.link(data, parentNode, prevNode, linkToNode, html, prevView);
//}, 0);
}

//=====================
// addBindingMarkers
//=====================

function addBindingMarkers(value, view, tag) {
	// Insert binding markers into the rendered template output, which will get converted to appropriate
	// data-jsv attributes (element-only content) or script marker nodes (phrasing or flow content), in convertMarkers,
	// within view.link, prior to inserting into the DOM. Linking will then bind based on these markers in the DOM.
	// Added view markers: #m_...VIEW.../m_
	// Added tag markers: #m^...TAG..../m^
	var id, end;
	if (tag) {
		// This is a binding marker for a data-linked tag {^{...}}
		end = "^`";
		addLinkMethods(tag, true); // This is {^{>...}} or {^{tag ...}}, {{cvt:...} or {^{:...}}, and tag was defined in convertVal or renderTag
		id = tag._tgId;
		if (!id) {
			bindingStore[id = bindingKey++] = tag; // Store the tag temporarily, ready for databinding.
			// During linking, in addDataBinding, the tag will be attached to the linkCtx,
			// and then in observeAndBind, bindingStore[bindId] will be replaced by binding info.
			tag._tgId = "" + id;
		}
	} else {
		// This is a binding marker for a view
		// Add the view to the store of current linked views
		end = "_`";
		addLinkMethods(viewStore[id = view._.id] = view);
	}
	// Example: "#23^TheValue/23^"
	return "#" + id + end
		+ (value != undefined ? value : "") // For {^{:name}} this gives the equivalent semantics to compiled
											// (v=data.name)!=null?v:""; used in {{:name}} or data-link="name"
		+ "/" + id + end;
}

//==============================
// Data-linking and data binding
//==============================

//---------------
// observeAndBind
//---------------

function observeAndBind(linkCtx, source, target) {
	var binding, l, k, linkedElem, exprFnDeps, exprOb, prop, propDeps,
		tag = linkCtx.tag,
		cvtBk = linkCtx.convertBack,
		depends = [],
		bindId = linkCtx._bndId || "" + bindingKey++,
		handler = linkCtx._hdl;

	linkCtx._bndId = undefined;

	if (tag) {
		// Use the 'depends' paths set on linkCtx.tag - which may have been set on declaration
		// or in events: init, render, onAfterLink etc.
		depends = tag.depends || depends;
		depends = $isFunction(depends) ? tag.depends(tag) : depends;
		linkedElem = tag.linkedElem;
	}
	if (!linkCtx._depends || ("" + linkCtx._depends !== "" + depends)) {
		// Only bind the first time, or if the new depends (toString) has changed from when last bound
		if (linkCtx._depends) {
			// Unobserve previous binding
			$observable._apply(false, [source], linkCtx._depends, handler, true);
		}

		exprFnDeps = linkCtx.fn.deps.slice(); // Make a copy of the dependency paths for the compiled linkCtx expression - to pass to observe(). In getInnerCb(),
		// (and whenever the object is updated, in innerCb), we will set exprOb.ob to the current object returned by that computed expression, for this view.

		if (tag && tag.boundProps) {
			// Add dependency paths for declared boundProps (so no need to writh ^myprop=... to get binding) and for linkedProp too if there is one
			l = tag.boundProps.length;
			while (l--) {
				prop = tag.boundProps[l];
				k = tag._.bnd.paths.length;
				while (k--) {
					propDeps = tag._.bnd.paths[k][prop];
					if (propDeps && propDeps.skp) { // Not already a bound prop ^prop=expression;
						exprFnDeps = exprFnDeps.concat(propDeps); // Add dependencies for this prop expression
					}
				}
			}
		}

		l = exprFnDeps.length;
		while (l--) {
			exprOb = exprFnDeps[l];
			if (exprOb._jsv) {
				// This path is an 'exprOb', corresponding to a computed, returning an object. We replace the exprOb by
				// a view-binding-specific exprOb instance. The current object will be stored as exprOb.ob.
				exprFnDeps[l] = $extend({}, exprOb);
			}
		}

		binding = $observable._apply(
			false,
			[source],
			exprFnDeps, // flatten the paths - to gather all the dependencies across args and bound params
			depends,
			handler,
			linkCtx._ctxCb);
		// The binding returned by $observe has a bnd array with the source objects of the individual bindings.

		binding.elem = target; // The target of all the individual bindings
		binding.linkCtx = linkCtx;
		binding._tgId = bindId;

		// Add to the _jsvBnd on the target the view id and binding id - for unbinding when the target element is removed
		target._jsvBnd = target._jsvBnd || "";
		target._jsvBnd += "&" + bindId;
		linkCtx._depends = depends;
		// Store the binding key on the view, for disposal when the view is removed
		linkCtx.view._.bnds[bindId] = bindId;
		// Store the binding.
		bindingStore[bindId] = binding; // Note: If this corresponds to a data-linked tag, we are replacing the
		// temporarily stored tag by the stored binding. The tag will now be at binding.linkCtx.tag

		if (linkedElem) {
			l = linkedElem.length;
			while (l--) {
				linkedElem[l]._jsvLkEl = tag;
				bindTo(binding, tag, linkedElem[l]);
				linkedElem[l]._jsvBnd = "&" + binding._tgId + "+"; // Add a "+" for cloned binding - so removing
				// elems with cloned bindings will not remove the 'parent' binding from the bindingStore.
			}
		} else if (cvtBk !== undefined) {
			bindTo(binding, tag, target, cvtBk);
		}

		if (tag) {
			if (!tag.flow && !tag._.inline) {
				target.setAttribute(jsvAttrStr, (target.getAttribute(jsvAttrStr)||"") + "#" + bindId + "^/" + bindId + "^");
				tag._tgId = "" + bindId;
			}
		}
	}
}

//-------
// $.link
//-------

function tmplLink(to, from, context, noIteration, parentView, prevNode, nextNode) {
	return $link(this, to, from, context, noIteration, parentView, prevNode, nextNode);
}

function $link(tmplOrLinkExpr, to, from, context, noIteration, parentView, prevNode, nextNode) {
	// When linking from a template, prevNode and nextNode parameters are ignored
	if (context === true) {
		noIteration = context; // passing boolean as third param - noIteration
		context = undefined;
	} else if (typeof context !== "object") {
		context = undefined; // context must be a boolean (noIteration) or a plain object
	} else {
		context = $extend({}, context);
	}
	if (tmplOrLinkExpr && to) {
		to = to.jquery ? to : $(to); // to is a jquery object or an element or selector

		if (!activeBody) {
			activeBody = document.body;
			$(activeBody)
				.on(elementChangeStr, elemChangeHandler)
				.on('blur', '[contenteditable]', elemChangeHandler);
		}

		var i, k, html, vwInfos, view, placeholderParent, targetEl, refresh, topLevelCall,
			onRender = addBindingMarkers,
			replaceMode = context && context.target === "replace",
			l = to.length;

		while (l--) {
			targetEl = to[l];

			parentView = parentView || $view(targetEl);

			if (topLevelCall = parentView === topView) {
				topView.data = (topView.ctx = context || {}).root = from;
			}
			if ("" + tmplOrLinkExpr === tmplOrLinkExpr) {
				// tmplOrLinkExpr is a string: treat as data-link expression.
				addDataBinding(tmplOrLinkExpr, targetEl, parentView, undefined, true, from, context);
			} else {
				if (tmplOrLinkExpr.markup !== undefined) {
					// This is a call to template.link()
					if (replaceMode) {
						placeholderParent = targetEl.parentNode;
					}

					html = tmplOrLinkExpr.render(from, context, noIteration, parentView, undefined, onRender);
					// TODO Consider finding a way to bind data (link) within template without html being different for each view, the HTML can
					// be evaluated once outside the while (l--), and pushed into a document fragment, then cloned and inserted at each target.

					if (placeholderParent) {
						// This is target="replace" mode
						prevNode = targetEl.previousSibling;
						nextNode = targetEl.nextSibling;
						$.cleanData([targetEl], true);
						placeholderParent.removeChild(targetEl);

						targetEl = placeholderParent;
					} else {
						prevNode = nextNode = undefined; // When linking from a template, prevNode and nextNode parameters are ignored
						$(targetEl).empty();
					}
				} else if (tmplOrLinkExpr === true && parentView === topView) {
					// $.link(true, selector, data, ctx) - where selector points to elem in top-level content. (If not top-level content, no-op)
					refresh = {lnk: 1};
				} else {
					break;
				}

// TODO Consider deferred linking API feature on per-template basis - {@{ instead of {^{ which allows the user to see the rendered content
// before that content is linked, with better perceived perf. Have view.link return a deferred, and pass that to onAfterLink...
// or something along those lines.
// setTimeout(function() {

				if (targetEl._df && !nextNode) {
					// We are inserting new content and the target element has some deferred binding annotations,and there is no nextNode.
					// Those views may be stale views (that will be recreated in this new linking action) so we will first remove them
					// (if not already removed).
					vwInfos = viewInfos(targetEl._df, true, rOpenViewMarkers);

					for (i = 0, k = vwInfos.length; i < k; i++) {
						view = vwInfos[i];
						if ((view = viewStore[view.id]) && view.data !== undefined) {
							// If this is the _prv (prevNode) for a view, remove the view
							// - unless view.data is undefined, in which case it is already being removed
							view.parent.removeViews(view._.key, undefined, true);
						}
					}
					setDefer(targetEl); // remove defer tokens
				}

				// Link the content of the element, since this is a call to template.link(), or to $(el).link(true, ...),
				parentView.link(from, targetEl, prevNode, nextNode, html, refresh, context);
//}, 0);
			}
			if (topLevelCall) {
				topView.data = topView.ctx = undefined;
			}
		}
	}
	return to; // Allow chaining, to attach event handlers, etc.
}

//----------
// view.link
//----------

function viewLink(outerData, parentNode, prevNode, nextNode, html, refresh, context, validateOnly) {
	// Optionally insert HTML into DOM using documentFragments (and wrapping HTML appropriately).
	// Data-link existing contents of parentNode, or the inserted HTML, if provided

	// Depending on the content model for the HTML elements, the standard data-linking markers inserted in the HTML by addBindingMarkers during
	// template rendering will be converted either to script marker nodes or, for element-only content sections, to data-jsv element annotations.

	// Data-linking will then add _prv and _nxt to views, where:
	//     _prv: References the previous node (script element of type "jsv123"), or (for elCnt=true), the first element node in the view (or if none, set _prv = _nxt)
	//     _nxt: References the last node (script element of type "jsv/123"), or (for elCnt=true), the next element node after the view.

	//==== nested functions ====
	function convertMarkers(all, preceding, selfClose, closeTag, spaceBefore, id, boundId, spaceAfter, tag1, tag2, closeTag2, spaceAfterClose, selfClose2, endOpenTag) {
		// rConvertMarkers = /(^|(\/>)|<\/(\w+)>|)(\s*)([#\/]\d+(?:_|(\^)))`(\s*)(<\w+(?=[\s\/>]))?|\s*(?:(<\w+(?=[\s\/>]))|<\/(\w+)>(\s*)|(\/>)\s*|(>))/g,
		//                 prec, slfCl, clsTag,  spBefore, id,      bndId  spAfter,tag1,                   tag2,               clTag2,sac  slfCl2, endOpenTag
		// Convert the markers that were included by addBindingMarkers in template output, to appropriate DOM annotations:
		// data-jsv attributes (for element-only content) or script marker nodes (within phrasing or flow content).

// TODO consider detecting 'quoted' contexts (attribute strings) so that attribute encoding does not need to encode >
// Currently rAttrEncode = /[><"'&]/g includes '>' encoding in order to avoid erroneous parsing of <span title="&lt;a/>"></span>">
		var errorMsg, bndId,
			endOfElCnt = "";
		if (endOpenTag) {
			inTag = 0;
			return all;
		}
		tag = tag1 || tag2 || "";
		closeTag = closeTag || closeTag2;
		selfClose = selfClose || selfClose2;
		if (isVoid && !selfClose && ( !all || closeTag || tag || id && !inTag)) { // !all = end of string
			isVoid = undefined;
			parentTag = tagStack.shift(); // preceding tag was a void element, with no closing slash, such as <br>.
		}
		closeTag = closeTag || selfClose;
		if (closeTag) {
			inTag = 0;
			isVoid = undefined;
			// TODO: smart insertion of <tbody> - to be completed for robust insertion of deferred bindings etc.
			//if (closeTag === "table" && parentTag === "tbody") {
			//	preceding = "</tbody>" + preceding;
			//	parentTag = "table";
			//	tagStack.shift();
			//}
			if (validate) {
				if (selfClose || selfClose2) {
					if (!voidElems[parentTag] && !/;svg;|;math;/.test(";" + tagStack.join(";") + ";")) {
						// Only self-closing elements must be legitimate void elements, such as <br/>, per HTML schema,
						// or under svg or math foreign namespace elements.
						errorMsg = "'<" + parentTag + ".../";
					}
				} else if (voidElems[closeTag]) {
					errorMsg = "'</" + closeTag; // closing tag such as </input>
				} else if (!tagStack.length || closeTag !== parentTag) {
					errorMsg = "Mismatch: '</" + closeTag;
				}
				if (errorMsg) {
					syntaxError(errorMsg + ">' in:\n" + html);
				}
			}
			prevElCnt = elCnt;
			parentTag = tagStack.shift();
			elCnt = elContent[parentTag];
			closeTag2 = closeTag2 ? ("</" + closeTag2 + ">") : "";
			if (prevElCnt) {
				// If there are ids (markers since the last tag), move them to the defer string
				defer += ids;
				ids = "";
				if (!elCnt) {
					endOfElCnt = closeTag2 + openScript + "@" + defer + closeScript + (spaceAfterClose || "");
					defer = deferStack.shift();
				} else {
					defer += "-"; // Will be used for stepping back through deferred tokens
				}
			}
		}
		if (elCnt) {
			// elContent maps tagNames which have only element content, so may not support script nodes.
			// We are in element-only content, can remove white space, and use data-jsv attributes on elements as markers
			// Example: <tr data-jsv="/2_#6_"> - close marker for view 2 and open marker for view 6

			if (id) {
				// append marker for this id, to ids string
				ids += id;
			} else {
				preceding = (closeTag2 || selfClose2 || "");
			}
			if (tag) {
				// TODO: smart insertion of <tbody> - to be completed for robust insertion of deferred bindings etc.
				//if (tag === "<tr" && parentTag === "table") {
				//	tagStack.unshift(parentTag);
				//	parentTag = "tbody";
				//	preceding += "<" + parentTag + ">";
				//	if (defer) {
				//		defer += "+"; // Will be used for stepping back through deferred tokens
				//	}
				//	// TODO: move this to design-time validation check
				//	//	error('"' + parentTag + '" has incorrect parent tag');
				//}
				preceding += tag;
				if (ids) {
					preceding += ' ' + jsvAttrStr + '="' + ids + '"';
					ids = "";
				}
			}
		} else {
			// We are in phrasing or flow content, so use script marker nodes
			// Example: <script type="jsv3/"></script> - data-linked tag, close marker
			// We validate with inTag so no script markers are inserted in attribute context e.g. for:
			// "<table {{if ...}}...{{/if}}... >" or "<table {{if ...}}...> ...{{/if}}..."
			preceding = id
				? (preceding + endOfElCnt + spaceBefore + (inTag ? "" : openScript + id + closeScript)+ spaceAfter + tag)
				: endOfElCnt || all;
		}

		if (validate && boundId) {
			if (inTag) {
				// JsViews data-linking tags are not allowed within element markup.
				// See jsviews/issues/303
				syntaxError('{^{ within elem markup (' + inTag + ' ). Use data-link="..."');
			}
			if (id.charAt(0) === "#") {
				tagStack.unshift(id.slice(1));
			} else if (id.slice(1) !== (bndId = tagStack.shift())) {
				// See jsviews/issues/213
				syntaxError('Closing tag for {^{...}} under different elem: <' + bndId + '>');
			}
		}
		if (tag) {
			inTag = tag;
			// If there are ids (markers since the last tag), move them to the defer string
			tagStack.unshift(parentTag);
			parentTag = tag.slice(1);
			if (validate && tagStack[0] && tagStack[0] === badParent[parentTag]) {
				// Missing <tbody>
				// TODO: replace this by smart insertion of <tbody> tags
				error('Parent of <tr> must be <tbody>');
			}
			isVoid = voidElems[parentTag];
			if ((elCnt = elContent[parentTag]) && !prevElCnt) {
				deferStack.unshift(defer);
				defer = "";
			}
			prevElCnt = elCnt;
//TODO Consider providing validation which throws if you place <span> as child of <tr>, etc. - since if not caught,
//this can cause errors subsequently which are difficult to debug.
//				if (elContent[tagStack[0]]>2 && !elCnt) {
//					error(parentTag + " in " + tagStack[0]);
//				}
			if (defer && elCnt) {
				defer += "+"; // Will be used for stepping back through deferred tokens
			}
		}
		return preceding;
	}

	function processViewInfos(vwInfos, targetParent) {
		// If targetParent, we are processing viewInfos (which may include navigation through '+-' paths) and hooking up to the right parentElem etc.
		// (and elem may also be defined - the next node)
		// If no targetParent, then we are processing viewInfos on newly inserted content
		var deferPath, deferChar, bindChar, parentElem, id, onAftCr, deep,
			addedBindEls = [];

		// In elCnt context (element-only content model), prevNode is the first node after the open, nextNode is the first node after the close.
		// If both are null/undefined, then open and close are at end of parent content, so the view is empty, and its placeholder is the
		// 'lastChild' of the parentNode. If there is a prevNode, then it is either the first node in the view, or the view is empty and
		// its placeholder is the 'previousSibling' of the prevNode, which is also the nextNode.
		if (vwInfos) {
			if (vwInfos._tkns.charAt(0) === "@") {
				// We are processing newly inserted content. This is a special script element that was created in convertMarkers() to process deferred bindings,
				// and inserted following the target parent element - because no element tags (outside elCnt) were encountered to carry those binding tokens.
				// We will step back from the preceding sibling of this element, looking at targetParent elements until we find the one that the current binding
				// token belongs to. Set elem to null (the special script element), and remove it from the DOM.
				targetParent = elem.previousSibling;
				elem.parentNode.removeChild(elem);
				elem = undefined;
			}
			len = vwInfos.length;
			while (len--) {
				vwInfo = vwInfos[len];
//if (prevIds.indexOf(vwInfo.token) < 0) { // This token is a newly created view or tag binding
				bindChar = vwInfo.ch;
				if (deferPath = vwInfo.path) {
					// We have a 'deferred path'
					j = deferPath.length - 1;
					while (deferChar = deferPath.charAt(j--)) {
						// Use the "+" and"-" characters to navigate the path back to the original parent node where the deferred bindings ocurred
						if (deferChar === "+") {
							if (deferPath.charAt(j) === "-") {
								j--;
								targetParent = targetParent.previousSibling;
							} else {
								targetParent = targetParent.parentNode;
							}
						} else {
							targetParent = targetParent.lastChild;
						}
						// Note: Can use previousSibling and lastChild, not previousElementSibling and lastElementChild,
						// since we have removed white space within elCnt. Hence support IE < 9
					}
				}
				if (bindChar === "^") {
					if (tag = bindingStore[id = vwInfo.id]) {
						// The binding may have been deleted, for example in a different handler to an array collectionChange event
						// This is a tag binding
						deep = targetParent && (!elem || elem.parentNode !== targetParent); // We are stepping back looking for the right targetParent,
						// or we are linking existing content and this element is in elCnt, not an immediate child of the targetParent.
						if (!elem || deep) {
							tag.parentElem = targetParent;
						}
						if (vwInfo.elCnt && deep) {
							// With element only content, if there is no following element, or if the binding is deeper than the following element
							// then we need to set the open or close token as a deferred binding annotation on the parent
							setDefer(targetParent, (vwInfo.open ? "#" : "/") + id + bindChar + (targetParent._df || ""));
						}
						// This is an open or close marker for a data-linked tag {^{...}}. Add it to bindEls.
						addedBindEls.push([deep ? null : elem, vwInfo]);
					}
				} else if (view = viewStore[id = vwInfo.id]) {
					// The view may have been deleted, for example in a different handler to an array collectionChange event
					if (!view.parentElem) {
						// If view is not already extended for JsViews, extend and initialize the view object created in JsRender, as a JsViews view
						view.parentElem = targetParent || elem && elem.parentNode || parentNode;
						view._.onRender = addBindingMarkers;
						view._.onArrayChange = arrayChangeHandler;
						setArrayChangeLink(view);
					}
					parentElem = view.parentElem;
					if (vwInfo.open) {
						// This is an 'open view' node (preceding script marker node,
						// or if elCnt, the first element in the view, with a data-jsv annotation) for binding
						view._elCnt = vwInfo.elCnt;
						if (targetParent && !elem) {
							setDefer(targetParent, "#" + id + bindChar + (targetParent._df || ""));
						} else {
							// No targetParent, so there is a ._nxt elem (and this is processing tokens on the elem)
							if (!view._prv) {
								setDefer(parentElem, removeSubStr(parentElem._df, "#" + id + bindChar));
							}
							view._prv = elem;
						}
					} else {
						// This is a 'close view' marker node for binding
						if (targetParent && (!elem || elem.parentNode !== targetParent)) {
							// There is no ._nxt so add token to _df. It is deferred.
							setDefer(targetParent, "/" + id + bindChar + (targetParent._df || ""));
							view._nxt = undefined;
						} else if (elem) {
							// This view did not have a ._nxt, but has one now, so token may be in _df, and must be removed. (No longer deferred)
							if (!view._nxt) {
								setDefer(parentElem, removeSubStr(parentElem._df, "/" + id + bindChar));
							}
							view._nxt = elem;
						}
						if (onAftCr = view.ctx && view.ctx[onAfterCreateStr] || onAfterCreate) {
							onAftCr.call(view.ctx.tag, view);
						}
					}
//}
				}
			}
			len = addedBindEls.length;
			while (len--) {
				// These were added in reverse order to addedBindEls. We push them in BindEls in the correct order.
				bindEls.push(addedBindEls[len]);
			}
		}
		return !vwInfos || vwInfos.elCnt;
	}

	function getViewInfos(vwInfos) {
		// Used by view.childTags() and tag.childTags()
		// Similar to processViewInfos in how it steps through bindings to find tags. Only finds data-linked tags.
		var level, parentTag, named;

		if (vwInfos) {
			len = vwInfos.length;
			for (j = 0; j < len; j++) {
				vwInfo = vwInfos[j];
				// This is an open marker for a data-linked tag {^{...}}, within the content of the tag whose id is get.id. Add it to bindEls.
				// Note - if bindingStore[vwInfo.id]._is === "tag" then getViewInfos is being called too soon - during first linking pass
				parentTag = tag = bindingStore[vwInfo.id].linkCtx.tag;
				named = tag.tagName === tagName;
				if (!tag.flow || named) {
					if (!deep) {
						level = 1;
						while (parentTag = parentTag.parent) {
							level++;
						}
						tagDepth = tagDepth || level; // The level of the first tag encountered.
					}
					if ((deep || level === tagDepth) && (!tagName || named)) {
						// Filter on top-level or tagName as appropriate
						tags.push(tag);
					}
				}
			}
		}
	}

	function dataLink() {
		//================ Data-link and fixup of data-jsv annotations ================
		var j, index,
			tokens = "",
			wrap = {},
			selector = linkViewsSel + (get ? ",[" + deferAttr + "]" : "");
			// If a childTags() call, get = ",[" + deferAttr + "]" - since we need to include elements that have a ._df expando for deferred tokens

		elems = qsa ? parentNode.querySelectorAll(selector) : $(selector, parentNode).get();
		l = elems.length;

		// The prevNode will be in the returned query, since we called markPrevOrNextNode() on it.
		// But it may have contained nodes that satisfy the selector also.
		if (prevNode && prevNode.innerHTML) {
			// Find the last contained node of prevNode, to use as the prevNode - so we only link subsequent elems in the query
			prevNodes = qsa ? prevNode.querySelectorAll(selector) : $(selector, prevNode).get();
			prevNode = prevNodes.length ? prevNodes[prevNodes.length - 1] : prevNode;
		}

		tagDepth = 0;
		for (i = 0; i < l; i++) {
			elem = elems[i];
			if (prevNode && !found) {
				// If prevNode is set, not false, skip linking. If this element is the prevNode, set to false so subsequent elements will link.
				found = (elem === prevNode);
			} else if (nextNode && elem === nextNode) {
				// If nextNode is set then break when we get to nextNode
				if (get) {
					tokens += markerNodeInfo(elem);
				}
				break;
			} else if (elem.parentNode) {
				// elem has not been removed from DOM
				if (get) {
					tokens += markerNodeInfo(elem);
					if (elem._df) {
						j = i + 1;
						while (j < l && elem.contains(elems[j])) {
							j++;
						}
						// Add defered tokens after any tokens on descendant elements of this one
						wrap[j-1] = elem._df;
					}
					if (wrap[i]) {
						tokens += wrap[i] || "";
					}
				} else {
					if (isLink && (vwInfo = viewInfos(elem, undefined, rViewMarkers)) && (vwInfo = vwInfo[0])) {
						// If this is a link(trueOrString ...) call we will avoid re-binding to elems that are within template-rendered views
						skip = skip ? (vwInfo.id !== skip && skip) : vwInfo.open && vwInfo.id;
					}
					if (!skip && processInfos(viewInfos(elem))
						// If a link() call, processViewInfos() adds bindings to bindEls, and returns true for non-script nodes, for adding data-link bindings
						// If a childTags() call, getViewInfos returns array of tag bindings.
							&& elem.getAttribute($viewsLinkAttr)) {
						bindEls.push([elem]); // A data-linked element so add to bindEls too
					}
				}
			}
		}

		if (get) {
			tokens += parentNode._df || "";
			if (index = tokens.indexOf("#" + get.id) + 1) {
				// We are looking for view.childTags() or tag.childTags() - so start after the open token of the parent view or tag.
				tokens = tokens.slice(index + get.id.length);
			}
			index = tokens.indexOf("/" + get.id);
			if (index + 1) {
				// We are looking for view.childTags() or tag.childTags() - so don't look beyond the close token of the parent view or tag.
				tokens = tokens.slice(0, index);
			}
			// Call getViewInfos to add the found childTags to the tags array
			getViewInfos(viewInfos(tokens, undefined, rOpenTagMarkers));
		}

		if (html === undefined && parentNode.getAttribute($viewsLinkAttr)) {
			bindEls.push([parentNode]); // Support data-linking top-level element directly (not within a data-linked container)
		}

		// Remove temporary marker script nodes they were added by markPrevOrNextNode
		unmarkPrevOrNextNode(prevNode, elCnt);
		unmarkPrevOrNextNode(nextNode, elCnt);

		if (get) {
			if (lazyLink) {
				lazyLink.resolve();
			}
			return; // We have added childTags to the tags array, so we are done
		}

		if (elCnt && defer + ids) {
			// There are some views with elCnt, for which the open or close did not precede any HTML tag - so they have not been processed yet
			elem = nextNode;
			if (defer) {
				if (nextNode) {
					processViewInfos(viewInfos(defer + "+", true), nextNode);
				} else {
					processViewInfos(viewInfos(defer, true), parentNode);
				}
			}
			processViewInfos(viewInfos(ids, true), parentNode);
			// If there were any tokens on nextNode which have now been associated with inserted HTML tags, remove them from nextNode
			if (nextNode) {
				tokens = nextNode.getAttribute(jsvAttrStr);
				if (l = tokens.indexOf(prevIds) + 1) {
					tokens = tokens.slice(l + prevIds.length - 1);
				}
				nextNode.setAttribute(jsvAttrStr, ids + tokens);
			}
		}

		//================ Bind the data-linked elements and tags ================
		l = bindEls.length;
		for (i = 0; i < l; i++) {
			elem = bindEls[i];
			linkInfo = elem[1];
			elem = elem[0];
			if (linkInfo) {
				if (tag = bindingStore[linkInfo.id]) {
					if (linkCtx = tag.linkCtx) {
						// The tag may have been stored temporarily on the bindingStore - or may have already been replaced by the actual binding
						tag = linkCtx.tag;
						tag.linkCtx = linkCtx;
					}
					if (linkInfo.open) {
						// This is an 'open linked tag' binding annotation for a data-linked tag {^{...}}
						if (elem) {
							tag.parentElem = elem.parentNode;
							tag._prv = elem;
						}
						tag._elCnt = linkInfo.elCnt;
						// We data-link depth-first ("on the way in"), which is better for perf - and allows setting parent tags etc.
						view = tag.tagCtx.view;
						addDataBinding(undefined, tag._prv, view, linkInfo.id);
					} else {
						tag._nxt = elem;
						if (tag._.unlinked) {
							// This is a 'close linked tag' binding annotation
							// Add data binding
							tagCtx = tag.tagCtx;
							view = tagCtx.view;
							callAfterLink(tag);
						}
					}
				}
			} else {
				// Add data binding for a data-linked element (with data-link attribute)
				addDataBinding(elem.getAttribute($viewsLinkAttr), elem, $view(elem), undefined, isLink, outerData, context);
			}
		}
		if (lazyLink) {
			lazyLink.resolve();
		}
	}
	//==== /end of nested functions ====

	var inTag, linkCtx, tag, i, l, j, len, elems, elem, view, vwInfo, linkInfo, prevNodes, token, prevView, nextView,
		node, tags, deep, tagName, tagCtx, validate, tagDepth, depth, fragment, copiedNode, firstTag, parentTag,
		isVoid, wrapper, div, tokens, elCnt, prevElCnt, htmlTag, ids, prevIds, found, skip, lazyLink, isLink, get,
		self = this,
		thisId = self._.id + "_",
		defer = "",
		// The marker ids for which no tag was encountered (empty views or final closing markers) which we carry over to container tag
		bindEls = [],
		tagStack = [],
		deferStack = [],
		onAfterCreate = self.hlp(onAfterCreateStr),
		processInfos = processViewInfos;

	if (refresh) {
		lazyLink = refresh.lazyLink && $.Deferred();
		if (refresh.tmpl) {
			// refresh is the prevView, passed in from addViews()
			prevView = "/" + refresh._.id + "_";
		} else {
			isLink = refresh.lnk; // Top-level linking
			if (refresh.tag) {
				thisId = refresh.tag + "^";
				refresh = true;
			}
			if (get = refresh.get) {
				processInfos = getViewInfos;
				tags = get.tags;
				deep = get.deep;
				tagName = get.name;
			}
		}
		refresh = refresh === true;
	}

	parentNode = parentNode
		? ("" + parentNode === parentNode
			? $(parentNode)[0]  // It is a string, so treat as selector
			: parentNode.jquery
				? parentNode[0] // A jQuery object - take first element.
				: parentNode)
		: (self.parentElem      // view.link()
			|| document.body);  // link(null, data) to link the whole document

	validate = !$subSettingsAdvanced.noValidate && parentNode.contentEditable !== TRUE;
	parentTag = parentNode.tagName.toLowerCase();
	elCnt = !!elContent[parentTag];

	prevNode = prevNode && markPrevOrNextNode(prevNode, elCnt);
	nextNode = nextNode && markPrevOrNextNode(nextNode, elCnt) || null;

	if (html != undefined) {
		//================ Insert html into DOM using documentFragments (and wrapping HTML appropriately). ================
		// Also convert markers to DOM annotations, based on content model.
		// Corresponds to nextNode ? $(nextNode).before(html) : $(parentNode).html(html);
		// but allows insertion to wrap correctly even with inserted script nodes. jQuery version will fail e.g. under tbody or select.
		// This version should also be slightly faster
		div = document.createElement("div");
		wrapper = div;
		prevIds = ids = "";
		htmlTag = parentNode.namespaceURI === "http://www.w3.org/2000/svg" ? "svg_ns" : (firstTag = rFirstElem.exec(html)) && firstTag[1] || "";
		if (elCnt) {
			// Now look for following view, and find its tokens, or if not found, get the parentNode._df tokens
			node = nextNode;
			while (node && !(nextView = viewInfos(node))) {
				node = node.nextSibling;
			}
			if (tokens = nextView ? nextView._tkns : parentNode._df) {
				token = prevView || "";
				if (refresh || !prevView) {
					token += "#" + thisId;
				}
				j = tokens.indexOf(token);
				if (j + 1) {
					j += token.length;
					// Transfer the initial tokens to inserted nodes, by setting them as the ids variable, picked up in convertMarkers
					prevIds = ids = tokens.slice(0, j);
					tokens = tokens.slice(j);
					if (nextView) {
						node.setAttribute(jsvAttrStr, tokens);
					} else {
						setDefer(parentNode, tokens);
					}
				}
			}
		}

		//================ Convert the markers to DOM annotations, based on content model. ================
//			oldElCnt = elCnt;
		isVoid = undefined;
		html = ("" + html).replace(rConvertMarkers, convertMarkers);
//			if (!!oldElCnt !== !!elCnt) {
//				error("Parse: " + html); // Parse error. Content not well-formed?
//			}
		if (validate && tagStack.length) {
			syntaxError("Mismatched '<" + parentTag + "...>' in:\n" + html); // Unmatched tag
		}
		if (validateOnly) {
			return;
		}
		// Append wrapper element to doc fragment
		safeFragment.appendChild(div);

		// Go to html and back, then peel off extra wrappers
		// Corresponds to jQuery $(nextNode).before(html) or $(parentNode).html(html);
		// but supports svg elements, and other features missing from jQuery version (and this version should also be slightly faster)
		htmlTag = wrapMap[htmlTag] || wrapMap.div;
		depth = htmlTag[0];
		wrapper.innerHTML = htmlTag[1] + html + htmlTag[2];
		while (depth--) {
			wrapper = wrapper.lastChild;
		}
		safeFragment.removeChild(div);
		fragment = document.createDocumentFragment();
		while (copiedNode = wrapper.firstChild) {
			fragment.appendChild(copiedNode);
		}
		// Insert into the DOM
		parentNode.insertBefore(fragment, nextNode);
	}

	if (lazyLink) {
		setTimeout(dataLink, 0);
	} else {
		dataLink();
	}

	return lazyLink && lazyLink.promise();
}

function addDataBinding(linkMarkup, node, currentView, boundTagId, isLink, data, context) {
	// Add data binding for data-linked elements or {^{...}} data-linked tags
	var tmpl, tokens, attr, convertBack, tagExpr, linkFn, linkCtx, tag, rTagIndex, hasElse, lastIndex,
		linkExpressions = [];

	if (boundTagId) {
		// boundTagId is a string for {^{...}} data-linked tag. So only one linkTag in linkMarkup
		// data and context parameters are undefined
		tag = bindingStore[boundTagId];
		tag = tag.linkCtx ? tag.linkCtx.tag : tag;

		linkCtx = tag.linkCtx || {
			type: "inline",
			data: currentView.data,                   // source
			elem: tag._elCnt ? tag.parentElem : node, // target
			view: currentView,
			ctx: currentView.ctx,
			attr: HTML, // Script marker nodes are associated with {^{ and always target HTML.
			fn: tag._.bnd,
			tag: tag,
			// Pass the boundTagId in the linkCtx, so that it can be picked up in observeAndBind
			_bndId: boundTagId
		};
		bindDataLinkTarget(linkCtx, linkCtx.fn);
	} else if (linkMarkup && node) {
		// If isLink then this is a top-level linking: .link(expression, target, data, ....) or
		// .link(true, target, data, ....) scenario - and data and context are passed in separately from the view
		data = isLink ? data : currentView.data;

		// Compiled linkFn expressions could be stored in the tmpl.links array of the template
		// TODO - consider also caching globally so that if {{:foo}} or data-link="foo" occurs in different places,
		// the compiled template for this is cached and only compiled once...
		//links = currentView.links || currentView.tmpl.links;

		tmpl = currentView.tmpl;

//			if (!(linkTags = links[linkMarkup])) {
		// This is the first time this view template has been linked, so we compile the data-link expressions, and store them on the template.

		linkMarkup = normalizeLinkTag(linkMarkup, defaultAttr(node));
		lastIndex = rTagDatalink.lastIndex = 0;
		while (tokens = rTagDatalink.exec(linkMarkup)) { // TODO require } to be followed by whitespace or $, and remove the \}(!\}) option.
			linkExpressions.push(tokens);
			lastIndex = rTagDatalink.lastIndex;
		}
		if (lastIndex < linkMarkup.length) {
			syntaxError(linkMarkup);
		}
		while (tokens = linkExpressions.shift()) {
			// Iterate over the data-link expressions, for different target attrs,
			// e.g. <input data-link="{:firstName:} title{>~description(firstName, lastName)}"
			// tokens: [all, attr, bindOnly, tagExpr, tagName, converter, colon, html, comment, code, params]
			rTagIndex = rTagDatalink.lastIndex;
			attr = tokens[1];
			tagExpr = tokens[3];
			while (linkExpressions[0] && linkExpressions[0][4] === "else") { // If this is {someTag...} and is followed by an {else...} add to tagExpr
				tagExpr += delimCloseChar1 + delimOpenChar0 + linkExpressions.shift()[3];
				hasElse = true;
			}
			if (hasElse) { // If an {else} has been added, need also to add closing {{/someTag}}
				tagExpr += delimCloseChar1 + delimOpenChar0 + delimOpenChar1 + "/" + tokens[4] + delimCloseChar0;
			}
			linkCtx = {
				type: isLink ? "top" : "link",
				data: data, // source
				elem: node, // target
				view: currentView,
				ctx: context,
				attr: attr,
				isLk: isLink, // top-level linking?
				_toLk : 1, // Flag to data-link on initial data-link call rendering call
				_noUpd : tokens[2] // Flag for data-link="^{...}" so on initial data-link call will bind, but not render)
			};

			convertBack = undefined;
			if (tokens[6]) {
				convertBack = tokens[10] || undefined;
				linkCtx.convert = tokens[5] || "";
				if (!attr && convertBack !== undefined && defaultAttr(node)) {
					// Default target, so allow 2 way binding
					linkCtx.convertBack = convertBack = convertBack.slice(1);
				}
			}
			// Compile the linkFn expression which evaluates and binds a data-link expression
			// TODO - optimize for the case of simple data path with no conversion, helpers, etc.:
			//     i.e. data-link="a.b.c". Avoid creating new instances of Function every time. Can use a default function for all of these...

			linkCtx.expr = attr + tagExpr;
			linkFn = tmpl.links[tagExpr];
			if (!linkFn) {
				tmpl.links[tagExpr] = linkFn = $sub.tmplFn(tagExpr, tmpl, true, convertBack, hasElse);
			}
			linkCtx.fn = linkFn;
			bindDataLinkTarget(linkCtx, linkFn);
			// We store rTagIndex in local scope, since this addDataBinding method can sometimes be called recursively,
			// and each is using the same rTagDatalink instance.
			rTagDatalink.lastIndex = rTagIndex;
		}
//		}
	}
}

function bindDataLinkTarget(linkCtx, linkFn) {
	// Add data link bindings for a link expression in data-link attribute markup
	function handler(ev, eventArgs) {
		propertyChangeHandler.call(linkCtx, ev, eventArgs, linkFn);
		// If the link expression uses a custom tag, the propertyChangeHandler call will call renderTag, which will set tagCtx on linkCtx
	}
	handler.noArray = true;
	if (linkCtx.isLk) {
		// Top-level linking: .link(expressionOrTrue, data, context) - so we need to create a view for the linking, with the data and ctx
		// which may be different than the current context of the target. Note that this view is not a standard data-linked view, so it will
		// be disposed only when its parent view is disposed.
		addLinkMethods(linkCtx.view = new $sub.View(
			$sub.extendCtx(linkCtx.ctx, linkCtx.view.ctx),
			"link", linkCtx.view, linkCtx.data, linkCtx.expr, undefined, addBindingMarkers));
	}
	linkCtx._ctxCb = $sub._gccb(linkCtx.view); // getContextCallback: _ctxCb, for filtering/appending to dependency paths: function(path, object) { return [(object|path)*]}
	linkCtx._hdl = handler;
	// handler._ctx = linkCtx; Could pass linkCtx for use in a depends = function() {} call, so depends is different for different linkCtx's
	handler(true);
}

//=====================
// Data-linking helpers
//=====================

function removeSubStr(str, substr) {
	var k;
	return str
		? (k = str.indexOf(substr),
			(k + 1
				? str.slice(0, k) + str.slice(k + substr.length)
				: str))
		: "";
}

function markerNodeInfo(node) {
	return node &&
		("" + node === node
			? node
			: node.tagName === SCRIPT
				? node.type.slice(3)
				: node.nodeType === 1 && node.getAttribute(jsvAttrStr) || "");
}

function viewInfos(node, isVal, rBinding) {
	// Test whether node is a script marker node, and if so, return metadata
	function getInfos(all, open, close, id, ch, elPath) {
		infos.push({
			elCnt: elCnt,
			id: id,
			ch: ch,
			open: open,
			close: close,
			path: elPath,
			token: all
		});
	}
	var elCnt, tokens,
		infos = [];
	if (tokens = isVal ? node : markerNodeInfo(node)) {
		elCnt = infos.elCnt = node.tagName !== SCRIPT;
		elCnt = tokens.charAt(0) === "@" || elCnt;
		infos._tkns = tokens;
		// rMarkerTokens = /(?:(#)|(\/))(\d+)([_^])([-+@\d]+)?/g;
		tokens.replace(rBinding || rMarkerTokens, getInfos);
		return infos;
	}
}

function unmarkPrevOrNextNode(node, elCnt) {
	if (node) {
		if (node.type === "jsv") {
			node.parentNode.removeChild(node);
		} else if (elCnt && node.getAttribute($viewsLinkAttr) === "") {
			node.removeAttribute($viewsLinkAttr);
		}
	}
}

function markPrevOrNextNode(node, elCnt) {
	var marker = node;
	while (elCnt && marker && marker.nodeType !== 1) {
		marker = marker.previousSibling;
	}
	if (marker) {
		if (marker.nodeType !== 1) {
			// For text nodes, we will add a script node before
			marker = document.createElement(SCRIPT);
			marker.type = "jsv";
			node.parentNode.insertBefore(marker, node);
		} else if (!markerNodeInfo(marker) && !marker.getAttribute($viewsLinkAttr)) {
			// For element nodes, we will add a data-link attribute (unless there is already one)
			// so that this node gets included in the node linking process.
			marker.setAttribute($viewsLinkAttr, "");
		}
	}
	return marker;
}

function normalizeLinkTag(linkMarkup, twoway) {
	linkMarkup = $.trim(linkMarkup).replace(rEscapeQuotes, "\\$&");
	return linkMarkup.slice(-1) !== delimCloseChar0
	// If simplified syntax is used: data-link="expression", convert to data-link="{:expression}",
	// or for inputs, data-link="{:expression:}" for (default) two-way binding
		? linkMarkup = delimOpenChar1 + ":" + linkMarkup + (twoway ? ":" : "") + delimCloseChar0
		: linkMarkup;
}

//===========================
// Methods for views and tags
//===========================

function callAfterLink(tag, ev, eventArgs) {
	var linkedElem, displayElem, linkedEl, val, l, linkedTag, oldTrig, newTrig, tagProps, propsExpr, linkedElemView, prop, propDef,
		tagCtx = tag.tagCtx,
		view = tagCtx.view,
		props = tagCtx.props,
		linkCtx = tag.linkCtx;

	if (tag._.unlinked) { // First call to onAfterLink, or first call after onUpdate: updateContent. Initialize and call onBind and set properties
		if (tag.linkedElement !== undefined) {
			// linkedElement: - selector for identifying linked element in template/rendered content
			tag.linkedElem = tag._.inline ? tag.contents(true, tag.linkedElement || "*").first() : $(linkCtx.elem);
		}
		if (tag.onBind) {
			tag.onBind(tagCtx, linkCtx, tag.ctx, ev, eventArgs);
		}
	}

	if (tag.onAfterLink) {
		tag.onAfterLink(tagCtx, linkCtx, tag.ctx, ev, eventArgs);
	}

	linkedElem = tag.targetTag ? tag.targetTag.linkedElem : tag.linkedElem;
	displayElem = tag.displayElem || linkedElem;

	if (linkedElem && linkedElem[0]) {
		val = tag.cvtArgs()[0];
		if (val !== undefined && !tag._.chging) {
			l = linkedElem.length;
			while (l--) {
				linkedEl = linkedElem[l];
				if (tag._.unlinked && linkedEl !== linkCtx.elem) {
					linkedTag = linkedEl._jsvLkEl;
					if (tag._.inline && (!linkedTag || linkedTag !== tag && linkedTag.targetTag !== tag)) {
						// For data-linked tags, identify the linkedEl with the tag, for "to" binding
						// (For data-linked elements, if not yet bound, we identify later when the linkCtx.elem is bound)
						linkedEl._jsvLkEl = tag;
						bindTo(bindingStore[tag._tgId], tag, linkedEl);
						linkedEl._jsvBnd = "&" + tag._tgId + "+"; // Add a "+" for cloned binding - so removing
						// elems with cloned bindings will not remove the 'parent' binding from the bindingStore.
					}
				}
				if (val !== undefined) {
					if (linkedEl.value !== undefined) {
						if (linkedEl.type === CHECKBOX) {
							linkedEl[CHECKED] = val && val !== "false";
						} else if (linkedEl.type === RADIO) {
							linkedEl[CHECKED] = (linkedEl.value === val);
						} else {
							$(linkedEl).val(val); // Use jQuery for attrHooks - can't just set value (on select, for example)
						}
					} else if (linkedEl.contentEditable === TRUE) {
						linkedEl.innerHTML = val;
					}
					linkCtx._val = val;
				}
				if (props.name) {
					linkedEl.name = linkedEl.name || props.name;
				}
			}
		}
		if (tag.setSize) {
			if (props.height) {
				displayElem.height(props.height);
			}
			if (props.width) {
				displayElem.width(props.width);
			}
		}
		if (props.title !== undefined) {
			displayElem.attr("title", props.title);
		}
		if (props["class"]) {
			// This code supports dynamic binding to class - where it adds the class if absent, and removes/adds if a previous value is present
			if (eventArgs && displayElem.hasClass(eventArgs.oldValue)) {
				displayElem.removeClass(eventArgs.oldValue);
			}
			displayElem.addClass(props["class"]);
		}
		if (props.id) {
			linkedElem[0].id = props.id;
		}
	}
	tag._.unlinked = undefined;
}

function asyncElemChangeHandler(ev) {
	setTimeout(function() {
		elemChangeHandler(ev);
	}, 0);
}

function bindElChange($elem, trig, onoff) {
	if (trig) {
		trig = "" + trig === trig ? trig : "keydown"; // Set trigger to (true || truey non-string (e.g. 1) || 'keydown'): Get 'keydown' with async
		$elem[onoff](trig, trig === "keydown" ? asyncElemChangeHandler : elemChangeHandler);
	}
}

function bindTo(binding, tag, linkedElem, cvtBk) {
	// Two-way binding.
	// We set the binding.to[1] to be the cvtBack, and binding.to[0] to be either the path to the target, or [object, path] where the target is the path on the provided object.
	// So for a computed path with an object call: a.b.getObject().d.e, then we set to[0] to be [exprOb, "d.e"], and we bind to the path on the returned object, exprOb.ob, as target
	// Otherwise our target is the first path, paths[0], which we will convert with contextCb() for paths like ~a.b.c or #x.y.z

	var bindto, pathIndex, path, lastPath, bindtoOb, $linkedElem, newTrig, oldTrig, to, l,
		linkCtx = binding.linkCtx,
		contextCb = linkCtx._ctxCb,
		source = linkCtx.data,
		paths = linkCtx.fn.paths[0];

	tag = tag || linkedElem._jsvLkEl;

	if (binding && paths && !binding.to) {
		oldTrig = linkedElem._jsvTr || false;
		if (tag) {
			cvtBk = tag.convertBack || cvtBk;
			newTrig = tag.tagCtx.props.trigger;
		}
		newTrig = newTrig === undefined ? $subSettings.trigger : newTrig;
		// Trigger is noop except for text box, textarea, contenteditable...
		newTrig = newTrig && (linkedElem.tagName === "INPUT" && linkedElem.type !== CHECKBOX && linkedElem.type !== RADIO || linkedElem.type === "textarea" || linkedElem.contentEditable === TRUE) && newTrig || false;

		if (oldTrig !== newTrig) {
			$linkedElem = $(linkedElem);
			bindElChange($linkedElem, oldTrig, "off");
			bindElChange(
				$linkedElem,
				linkedElem._jsvTr = newTrig,
				"on"
			);
		}

		paths = (bindto = paths._jsvto) || paths[0];
		if (pathIndex = paths && paths.length) {
			lastPath = paths[pathIndex - 1];
			if (lastPath._jsv) {
				bindtoOb = lastPath;
				while (lastPath.sb && lastPath.sb._jsv) {
					path = lastPath = lastPath.sb;
				}
				path = lastPath.sb || path && path.path;
				lastPath = path ? path.slice(1) : bindtoOb.path;
			}
			if (path) {
				to = [
						bindtoOb, // 'exprOb' for this expression and view-binding. So bindtoOb.ob is current object returned by expression.
						lastPath
					];
			} else {
				while ((to = contextCb(path = lastPath.split("^").join("."), source)) && (l = to.length)) {
					// Recursively dereference any ~foo or #bar tokens in the path. (Recursive because ~foo may be a contextual param which has
					// its own dependencies on other ~foo #bar components)
					if (to[0]._cp) { // Two-way binding to a contextual parameter reference, ~foo (declared as ~foo=expr on a parent tag)
						to = to[0];    // so 'to' is the [view, expression/dependencies] for the contextual parameter
						contextCb = $sub._gccb(to[0]); // getContextCallback: Move contextCb up to view where contextual parameter was assigned
						lastPath = to[1];
						to = [to[0].data, to[1]];
						if (lastPath._jsv) { // computed value
							bindtoOb = lastPath;
							bindtoOb.data = to[0];
							bindtoOb._cpCtx = contextCb;
							while (lastPath.sb && lastPath.sb._jsv) {
								path = lastPath = lastPath.sb;
							}
							path = lastPath.sb || path && path.path;
							lastPath = path ? path.slice(1) : bindtoOb.path;
							to = [
								bindtoOb, // 'exprOb' for this expression and view-binding. So bindtoOb.ob is current object returned by expression.
								lastPath
							];
						}
					} else { // Two-way binding to a helper - e.g. ~address.street, or computed, e.g. ~fullName(), or view property e.g. #data.foo
						to = l>2
							? [to[l-3], to[l-2]] // With path: [object, path]
							: [to[l-2]];         // No path, (e.g. [function] for computed with setter)
					}
					source = to[0];
					lastPath = to[1];
				}
				to = to || [source, path]; // Two way binding to an object (neither ~foo nor #bar)
			}
		} else {
			to = [];
		}
		binding.to = [
			to,
			cvtBk
		];
	}
}

function mergeCtxs(tag, newCtxs, replace) { // Merge updated tagCtxs into tag.tagCtxs
	var tagCtx, newTagCtx,
		view = tag.tagCtx.view,
		tagCtxs = tag.tagCtxs || [tag.tagCtx],
		l = tagCtxs.length,
		refresh = !newCtxs;

	newCtxs = newCtxs || tag._.bnd.call(view.tmpl, (tag.linkCtx || view).data, view, $sub);

	if (replace) {
		// Replace previous tagCtxs by new ones, rather than merging
		tagCtxs = tag.tagCtxs = newCtxs;
		tag.tagCtx = tagCtxs[0];
	} else {
		while (l--) {
			tagCtx = tagCtxs[l];
			newTagCtx = newCtxs[l];
			$observable(tagCtx.props).setProperty(newTagCtx.props);
			$extend(tagCtx.ctx, newTagCtx.ctx); // We don't support propagating ctx variables, ~foo, observably, to nested views. So extend, not setProperty...
			tagCtx.args = newTagCtx.args;
			if (refresh) {
				tagCtx.tmpl = newTagCtx.tmpl;
			}
		}
	}
	$sub._ths(tag, tagCtxs[0]); // tagHandlersFromProps
	return tagCtxs;
}

//=========
// Disposal
//=========

function clean(elems) {
	// Remove data-link bindings, or contained views
	var l, elem, bindings,
		elemArray = [],
		len = elems.length,
		i = len;
	while (i--) {
		// Copy into an array, so that deletion of nodes from DOM will not cause our 'i' counter to get shifted
		// (Note: This seems as fast or faster than elemArray = [].slice.call(elems); ...)
		elemArray.push(elems[i]);
	}
	i = len;
	while (i--) {
		elem = elemArray[i];
		if (elem.parentNode) {
			// Has not already been removed from the DOM
			if (bindings = elem._jsvBnd) {
				// Get propertyChange bindings for this element
				// This may be an element with data-link, or the opening script marker node for a data-linked tag {^{...}}
				// bindings is a string with the syntax: "(&bindingId)*"
				bindings = bindings.slice(1).split("&");
				elem._jsvBnd = "";
				l = bindings.length;
				while (l--) {
					// Remove associated bindings
					removeViewBinding(bindings[l], elem._jsvLkEl, elem); // unbind bindings with this bindingId on this view
				}
			}
			disposeTokens(markerNodeInfo(elem) + (elem._df || ""));
		}
	}
}

function removeViewBinding(bindId, linkedElemTag, elem) {
	// Unbind
	var objId, linkCtx, tag, object, obsId, tagCtxs, l, map, $linkedElem, linkedElem, trigger, view, targetTag,
		binding = bindingStore[bindId];

	if (linkedElemTag) {
		linkedElemTag = linkedElemTag.targetTag || linkedElemTag;
		elem._jsvLkEl = undefined;
	} else if (binding) {
		delete bindingStore[bindId]; // Delete already, so call to onDispose handler below cannot trigger recursive deletion (through recursive call to jQuery cleanData)
		for (objId in binding.bnd) {
			object = binding.bnd[objId];
			obsId = binding.cbId;
			if ($isArray(object)) {
				$([object]).off(arrayChangeStr + obsId).off(propertyChangeStr + obsId); // There may be either or both of arrayChange and propertyChange
			} else {
				$(object).off(propertyChangeStr + obsId);
			}
			delete binding.bnd[objId];
		}

		if (linkCtx = binding.linkCtx) {
			if (tag = linkCtx.tag) {
				if (tagCtxs = tag.tagCtxs) {
					l = tagCtxs.length;
					while (l--) {
						if (map = tagCtxs[l].map) {
							map.unmap(); //unobserve
						}
					}
				}
				$linkedElem = tag.linkedElem;

				if (tag.onUnbind) {
					tag.onUnbind(tag.tagCtx, linkCtx, tag.ctx, true);
				}
				if (tag.onDispose) {
					tag.onDispose();
				}

				if (!tag._elCnt) {
					if (tag._prv) {
						tag._prv.parentNode.removeChild(tag._prv);
					}
					if (tag._nxt) {
						tag._nxt.parentNode.removeChild(tag._nxt);
					}
				}
			}
			linkedElem = $linkedElem && $linkedElem[0] || linkCtx.elem;

			if (trigger = linkedElem && linkedElem._jsvTr) {
				bindElChange($linkedElem || $(linkedElem), trigger, "off");
				linkedElem._jsvTr = undefined;
			}
			view = linkCtx.view;
			if (view.type === "link") {
				view.parent.removeViews(view._.key, undefined, true); // A "link" view is associated with the binding, so should be disposed with binding.
			} else {
				delete view._.bnds[bindId];
			}
		}
		delete binding.s[binding.cbId];
	}
}

function $unlink(to) {
	if (to) {
		to = to.jquery ? to : $(to);
		to.each(function() {
			var innerView;
			//TODO fix this for better perf. Rather that calling inner view multiple times which does querySelectorAll each time, consider a single querySelectorAll
			// or simply call view.removeViews() on the top-level views under the target 'to' node, then clean(...)
			while ((innerView = $view(this, true)) && innerView.parent) {
				innerView.parent.removeViews(innerView._.key, undefined, true);
			}
			clean(this.getElementsByTagName("*"));
		});
		clean(to);
	} else {
		// Call to $.unlink() is equivalent to $.unlink(true, "body")
		if (activeBody) {
			$(activeBody)
				.off(elementChangeStr, elemChangeHandler)
				.off('blur', '[contenteditable]', elemChangeHandler);
			activeBody = undefined;
		}
		topView.removeViews();
		clean(document.body.getElementsByTagName("*"));
	}
}

//========
// Helpers
//========

function inputAttrib(elem) {
	return elem.type === CHECKBOX ? elem[CHECKED] : elem.value;
}

//========================== Initialize ==========================

//=====================
// JsRender integration
//=====================

$sub.onStore.template = function(name, item) {
	item.link = tmplLink;
	if (name) {
		$.link[name] = function() {
			return tmplLink.apply(item, arguments);
		};
	}
};

$sub.viewInfos = viewInfos; // Expose viewInfos() as public helper method

// Define JsViews version of delimiters(), and initialize
($viewsSettings.delimiters = function() {
	// Run delimiters initialization in context of jsrender.js
	var ret = oldJsvDelimiters.apply(0, arguments),
		// Now set also delimOpenChar0 etc. in context of jquery.views.js...
		delimChars = $subSettings.delimiters;

	delimOpenChar0 = delimChars[0].charAt(0);
	delimOpenChar1 = delimChars[0].charAt(1);
	delimCloseChar0 = delimChars[1].charAt(0);
	delimCloseChar1 = delimChars[1].charAt(1);
	linkChar = delimChars[2];

	// Data-linking must use new delimiters
	rTagDatalink = new RegExp("(?:^|\\s*)([\\w-]*)(\\" + linkChar + ")?(\\" + delimOpenChar1 + $sub.rTag + "(:\\w*)?\\" + delimCloseChar0 + ")", "g");
	return ret;
})(); // jshint ignore:line

$sub.addSetting("trigger");

//====================================
// Additional members for linked views
//====================================

function transferViewTokens(prevNode, nextNode, parentElem, id, viewOrTagChar, refresh) {
	// Transfer tokens on prevNode of viewToRemove/viewToRefresh to nextNode or parentElem._df
	var i, l, vwInfos, vwInfo, viewOrTag, viewId, tokens,
		precedingLength = 0,
		emptyView = prevNode === nextNode;

	if (prevNode) {
		// prevNode is either the first node in the viewOrTag, or has been replaced by the vwInfos tokens string
		vwInfos = viewInfos(prevNode) || [];
		for (i = 0, l = vwInfos.length; i < l; i++) {
			// Step through views or tags on the prevNode
			vwInfo = vwInfos[i];
			viewId = vwInfo.id;
			if (viewId === id && vwInfo.ch === viewOrTagChar) {
				if (refresh) {
					// This is viewOrTagToRefresh, this is the last viewOrTag to process...
					l = 0;
				} else {
					// This is viewOrTagToRemove, so we are done...
					break;
				}
			}
			if (!emptyView) {
				viewOrTag = vwInfo.ch === "_"
					? viewStore[viewId]
					: bindingStore[viewId].linkCtx.tag;
				if (vwInfo.open) {
					// A "#m" token
					viewOrTag._prv = nextNode;
				} else if (vwInfo.close) {
					// A "/m" token
					viewOrTag._nxt = nextNode;
				}
			}
			precedingLength += viewId.length + 2;
		}

		if (precedingLength) {
			prevNode.setAttribute(jsvAttrStr, prevNode.getAttribute(jsvAttrStr).slice(precedingLength));
		}
		tokens = nextNode ? nextNode.getAttribute(jsvAttrStr) : parentElem._df;
		if (l = tokens.indexOf("/" + id + viewOrTagChar) + 1) {
			tokens = vwInfos._tkns.slice(0, precedingLength) + tokens.slice(l + (refresh ? -1 : id.length + 1));
		}
		if (tokens) {
			if (nextNode) {
				// If viewOrTagToRemove was an empty viewOrTag, we will remove both #n and /n
				// (and any intervening tokens) from the nextNode (=== prevNode)
				// If viewOrTagToRemove was not empty, we will take tokens preceding #n from prevNode,
				// and concatenate with tokens following /n on nextNode
				nextNode.setAttribute(jsvAttrStr, tokens);
			} else {
				setDefer(parentElem, tokens);
			}
		}
	} else {
		// !prevNode, so there may be a deferred nodes token on the parentElem. Remove it.
		setDefer(parentElem, removeSubStr(parentElem._df, "#" + id + viewOrTagChar));
		if (!refresh && !nextNode) {
			// If this viewOrTag is being removed, and there was no .nxt, remove closing token from deferred tokens
			setDefer(parentElem, removeSubStr(parentElem._df, "/" + id + viewOrTagChar));
		}
	}
}

function disposeTokens(tokens) {
	var i, l, vwItem, vwInfos;
	if (vwInfos = viewInfos(tokens, true, rOpenMarkers)) {
		for (i = 0, l = vwInfos.length; i < l; i++) {
			vwItem = vwInfos[i];
			if (vwItem.ch === "_") {
				if ((vwItem = viewStore[vwItem.id]) && vwItem.type) {
					// If this is the _prv (prevNode) for a view, remove the view
					// - unless view.type is undefined, in which case it is already being removed
					vwItem.parent.removeViews(vwItem._.key, undefined, true);
				}
			} else {
				removeViewBinding(vwItem.id); // unbind bindings with this bindingId on this view
			}
		}
	}
}

//====================================
// Add link methods to data-linked view or tag
//====================================
function addLinkMethods(tagOrView, isTag) {

	tagOrView.contents = function(deep, select) {
		// For a view or a tag, return jQuery object with the content nodes,
		if (deep !== !!deep) {
			// deep not boolean, so this is contents(selector)
			select = deep;
			deep = undefined;
		}
		var filtered,
			nodes = $(this.nodes());
		if (nodes[0]) {
			filtered = select ? nodes.filter(select) : nodes;
			nodes = deep && select ? filtered.add(nodes.find(select)) : filtered;
		}
		return nodes;
	};

	tagOrView.nodes = function(withMarkers, prevNode, nextNode) {
		// For a view or a tag, return top-level nodes
		// Do not return any script marker nodes, unless withMarkers is true
		// Optionally limit range, by passing in prevNode or nextNode parameters

		var node,
			self = this,
			elCnt = self._elCnt,
			prevIsFirstNode = !prevNode && elCnt,
			nodes = [];

		prevNode = prevNode || self._prv;
		nextNode = nextNode || self._nxt;

		node = prevIsFirstNode
			? (prevNode === self._nxt
				? self.parentElem.lastSibling
				: prevNode)
			: (self._.inline === false
				? prevNode || self.linkCtx.elem.firstChild
				: prevNode && prevNode.nextSibling);

		while (node && (!nextNode || node !== nextNode)) {
			if (withMarkers || elCnt || node.tagName !== SCRIPT) {
				// All the top-level nodes in the view
				// (except script marker nodes, unless withMarkers = true)
				// (Note: If a script marker node, viewInfo.elCnt undefined)
				nodes.push(node);
			}
			node = node.nextSibling;
		}
		return nodes;
	};

	tagOrView.childTags = function(deep, tagName) {
		// For a view or a tag, return child tags - at any depth, or as immediate children only.
		if (deep !== !!deep) {
			// deep not boolean, so this is childTags(tagName) - which looks for top-level tags of given tagName
			tagName = deep;
			deep = undefined;
		}

		var self = this,
			view = self.link ? self : self.tagCtx.view, // this may be a view or a tag. If a tag, get the view from tag.view.tagCtx
			prevNode = self._prv,
			elCnt = self._elCnt,
			tags = [];

		view.link(
			undefined,
			self.parentElem,
			elCnt ? prevNode && prevNode.previousSibling : prevNode,
			self._nxt,
			undefined,
			{get:{
				tags: tags,
				deep: deep,
				name: tagName,
				id: self.link ? self._.id + "_" : self._tgId + "^"
			}}
		);
		return tags;
	};

	tagOrView.refresh = function(sourceValue) {
		var promise, attr,
			tag = this,
			linkCtx = tag.linkCtx,
			view = tag.tagCtx.view;

		if (tag.disposed) { error("Removed tag"); }
		if (sourceValue === undefined) {
			sourceValue = $sub._tag(tag, view, view.tmpl, mergeCtxs(tag), true); // Get rendered HTML for tag, based on refreshed tagCtxs
		}
		if (sourceValue + "" === sourceValue) {
			// If no rendered content, sourceValue will not be a string (can be 0 or undefined)
			if (tag.onUnbind) {
				tag.onUnbind(tag.tagCtx, linkCtx, tag.ctx);
			}
			attr = tag._.inline ? HTML : (linkCtx.attr || defaultAttr(tag.parentElem, true));
			promise = updateContent(sourceValue, linkCtx, attr, tag);
		}

		callAfterLink(tag);
		return promise || tag;
	};

	tagOrView.update = function(value) {
		var linkedElem = this.linkedElem;
		if (linkedElem) {
			elemChangeHandler({
				target: linkedElem[0]
			}, undefined, value);
		}
	};

	if (isTag) {
		// This is a TAG
		tagOrView.domChange = function() { // domChange notification support
			var elem = this.parentElem,
				hasListener = $.hasData(elem) && $._data(elem).events,
				domChangeNotification = "jsv-domchange";

			if (hasListener && hasListener[domChangeNotification]) {
				// Only trigger handler if there is a handler listening for this event. (Note using triggerHandler - so no event bubbling.)
				$(elem).triggerHandler(domChangeNotification, arguments);
			}
		};
	} else {
		// This is a VIEW
		// Note: a linked view will also, after linking have nodes[], _prv (prevNode), _nxt (nextNode) ...
		tagOrView.addViews = function(index, dataItems) {
			// if view is not an array view, do nothing
			var i, viewsCount,
				self = this,
				itemsCount = dataItems.length,
				views = self.views;

			if (!self._.useKey && itemsCount) {
				// view is of type "array"
				viewsCount = views.length + itemsCount;

				if (viewsCount === self.data.length // If views not already synced to array (e.g. triggered by array.length propertyChange - jsviews/issues/301)
						&& renderAndLink(self, index, self.tmpl, views, dataItems, self.ctx) !== false) {
					if (!self._.srt) { // Not part of a 'sort' on refresh
						self.fixIndex(index + itemsCount);
					}
				}
			}
		};

		tagOrView.removeViews = function(index, itemsCount, keepNodes, isMove) {
			// view.removeViews() removes all the child views
			// view.removeViews(index) removes the child view with specified index or key
			// view.removeViews(index, count) removes the specified nummber of child views, starting with the specified index
			function removeView(index) {
				var id, bindId, parentElem, prevNode, nextNode, nodesToRemove,
					viewToRemove = views[index];

				if (viewToRemove && viewToRemove.link) {
					id = viewToRemove._.id;
					if (!keepNodes) {
						// Remove the HTML nodes from the DOM, unless they have already been removed, including nodes of child views
						nodesToRemove = viewToRemove.nodes();
					}

					// Remove child views, without removing nodes
					viewToRemove.removeViews(undefined, undefined, true);

					viewToRemove.type = undefined; // Set type to undefined: used as a flag that this view is being removed
					prevNode = viewToRemove._prv;
					nextNode = viewToRemove._nxt;
					parentElem = viewToRemove.parentElem;
					// If prevNode and nextNode are the same, the view is empty
					if (!keepNodes) {
						// Remove the HTML nodes from the DOM, unless they have already been removed, including nodes of child views
						if (viewToRemove._elCnt) {
							// if keepNodes is false (and transferring of tokens has not already been done at a higher level)
							// then transfer tokens from prevNode which is being removed, to nextNode.
							transferViewTokens(prevNode, nextNode, parentElem, id, "_");
						}
						$(nodesToRemove).remove();
					}
					if (!viewToRemove._elCnt) {
						try {
							prevNode.parentNode.removeChild(prevNode); // (prevNode.parentNode is parentElem, except if jQuery Mobile or similar has inserted an intermediate wrapper
							nextNode.parentNode.removeChild(nextNode);
						} catch (e) {}
					}
					setArrayChangeLink(viewToRemove);
					for (bindId in viewToRemove._.bnds) {
						removeViewBinding(bindId);
					}
					delete viewStore[id];
				}
			}

			var current, view, viewsCount,
				self = this,
				isArray = !self._.useKey,
				views = self.views;

			if (isArray) {
				viewsCount = views.length;
			}
			if (index === undefined) {
				// Remove all child views
				if (isArray) {
					// views and data are arrays
					current = viewsCount;
					while (current--) {
						removeView(current);
					}
					self.views = [];
				} else {
					// views and data are objects
					for (view in views) {
						// Remove by key
						removeView(view);
					}
					self.views = {};
				}
			} else {
				if (itemsCount === undefined) {
					if (isArray) {
						// The parentView is data array view.
						// Set itemsCount to 1, to remove this item
						itemsCount = 1;
					} else {
						// Remove child view with key 'index'
						removeView(index);
						delete views[index];
					}
				}
				if (isArray && itemsCount
					&& (isMove || viewsCount - itemsCount === self.data.length)) { // If views not already synced to array (e.g. triggered by array.length propertyChange - jsviews/issues/301)
					current = index + itemsCount;
					// Remove indexed items (parentView is data array view);
					while (current-- > index) {
						removeView(current);
					}
					views.splice(index, itemsCount);
					if (!self._.sort) {
						self.fixIndex(index);
					}
				}
			}
		};

		tagOrView.refresh = function() {
			var self = this,
				parent = self.parent;

			if (parent) {
				renderAndLink(self, self.index, self.tmpl, parent.views, self.data, undefined, true);
				setArrayChangeLink(self);
			}
		};

		tagOrView.fixIndex = function(fromIndex) {
			// Fixup index on following view items...
			var views = this.views,
				index = views.length;
			while (fromIndex < index--) {
				if (views[index].index !== index) {
					$observable(views[index]).setProperty("index", index);
					// This is fixing up index, but not key, and not index on child views. From child views, use view.getIndex()
				}
			}
		};

		tagOrView.link = viewLink;
	}
}

//========================
// JsViews-specific converters
//========================

$converters.merge = function(val) {
	// Special converter used in data-linking to space-separated lists, such as className:
	// Currently only supports toggle semantics - and has no effect if toggle string is not specified
	// data-link="class{merge:boolExpr toggle=className}"
	var regularExpression,
		currentValue = this.linkCtx._val || "",
		toggle = this.tagCtx.props.toggle;

	if (toggle) {
		// We are toggling the class specified by the toggle property,
		// and the boolean val binding is driving the insert/remove toggle

		regularExpression = toggle.replace(/[\\^$.|?*+()[{]/g, "\\$&");
		// Escape any regular expression special characters (metacharacters) within the toggle string
		regularExpression = "(\\s(?=" + regularExpression + "$)|(\\s)|^)(" + regularExpression + "(\\s|$))";
		// Example: /(\s(?=myclass$)|(\s)|^)?(myclass(\s|$))/ - so matches (" myclass" or " " or ^ ) followed by ("myclass " or "myclass$") where ^/$ are beginning/end of string
		currentValue = currentValue.replace(new RegExp(regularExpression), "$2");
		val = currentValue + (val ? (currentValue && " ") + toggle : "");
	}
	return val;
};

//========================
// JsViews-specific tags
//========================

function keepParentDataCtx(val) {
	return this.tagCtx.view; // Return the parent view as data context for rendering block content
}

$tags({
	on: {
		attr: NONE,
		init: function(tagCtx) {
			var content,
				tag = this,
				i = 0,
				args = tagCtx.args, // [events,] [selector,] handler
				l = args.length;

			for (; i<l && !$isFunction(args[i]); i++); // Handler is first arg of type function
			tag._hi = l>i && i+1; // handler index
			if (tag._.inline) {
				if (!$sub.rTmpl.exec(content = tagCtx.tmpl.markup)) {
					// Inline {^{on}} tag with no content (or external template content) or with content containing
					// no HTML or JsRender tags: We will wrap the (text) content, or the operation name in a <button> element
					// (Otherwise we will attach the handler to the element content after data-linking)
					tag.template = "<button>" + ($.trim(content) || tagCtx.params.args[i] || "noop") + "</button>";
				}
				tag.attr = HTML;
			}
		},
		onAfterLink: function(tagCtx, linkCtx) {
			var handler, params, find, activeElem,
				tag = this,
				i = tag._hi,
				args = tagCtx.args, // [events,] [selector,] handler
				l = args.length,
				props = tagCtx.props,
				data = props.data,
				view = tagCtx.view,
				contextOb = props.context; // Context ('this' pointer) for attached handler

			if (i) { // There is a handler
				handler = args[i-1];
				params = args.slice(i); // Subsequent args are params
				args = args.slice(0, i-1); // Preceding args (if any) are events and selector
				tag._sel = args[1]; // Selector for descendant elements - for delegated events on those elements, delegating to the activeElem

				activeElem = tag.activeElem = tag.activeElem || $(tag._.inline
					? (tag._sel = args[1] || "*", tag.parentElem)
					// If inline, attach to child elements of tag parent element (filtered by selector argument if provided.
					// (In handler we'll filter out events from sibling elements preceding or following tag.)
					// This allows us to use the delegated pattern where the attached event works even for added elements satisfying the selector
					: linkCtx.elem);

				if (!contextOb) {
					// Get the path for the preceding object (context object) of handler (which is the last arg), compile function
					// to return that context object, and run compiled function against data
					contextOb = /^(.*)[\.^][\w$]+$/.exec(tagCtx.params.args.slice(-params.length - 1)[0]);
					contextOb = contextOb && $sub.tmplFn(delimOpenChar1 + ":" + contextOb[1] + delimCloseChar0, view.tmpl, true)(linkCtx.data, view);
				}

				if (tag._evs) {
					tag.onUnbind();
				}

				activeElem.on(
					tag._evs = args[0] || "click", // events defaults to "click"
					tag._sel,
					data == undefined ? null : data,
					tag._hlr = function hndlr(ev) {
						var nodes, length,
							found = !tag._.inline;

						if (!found) { // If inline, filter out events from sibling elements preceding or following tag.
							nodes = tag.contents("*");
							l = nodes.length;
							while (!found && l--) {
								if (nodes[l].contains(ev.target)) {
									found = true;
								}
							}
						}
						if (found) { // target elem is indeed within the tag, so call the {on} handler
							return handler.apply(contextOb || linkCtx.data, [].concat(
								params, // e.g. par1, par2
								ev,
								{change: ev.type, view: view, linkCtx: linkCtx},
								params.slice.call(arguments, 1) // If triggering event (e.g. jsv-domchange) has additional arguments after ev, pass them too
							));
							// for {on 'click' handler par1 par2} use handler(par1, par2, ev, domchangeEventArgs)
							// for {on 'jsv-domchange' handler par1 par2} use handler(par1, par2, ev, domchangeEventArgs, tagCtx, linkCtx, observableEventArgs)
						}
					}
				);
			}
		},
		onUpdate: function() {
			return false;
		},
		onUnbind: function() {
			var self = this;
			if (self.activeElem) {
				self.activeElem.off(self._evs, self._sel, self._hlr);
			}
		},
		flow: true,
		contentCtx: keepParentDataCtx,
		dataBoundOnly: true
	},
	radiogroup: {
		init: function(tagCtx) {
			this.name = tagCtx.props.name || ("jsv" + Math.random());
		},
		onBind: function(tagCtx, linkCtx) {
			var domChngCntnr,
				tag = this,
				$linkedElem = tag.linkedElem = (tag._.inline ? tag.contents(true, "input[type=radio]") : $(linkCtx.elem).find("input[type=radio]")),
				l = $linkedElem.length;

			if (tag._.inline) {
				// If the first element is owned by (rendered by) this tag (not by a childTag such as {^{for}})
				// use it as container for detecting dom changes
				domChngCntnr = tag.contents("*")[0];
				domChngCntnr = domChngCntnr && $.view(domChngCntnr).ctx.tag === tag.parent ? domChngCntnr : tag.parentElem;
			} else {
				domChngCntnr = linkCtx.elem;
			}
			while (l--) {
				// Configure the name for each radio input element
				$linkedElem[l].name = $linkedElem[l].name || tag.name;
			}
			// Establish a domchange listener in case this radiogroup wraps a {^{for}} or {^{if}} or similar which might dynamically insert new radio input elements
			$(domChngCntnr).on("jsv-domchange", function(ev, forOrIfTagCtx) {
				var linkedElem,
					parentTags = forOrIfTagCtx.ctx.parentTags;
				if (!tag._.inline || domChngCntnr !== tag.parentElem // The domChngCntnr is specific to this tag
					// The domChngCntnr is the parentElem of this tag, so need to make sure dom change event is for
					// a content change within this tag, not outside it.
					|| parentTags && parentTags[tag.tagName] === tag) {
					// Contents have changed so recreate $linkedElem for the radio input elements (including possible new one just inserted)
					$linkedElem = tag.linkedElem = tag.contents(true, "input[type=radio]");
					l = $linkedElem.length;
					while (l--) {
						// Configure binding  and name for each radio input element
						linkedElem = $linkedElem[l];
						linkedElem._jsvLkEl = tag;
						linkedElem.name = linkedElem.name || tag.name;
						bindTo(bindingStore[tag._tgId], tag, linkedElem);
						linkedElem._jsvBnd = "&" + tag._tgId + "+";
						linkedElem.checked = tag.cvtArgs()[0] === linkedElem.value;
					}
				}
			});
		},
		onUpdate: function(ev, eventArgs, tagCtxs) {
			return false; // don't rerender
		},
		contentCtx: keepParentDataCtx,
		dataBoundOnly: true
	}
});

$extend($tags["for"], {
	//onUpdate: function(ev, eventArgs, newTagCtxs) {
		//Consider adding filtering for perf optimization. However the below prevents update on some scenarios which _should_ update - namely when there is another array on which for also depends.
		//var i, l, tci, prevArg;
		//for (tci = 0; (prevArg = this.tagCtxs[tci]) && prevArg.args.length; tci++) {
		//	if (prevArg.args[0] !== newTagCtxs[tci].args[0]) {
		//		return true;
		//	}
		//}
		//return false;
	//},
	onArrayChange: function(ev, eventArgs, tagCtx, linkCtx) {
		var arrayView,
			target = ev.target,
			targetLength = target.length,
			tag = this,
			change = eventArgs.change;
		if (tag._.noVws // Child views not supported because target is not html - e.g. data-link="title{for ...}"
			|| tag.tagCtxs[1] && ( // There is an {{else}}
				change === "insert" && targetLength === eventArgs.items.length // inserting, and new length is same as inserted length, so going from 0 to n
				|| change === "remove" && !targetLength // removing , and new length 0, so going from n to 0
			)) {
			tag.refresh();
		} else {
			for (arrayView in tag._.arrVws) {
				arrayView = tag._.arrVws[arrayView];
				if (arrayView.data === target) {
					arrayView._.onArrayChange.apply(arrayView, arguments);
				}
			}
		}
		tag.domChange(tagCtx, linkCtx, eventArgs);
		ev.done = true;
	},
	onAfterLink: function(tagCtx, linkCtx) {
		var i, arrHandler, arrBinding, data,
			tag = this,
			arrayBindings = tag._ars || {},
			tagCtxs = tag.tagCtxs,
			l = tagCtxs.length,
			selected = tag.selected || 0;

		for (i = 0; i <= selected; i++) {
			tagCtx = tagCtxs[i];        // loop through tagCtxs up to selected
			data = tagCtx.map
				? tagCtx.map.tgt        // 'data' is mapped data
				: tagCtx.args.length
					? tagCtx.args[0]    // or args[0]
					: tagCtx.view.data; // or defaults to current data.

			if ((arrBinding = arrayBindings[i]) && data !== arrBinding[0]) { // Is there previous array data on this tagCtx, different from new data
				$observe(arrBinding[0], arrBinding[1], true); //unobserve previous array
				delete arrayBindings[i];
			}
			if (!arrayBindings[i] && $isArray(data)) {
				$observe(data, arrHandler = function(ev, eventArgs) {
					var tagCt = tagCtx;
					tag.onArrayChange(ev, eventArgs, tagCt, linkCtx);
				});
				arrayBindings[i] = [data, arrHandler]; // Store array data and arrayChangeHandler on tag._ars[i]
			}
		}
		for (i = selected + 1; i < l; i++) { // If there were previous bindings on later tagCtxs, remove them
			if (arrBinding = arrayBindings[i]) {
				$observe(arrBinding[0], arrBinding[1], true); //unobserve previous binding
				delete arrayBindings[i];
			}
		}
		tag._ars = arrayBindings;
	},
	onDispose: function() {
		var l, tag = this;
		for (l in tag._ars) {
			$observe(tag._ars[l][0], tag._ars[l][1], true); //unobserve
		}
	}
});

$extend($tags["if"], {
	onUpdate: function(ev, eventArgs, newTagCtxs) {
		var tci, prevArg, different;
		for (tci = 0; (prevArg = this.tagCtxs[tci]); tci++) {
			different = prevArg.props.tmpl !== newTagCtxs[tci].props.tmpl || prevArg.args.length && !(prevArg = prevArg.args[0]) !== !newTagCtxs[tci].args[0];
			if ((!this.convert && !!prevArg) || different) {
				return different;
				// If there is not a change of template, and there is no converter, and newArg and prevArg are both truthy, return false to cancel update.
				// (Even if values on later elses are different, we still don't want to update, since rendered output would be unchanged)
				// If newArg and prevArg are different, return true, to update
				// If newArg and prevArg are both falsey, move to the next {{else ...}}
			}
		}
		// Boolean value of all args are unchanged (falsey), so return false to cancel update
		return false;
	},
	onAfterLink: function(tagCtx, linkCtx, ctx, ev, eventArgs) {
		if (eventArgs) {
			this.domChange(tagCtx, linkCtx, eventArgs);
		}
	}
});

function observeProps(map, ev, eventArgs) {
	if (eventArgs.change === "set") {
		var target = map.tgt,
			l = target.length;
		while (l--) {
			if (target[l].key === eventArgs.path) {
				break;
			}
		}
		if (l === -1) {
			if (eventArgs.path && !eventArgs.remove) {
				$observable(target).insert({key: eventArgs.path, prop: eventArgs.value});
			}
		} else if (eventArgs.remove) {
			$observable(target).remove(l);
		} else {
			$observable(target[l]).setProperty("prop", eventArgs.value);
		}
	}
}

function observeMappedProps(map, ev, eventArgs) {
	var item,
		source = map.src,
		change = eventArgs.change;

	if (change === "set") {
		if (eventArgs.path === "prop") {
			$observable(source).setProperty(ev.target.key, eventArgs.value);
		} else { // path === "key"
			$observable(source).removeProperty(eventArgs.oldValue); // When key is modified observably, remove old one and set new one
			$observable(source).setProperty(eventArgs.value, ev.target.prop);
		}
	} else if (change === "remove") {
		item = eventArgs.items[0];
		$observable(source).removeProperty(item.key);
		delete source[item.key];
	} else if (change === "insert") {
		item = eventArgs.items[0];
		if (item.key) {
			$observable(source).setProperty(item.key, item.prop);
		}
	}
}

function shallowArrayFilter(allPath /*, object, parentObs*/) { // Filter used by {{props}} for the mappedProps target array
	return allPath.indexOf(".") < 0;
}

$tags("props", {
	baseTag: "for",
	dataMap: $views.map({
		getTgt: $tags.props.dataMap.getTgt,
		obsSrc: observeProps,
		obsTgt: observeMappedProps,
		tgtFlt: shallowArrayFilter
	}),
	flow: true
});

//========================
// Extend jQuery namespace
//========================

$extend($, {

	//=======================
	// jQuery $.view() plugin
	//=======================

	view: $view = function(node, inner, type) {
		// $.view() returns top view
		// $.view(node) returns view that contains node
		// $.view(selector) returns view that contains first selected element
		// $.view(nodeOrSelector, type) returns nearest containing view of given type
		// $.view(nodeOrSelector, "root") returns root containing view (child of top view)
		// $.view(nodeOrSelector, true, type) returns nearest inner (contained) view of given type

		function getInnerView(nd, isVl) {
			if (nd) {
				vwInfos = viewInfos(nd, isVl, rOpenViewMarkers);
				for (j = 0, k = vwInfos.length; j < k; j++) {
					if ((view = viewStore[vwInfos[j].id]) && (view = view && type ? view.get(true, type) : view)) {
						break;
					}
				}
			}
		}

		if (inner !== !!inner) {
			// inner not boolean, so this is view(nodeOrSelector, type)
			type = inner;
			inner = undefined;
		}
		var view, vwInfos, i, j, k, l, elems,
			level = 0,
			body = document.body;

		if (node && node !== body && topView._.useKey > 1) {
			// Perf optimization for common cases

			node = "" + node === node
				? $(node)[0]
				: node.jquery
					? node[0]
					: node;

			if (node) {
				if (inner) {
					getInnerView(node._df, true);
					if (!view) {
						// Treat supplied node as a container element and return the first view encountered.
						elems = qsa ? node.querySelectorAll(bindElsSel) : $(bindElsSel, node).get();
						l = elems.length;
						for (i = 0; !view && i < l; i++) {
							getInnerView(elems[i]);
						}
					}
					return view;
				}
				while (node) {
					// Move back through siblings and up through parents to find preceding node which is a _prv (prevNode)
					// script marker node for a non-element-content view, or a _prv (first node) for an elCnt view
					if (vwInfos = viewInfos(node, undefined, rViewMarkers)) {
						l = vwInfos.length;
						while (l--) {
							view = vwInfos[l];
							if (view.open) {
								if (level < 1) {
									view = viewStore[view.id];
									return view && type ? view.get(type) : view || topView;
								}
								level--;
							} else {
								// level starts at zero. If we hit a view.close, then we move level to 1, and we don't return a view until
								// we are back at level zero (or a parent view with level < 0)
								level++;
							}
						}
					}
					node = node.previousSibling || node.parentNode;
				}
			}
		}
		return topView;
	},

	link: $link,
	unlink: $unlink,

	//=====================
	// override $.cleanData
	//=====================
	cleanData: function(elems) {
		if (elems.length && isCleanCall) {
			// Remove JsViews bindings. Also, remove from the DOM any corresponding script marker nodes
			clean(elems);
		}
		oldCleanData.apply($, arguments);
	}
});

// Possible future addition - e.g. for ckeditor tag control
//$views.utility = {
//	validate: function(html) {
//		try {
//			topView.link(undefined, document.createElement("div"), undefined, undefined, html, undefined, undefined, 1);
//		}
//		catch (e) {
//			return e.message;
//		}
//	}
//};

//===============================
// Extend jQuery instance plugins
//===============================

$extend($.fn, {
	link: function(expr, from, context, noIteration, parentView, prevNode, nextNode) {
		return $link(expr, this, from, context, noIteration, parentView, prevNode, nextNode);
	},
	unlink: function() {
		return $unlink(this);
	},
	view: function(inner, type) {
		return $view(this[0], inner, type);
	}
});

//==============================================================================
// Override jQuery methods that call our overridden cleanData, for disposal etc.
//==============================================================================

$.each([HTML, "replaceWith", "empty", "remove"], function(i, name) {
	var oldFn = $.fn[name];
	$.fn[name] = function() {
		var result;
		isCleanCall = 1; // Make sure cleanData does disposal only when coming from these calls.
		try {
			result = oldFn.apply(this, arguments);
		}
		finally {
			isCleanCall = 0;
		}
		return result;
	};
});

//===============
// Extend topView
//===============

addLinkMethods($extend(topView = $sub.topView, {tmpl: {links: {}}}));

viewStore = {0: topView}; // Top-level view
//===============
// Extend $.views
//===============

$views.getCtx = function(param) { // Return value of ctx.foo, including for compiled contextual parameters, ~foo=expr
	if (param && param._cp) { // If this helper resource is a contextual parameter, ~foo=expr
		param =  param[1](param[0].data, param[0], $sub);
	}
	return param;
};

//===================
// Extend $.views.sub
//===================

$sub._cp = function(paramVal, params, view) { // Get compiled contextual parameters (or properties) ~foo=expr.
	if (view.linked) { // In JsViews, returns [view, linkFn] where linkFn is compiled function for expression
		params = delimOpenChar1 + ":" + params + delimCloseChar0;
		var tmpl = view.tmpl,
			links = topView.tmpl.links, // Use topView links, as for compiled top-level linking expressions. To do - should this ever get disposed?
			linkFn = links[params];
		if (!linkFn) {
			links[params] = linkFn = $sub.tmplFn(params, tmpl, true);
		}
		paramVal = [view, linkFn];
		paramVal._cp = true; // Flag that this is a contextual parameter
	}
	return paramVal; // In JsRender returns evaluated expression
};

$sub._ceo = function cloneExprObjects(obs) {  // Clone exprObs so that each referenced contextual parameter ~foo uses its own exprOb instances
	var ob,
		clones = obs,
		l = obs.length;
	if (l) {
		clones = [];
		while (l--) {
			ob = obs[l];
			if (ob._jsv) {
				ob = $extend({}, ob);              // If an exprOb, clone it. If a string, keep as is
				ob.prm = cloneExprObjects(ob.prm); // Recursively clone exprObs in parameters, too
			}
			clones.unshift(ob);
		}
	}
	return clones;
};

$sub._gccb = function(view) { // Return a callback for accessing the context of a template/data-link expression - and converting ~foo, #foo etc.
	// TODO Consider exposing or allowing override, as public API
	return function(path, object, depth) {
		// TODO consider only calling the contextCb on the initial token in path '~a.b.c' and not calling again on
		// the individual tokens, 'a', 'b', 'c'... Currently it is called multiple times
		var tokens, tag, items, helper, last, nextPath, l;
		if (view && path) {
			if (path._jsv) {
				return path._jsv.call(view.tmpl, object, view, $sub);
			}
			if (path.charAt(0) === "~") {
				// We return new items to insert into the sequence, replacing the "~a.b.c" string:
				// [helperObject 'a', "a.b.c" currentDataItem] so currentDataItem becomes the object for subsequent paths.
				if (path.slice(0, 4) === "~tag") {
					tag = view.ctx;
					if (path.charAt(4) === ".") {
						// "~tag.xxx"
						tokens = path.slice(5).split(".");
						tag = tag.tag;
					}
					if (tokens) {
						return tag ? [tag, tokens.join("."), object] : [];
					}
				}
				path = path.slice(1).split(".");
				if (helper = view.hlp(last = path.shift(), true)) {
					if (helper._cp) {  // helper for (contextual parameter ~foo=...) is an array - [view, ctxPrmDependencies ...]
						if (path.length) {
							nextPath = "." + path.join(".");
							last = helper[l = helper.length-1];
							if (last._jsv) {
								last.sb = nextPath;
								last.bnd = !!depth;
							} else {
								helper[l] = (last + nextPath).replace("#data.", "");
								if (last.slice(0, 5) === "#view") {
									helper[l] = helper[l].slice(6);
									helper.splice(l, 0, view);
								}
							}
						}
						items = [helper]; // Contextual parameter
					} else if (path.length || $isFunction(helper)) {
						items = [helper, path.join("."), object]; // 2way bindng on ~foo.helperLeafProperty or ~computed() or ~contextualParam
					}
				}
				return items || [];
			}
			if (path.charAt(0) === "#") {
				// We return new items to insert into the sequence, replacing the "#a.b.c" string: [view, "a.b.c" currentDataItem]
				// so currentDataItem becomes the object for subsequent paths. The 'true' flag makes the paths bind only to leaf changes.
				return path === "#data" ? [] : [view, path.replace(rViewPath, ""), object];
			}
		}
	};
};

//=========================
// Extend $.views.settings
//=========================

oldAdvSet = $sub.advSet;

$sub.advSet = function() { // refresh advanced settings
	oldAdvSet.call($sub);
	global._jsv = $subSettingsAdvanced._jsv
		? $extend(global._jsv || {}, { // create global _jsv, for accessing views, etc
				views: viewStore,
				bindings: bindingStore
			})
		: undefined; // In IE8 cannot do delete global._jsv
	$viewsLinkAttr = $subSettingsAdvanced.linkAttr;
	linkViewsSel = bindElsSel + ",[" + $viewsLinkAttr + "]";
	wrapMap = $subSettingsAdvanced._wm;
	wrapMap.optgroup = wrapMap.option;
	wrapMap.tbody = wrapMap.tfoot = wrapMap.colgroup = wrapMap.caption = wrapMap.thead;
	wrapMap.th = wrapMap.td;
};

$viewsSettings.advanced({
	linkAttr: "data-link",
	useViews: false,
	noValidate: false,
	// wrapMap provide appropriate wrappers for inserting innerHTML, used in insertBefore
	// We have to close these tags to support XHTML (#13200)
	// TODO investigate whether more recent jQuery implementation using wrapMap in domManip/$().html() etc. is better optimized now...
	_wm: {
		option: [1, "<select multiple='multiple'>", "</select>"],
		legend: [1, "<fieldset>", "</fieldset>"],
		area: [1, "<map>", "</map>"],
		param: [1, "<object>", "</object>"],
		thead: [1, "<table>", "</table>"],
		tr: [2, "<table><tbody>", "</tbody></table>"],
		td: [3, "<table><tbody><tr>", "</tr></tbody></table>"],
		col: [2, "<table><tbody></tbody><colgroup>", "</colgroup></table>"],
		svg_ns: [1, "<svg>", "</svg>"],
		// IE6-8 can't serialize link, script, style, or any html5 (NoScope) tags,
		// unless wrapped in a div with non-breaking characters in front of it.
		div: $.support.htmlSerialize ? [0, "", ""] : [1, "X<div>", "</div>"]
	},
	_fe: {
		input: {
			from: inputAttrib, to: "value"
		},
		textarea: valueBinding,
		select: valueBinding,
		optgroup: {
			to: "label"
		}
	}
});

	return $;
}, window));
