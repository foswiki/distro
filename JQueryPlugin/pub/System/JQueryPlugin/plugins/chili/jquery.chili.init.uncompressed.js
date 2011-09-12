jQuery(function($) {

  /* improved codeLanguage that removes metadata first */
  ChiliBook.codeLanguage = function( el ) {
    var $el = jQuery(el),
        recipeName = $el.attr("class") || '', 
        re;

    recipeName = recipeName.replace(/\s*{.*}\s*/, "");
    re = /^(bash|cplusplus|csharp|css|delphi|html|java|js|lotusscript|php-f|php|recipes|sql|tml)$/;

    return (recipeName && re.test(recipeName))?recipeName : '';
  }

  ChiliBook.recipeFolder = foswiki.getPreference("PUBURLPATH")+'/'+foswiki.getPreference("SYSTEMWEB")+'/JQueryPlugin/plugins/chili/recipes/';
  ChiliBook.automaticSelector = 'pre';
  //ChiliBook.lineNumbers = true;

  if (ChiliBook.automatic) {
    $(ChiliBook.automaticSelector).livequery(function() {
      $(this).chili();
    });
  }
});

