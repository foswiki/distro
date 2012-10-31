jQuery(function($) {
    // have javascript
    $('body').addClass('foswikiJs');
    // cookie check
    var testCookieValue = String(Math.floor(10000000 * Math.random()));
    var testCookieName = 'foswikiRegistrationTest';
    $.cookie(testCookieName, testCookieValue);
    if ( $.cookie(testCookieName) === testCookieValue) {
	$('body').addClass('foswikiCookiesEnabled');
    }
    $.cookie(testCookieName, undefined);
    //
    // inline form validation
    $('form[name=registration]').livequery(function() {
	$('#Fwk1WikiName').wikiword('#Fwk1FirstName, #Fwk1LastName');
	var validator;
	//console.debug($("#FwkVD").text())
	var data = $.parseJSON($("#FwkVD").text())
	validator = $(this).validate({
	    rules: {
		Fwk1FirstName: 'required',
		Fwk1LastName: 'required',
		Fwk1WikiName: {
		    required: true,
		    wikiword: true,
		    remote: {
			url: data.url,
			type: 'get',
			data: {
			    section: 'checkWikiName',
			    skin: 'text',
			    name: function() {
				return $('#Fwk1WikiName').val();
			    }
			}
		    }
		},
		Fwk1LoginName: {
		    required: true,
		    remote: {
			url: data.url,
			type: 'get',
			data: {
			    section: 'checkLoginName',
			    skin: 'text',
			    name: function() {
				return $('#Fwk1LoginName').val();
			    }
			}
		    }
		},
		Fwk1Email: {
		    required: true,
		    email: true
		},
		Fwk1Password: {
		    required: true,
		    minlength: data.MinPasswordLength 
		},
		Fwk1Confirm: {
		    required: true,
		    minlength: data.MinPasswordLength,
		    equalTo: '#Fwk1Password'
		}
	    },
	    messages: data.messages,
	    success: function(label) {
		// remove generated label
		label.remove();
		if (validator.numberOfInvalids() === 0) {
		    $(':submit').removeClass('foswikiSubmitDisabled');
		    $('.expl').addClass('foswikiHidden');
		}
	    },
	    showErrors: function(errorMap, errorList) {
		$(':submit').addClass('foswikiSubmitDisabled');
		$('.expl').removeClass('foswikiHidden');
		validator.defaultShowErrors();
	    }
	});
    });
});

