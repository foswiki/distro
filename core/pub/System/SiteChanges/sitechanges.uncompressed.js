(function($) {
   
   var DEBUG;

   function updateLastTimeCheckedOption (inDate) {
      var el = document.getElementById('last_time_checked');
      if (el) {
         el.value = inDate;
         el.text = 'last time I checked';
      }
   }
   
   function setOptionSelected (inId) {
      if (DEBUG && console) {
         console.log('setOptionSelected:inId=' + inId);
      }
      var el = document.getElementById(inId);
      if (el) {
         el.selected = 'selected';
      }
   }
   
   function processFormValue (inValue) {
      if (DEBUG && console) {
         console.log('submitted:' + inValue);
      }
      return true;
   }
   
   // stores the name
   function storeSelectedOption (inName, inValue, inStorageField) {
      if (DEBUG && console) {
         console.log('storeSelectedOption:inName=' + inName + ';inValue=' + inValue + ';inStorageField=' + inStorageField);
      }
      // store readable value so we can use it when reloading the page
      inStorageField.value=inName;
      return true;
   }
   
   function init() {
      var DEFAULT_OPTION_ID = '24_hours_ago';
   
      var dateLastCheck = foswiki.Pref.getPref('WebChangesForAllWebs_dateLastCheck');
      if (dateLastCheck) {
         var selectedOption = $('input[name="sinceReadable"]').val();
         if (DEBUG && console) {
            console.log('sinceReadable selectedOption:' + selectedOption);
         }
         if (selectedOption) {
            setOptionSelected(selectedOption);
         } else {
            setOptionSelected(DEFAULT_OPTION_ID);
         }
      }
      var d = new Date();
      var now = d.getFullYear() + '-' +
          (d.getMonth() + 1) + '-' +
          d.getDate() + ' ' +
          d.getHours() + ':' +
          d.getMinutes() + ':' +
          d.getSeconds();
      now = now.replace(/([-: ])(\d)([-: ]|$)/g, '$1\60$2$3');
      if (DEBUG && console) {
         console.log('now:' + now);
      }
      if (now) {
         foswiki.Pref.setPref(foswiki.getPreference('WEB') +
         '_' + foswiki.getPreference('TOPIC') +
         '_dateLastCheck', now);
         updateLastTimeCheckedOption(now);
      }
   }
   
   function submitForm() {
      document.forms.seeChangesSince.web.value = document.forms.seeChangesSince.web.value.replace(/\s*,\s*/, ', ');
      processFormValue(document.forms.seeChangesSince.since.value);
      document.forms.seeChangesSince.submit();
   }
   
   $(function() {
      DEBUG = $("input[name='debugJs']").val();
      $('#siteChangesSelect').change(function() {
         var $selected = $('option:selected', this);
         storeSelectedOption($selected.attr('id'), $selected.attr('value'), document.forms.seeChangesSince.sinceReadable);
         submitForm();
      });
      $(document.forms.seeChangesSince).submit(function() {
         submitForm();
      });
      init();
   });
}(jQuery));

