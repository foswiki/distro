var Pattern = {

	searchResultsCount:0,
	metaTags:[],
	
	createTwikiActionFormStepSign:function(el) {
		var sign = '&#9658;';
		var newEl = twiki.HTML.insertBeforeElement(
			el,
			'span',
			sign
		);
		newEl.className = 'twikiActionFormStepSign';
	},

	/**
	Creates a attachment counter in the attachment table twisty.
	*/
	setAttachmentCount:function(inTableElement) {		
		var count = inTableElement.getElementsByTagName("tr").length - 1;
		var countStr = " " + "<span class='patternAttachmentCount'>" + " ("  + count + ")" + "<\/span>";
		var showElem = document.getElementById('topicattachmentslistshow');
		if (showElem != undefined) {
			var labelElem = showElem.getElementsByTagName('a')[0].getElementsByTagName('span')[0];
			labelElem.innerHTML += countStr;
		}
		var hideElem = document.getElementById('topicattachmentslisthide');
		if (hideElem != undefined) {
			var labelElem = hideElem.getElementsByTagName('a')[0].getElementsByTagName('span')[0];
			labelElem.innerHTML += countStr;
		}
	},
	
	addSearchResultsCounter:function(el) {
		var count = twiki.HTML.getHtmlOfElement(el);
		Pattern.searchResultsCount += parseInt(count);
	},
	
	displayTotalSearchResultsCount:function(el) {
		// write result count
		if (Pattern.searchResultsCount >= 10) {
			var text = " " + TEXT_NUM_TOPICS + " <b>" + Pattern.searchResultsCount + " <\/b>";
			twiki.HTML.setHtmlOfElement(el, text);			
		}		
	},
	
	displayModifySearchLink:function() {
		var linkContainer = document.getElementById('twikiModifySearchContainer');
		if (linkContainer != null) {
			if (Pattern.searchResultsCount > 0) {
				var linkText=' <a href="#" onclick="location.hash=\'twikiSearchForm\'; return false;"><span class="twikiLinkLabel twikiSmallish">' + TEXT_MODIFY_SEARCH + '</span></a>';
					twiki.HTML.setHtmlOfElement(linkContainer, linkText);
			}
		}
	}
}

var patternRules = {
	'.twikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	},
	'#jumpFormField' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_JUMP);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#quickSearchBox' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_SEARCH);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#tabletwikiAttachmentsTable' : function(el) {
		Pattern.setAttachmentCount(el);
	},
	'body.patternEditPage' : function(el) {
		twiki.Event.addLoadEvent(initForm, false); // call after Behaviour
	},
	'.twikiSearchResultCount' : function(el) {
		Pattern.addSearchResultsCounter(el);
	},
	'#twikiNumberOfResultsContainer' : function(el) {
		Pattern.displayTotalSearchResultsCount(el);
	},
	'#twikiWebSearchForm':function(el) {
		Pattern.displayModifySearchLink();
	},
	'.twikiPopUp':function(el) {
		el.onclick = function() {
			twiki.Window.openPopup(el.href, {template:"viewplain"});
			return false;
		}
	},
	'.twikiFocus':function(el) {
		el.focus();
	}
};
Behaviour.register(patternRules);

var initForm; // in case initForm is not defined (f.e. when TinyMCE is used and twiki_edit.js is not loaded
var TEXT_JUMP = twiki.getMetaTag('TEXT_JUMP');
var TEXT_SEARCH = twiki.getMetaTag('TEXT_SEARCH');
var TEXT_NUM_TOPICS = twiki.getMetaTag('TEXT_NUM_TOPICS');
var TEXT_MODIFY_SEARCH = twiki.getMetaTag('TEXT_MODIFY_SEARCH');
