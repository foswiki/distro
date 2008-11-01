// to please pattern skin < 4.2
function initTextAreaHeight () { }
function handleKeyDown () { }
var bottomBarHeight = -1;
function fixHeightOfPane() {

  var selector = (newTab)?"#"+newTab:".jqTab:visible";
  selector += " .jqTabContents";
  //alert("newTab="+newTab+" selector="+selector);
  var $container = $(selector);
  var paneOffset = $container.offset({
    scroll:false,
    border:true,
    padding:true,
    margin:true
  });


  if (typeof(paneOffset) != 'undefined') {

    var paneTop = paneOffset.top;
    if (bottomBarHeight < 0) {
      bottomBarHeight = $(".natEditBottomBar").height();
    }
    //alert("container="+$container.parent().attr('id')+" paneTop="+paneTop+" bottomBarHeight="+bottomBarHeight);

    var windowHeight = $(window).height();
    if (!windowHeight) {
      windowHeight = window.innerHeight; // woops, jquery, whats up, i.e. for konqueror
    }
    var height = windowHeight-paneTop-bottomBarHeight-70;

    var newTabSelector;
    if (typeof(newTab) == 'undefined') {
      newTabSelector = ".jqTab:visible";
    } else {
      newTabSelector = "#"+newTab;
    }

    // add new height to those containers, that don't have an natEditAutoMaxExpand element
    $(newTabSelector+" .jqTabContents").filter(function(index) { 
      return $(".natEditAutoMaxExpand", this).length == 0; 
    }).each(function() {
      $(this).height(height);
    });
  }


  // add a slight timeout not to DoS IE 
  // before enabling handler again
  setTimeout(function() { 
    $(window).one("resize", fixHeightOfPane);
  }, 20);
}
