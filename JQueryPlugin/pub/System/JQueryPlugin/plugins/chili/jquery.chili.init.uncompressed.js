(function($) {
  $(function() {

    ChiliBook.recipeFolder = foswiki.pubUrlPath+'/'+foswiki.systemWebName+'/JQueryPlugin/plugins/chili/recipes/';
    ChiliBook.automaticSelector = 'pre';

    if (ChiliBook.automatic) {
      $(ChiliBook.automaticSelector).chili();
    }
  });
})(jQuery);

/* improved codeLanguage that removes metadata first */
ChiliBook.codeLanguage = function( el ) {
  var recipeName = jQuery(el).attr( "class" );
  recipeName = recipeName.replace(/\s*{.*}\s*/, "");
  return recipeName ? recipeName : '';
}
