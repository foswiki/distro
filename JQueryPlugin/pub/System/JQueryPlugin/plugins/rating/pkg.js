window.jQuery&&function(t){if(!t.support.opacity&&!t.support.style)try{document.execCommand("BackgroundImageCache",!1,!0)}catch(t){}t.fn.rating=function(a){if(0==this.length)return this;if("string"==typeof arguments[0]){if(this.length>1){var i=arguments;return this.each((function(){t.fn.rating.apply(t(this),i)}))}return t.fn.rating[arguments[0]].apply(this,t.makeArray(arguments).slice(1)||[]),this}a=t.extend({},t.fn.rating.options,a||{});return t.fn.rating.calls++,this.not(".star-rating-applied").addClass("star-rating-applied").each((function(){var i,n=t(this),r=(this.name||"unnamed-rating").replace(/\[|\]/g,"_").replace(/^\_+|\_+$/g,""),e=t(this.form||document.body),s=e.data("rating");s&&s.call==t.fn.rating.calls||(s={count:0,call:t.fn.rating.calls});var l=s[r]||e.data("rating"+r);l&&(i=l.data("rating")),l&&i?i.count++:((i=t.extend({},a||{},(t.metadata?n.metadata():t.meta?n.data():null)||{},{count:0,stars:[],inputs:[]})).serial=s.count++,l=t('<span class="star-rating-control"/>'),n.before(l),l.addClass("rating-to-be-drawn"),(n.attr("disabled")||n.hasClass("disabled"))&&(i.readOnly=!0),n.hasClass("required")&&(i.required=!0),l.append(i.cancel=t('<div class="rating-cancel"><a title="'+i.cancel+'">'+i.cancelValue+"</a></div>").on("mouseover",(function(){t(this).rating("drain"),t(this).addClass("star-rating-hover")})).on("mouseout",(function(){t(this).rating("draw"),t(this).removeClass("star-rating-hover")})).on("click",(function(){t(this).rating("select")})).data("rating",i)));var d=t('<div role="text" aria-label="'+this.title+'" class="star-rating rater-'+i.serial+'"><a title="'+(this.title||this.value)+'">'+this.value+"</a></div>");if(l.append(d),this.id&&d.attr("id",this.id),this.className&&d.addClass(this.className),i.half&&(i.split=2),"number"==typeof i.split&&i.split>0){var u=(t.fn.width?d.width():0)||i.starWidth,c=i.count%i.split,o=Math.floor(u/i.split);d.width(o).find("a").css({"margin-left":"-"+c*o+"px"})}i.readOnly?d.addClass("star-rating-readonly"):d.addClass("star-rating-live").on("mouseover",(function(){t(this).rating("fill"),t(this).rating("focus")})).on("mouseout",(function(){t(this).rating("draw"),t(this).rating("blur")})).on("click",(function(){t(this).rating("select")})),this.checked&&(i.current=d),"A"==this.nodeName&&t(this).hasClass("selected")&&(i.current=d),n.hide(),n.on("change.rating",(function(a){if(a.selfTriggered)return!1;t(this).rating("select")})),d.data("rating.input",n.data("rating.star",d)),i.stars[i.stars.length]=d[0],i.inputs[i.inputs.length]=n[0],i.rater=s[r]=l,i.context=e,n.data("rating",i),l.data("rating",i),d.data("rating",i),e.data("rating",s),e.data("rating"+r,l)})),t(".rating-to-be-drawn").rating("draw").removeClass("rating-to-be-drawn"),this},t.extend(t.fn.rating,{calls:0,focus:function(){var a=this.data("rating");if(!a)return this;if(!a.focus)return this;var i=t(this).data("rating.input")||t("INPUT"==this.tagName?this:null);a.focus&&a.focus.apply(i[0],[i.val(),t("a",i.data("rating.star"))[0]])},blur:function(){var a=this.data("rating");if(!a)return this;if(!a.blur)return this;var i=t(this).data("rating.input")||t("INPUT"==this.tagName?this:null);a.blur&&a.blur.apply(i[0],[i.val(),t("a",i.data("rating.star"))[0]])},fill:function(){var t=this.data("rating");if(!t)return this;t.readOnly||(this.rating("drain"),this.prevAll().addBack().filter(".rater-"+t.serial).addClass("star-rating-hover"))},drain:function(){var t=this.data("rating");if(!t)return this;t.readOnly||t.rater.children().filter(".rater-"+t.serial).removeClass("star-rating-on").removeClass("star-rating-hover")},draw:function(){var a=this.data("rating");if(!a)return this;this.rating("drain");var i=t(a.current),n=i.length?i.prevAll().addBack().filter(".rater-"+a.serial):null;n&&n.addClass("star-rating-on"),a.cancel[a.readOnly||a.required?"hide":"show"](),this.siblings()[a.readOnly?"addClass":"removeClass"]("star-rating-readonly")},select:function(a,i){var n=this.data("rating");if(!n)return this;if(!n.readOnly){if(n.current=null,void 0!==a||this.length>1){if("number"==typeof a)return t(n.stars[a]).rating("select",void 0,i);if("string"==typeof a)return t.each(n.stars,(function(){t(this).data("rating.input").val()==a&&t(this).rating("select",void 0,i)})),this}else n.current="INPUT"==this[0].tagName?this.data("rating.star"):this.is(".rater-"+n.serial)?this:null;this.data("rating",n),this.rating("draw");var r=t(n.current?n.current.data("rating.input"):null),e=t(n.inputs).filter(":checked");return t(n.inputs).not(r).prop("checked",!1),r.prop("checked",!0),t(r.length?r:e).trigger({type:"change",selfTriggered:!0}),(i||null==i)&&n.callback&&n.callback.apply(r[0],[r.val(),t("a",n.current)[0]]),this}},readOnly:function(a,i){var n=this.data("rating");if(!n)return this;n.readOnly=!(!a&&null!=a),i?t(n.inputs).prop("disabled",!0):t(n.inputs).removeAttr("disabled"),this.data("rating",n),this.rating("draw")},disable:function(){this.rating("readOnly",!0,!0)},enable:function(){this.rating("readOnly",!1,!1)}}),t.fn.rating.options={cancel:"Cancel Rating",cancelValue:"",split:0,starWidth:16},t((function(){t("input[type=radio].star").rating()}))}(jQuery),jQuery((function(t){t(".jqRating:not(.jqInitedRating)").livequery((function(){var a=t(this),i=t.extend({focus:function(i,n){var r=t(n),e=r.attr("title")||r.attr("value");a.find(".jqRatingValue").text(e)},blur:function(t,i){var n=a.find(":checked"),r=n.attr("title")||n.attr("value")||"";a.find(".jqRatingValue").text(r)},callback:function(i,n){var r=t(n),e=r.attr("title")||r.attr("value");a.find(".jqRatingValue").text(e)}},a.data(),a.metadata()),n=a.find(":checked"),r=n.attr("title")||n.attr("value")||"";t("<span>"+r+"</span>").addClass("jqRatingValue").appendTo(a),a.addClass("jqInitedRating").find("[type=radio]").rating(i),a.find(".rating-cancel").hover((function(){"function"==typeof i.focus&&i.focus(0,this)}),(function(){"function"==typeof i.blur&&i.blur(0,this)}))}))}));