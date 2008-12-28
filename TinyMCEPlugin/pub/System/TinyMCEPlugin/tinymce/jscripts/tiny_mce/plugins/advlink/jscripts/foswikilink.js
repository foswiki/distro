var templates = { "window.open" : "window.open('${url}','${target}','${options}')" };

function preinit() {
	// Initialize
	tinyMCE.setWindowArg('mce_windowresize', false);
}

function changeClass() {
	var formObj = document.forms[0];
	formObj.classes.value = getSelectValue(formObj, 'classlist');
}

function init() {
	tinyMCEPopup.resizeToInnerSize();   

	var selecetedText = tinyMCE.selectedInstance.selection.getSelectedHTML();
    
    $j('#link_name_intern').val(selecetedText);
    $j('#link_name_extern').val(selecetedText);
    $j('#insert').val( tinyMCE.getLang('lang_isert', 'Insert', true) ); 
    init_webs();
	window.focus();
}

function init_webs() {

}

function convertURL(url, node, on_save) {
	return eval("tinyMCEPopup.windowOpener." + tinyMCE.settings['urlconverter_callback'] + "(url, node, on_save);");
}


function getAnchorListHTML(id, target) {
	var inst = tinyMCE.getInstanceById(tinyMCE.getWindowArg('editor_id'));
	var nodes = inst.getBody().getElementsByTagName("a"), name, i;
	var html = "";

	html += '<select id="' + id + '" name="' + id + '" class="mceAnchorList" onfocus="tinyMCE.addSelectAccessibility(event, this, window);" onchange="this.form.' + target + '.value=';
	html += 'this.options[this.selectedIndex].value;">';
	html += '<option value="">---</option>';

	for (i=0; i<nodes.length; i++) {
		if ((name = tinyMCE.getAttrib(nodes[i], "name")) != "")
			html += '<option value="#' + name + '">' + name + '</option>';
	}

	html += '</select>';

	return html;
}

function insertFoswikiLink() {
    var href = "";
    var title = "";
    var link_name = tinyMCE.selectedInstance.selection.getSelectedHTML();
    var target = "_self";
    var errormsg = "";
    if($j("div[id='internal_link_panel'][class*='current']").length > 0) {
        var web = $j("#web_name").val();        
        if(web =="")
            errormsg +="You must select a web\n";
            
        var topic = $j("#topic_name").val();        
        if(topic == "")
            errormsg += "You must define the topic to link to\n";
            
        var title = $j("#internal_link_title").val();
        href = '[['+web+'.'+topic+']['+link_name+']]';        
    }
    else if ($j("div[id='external_link_panel'][class*='current']").length > 0) {
        var ext_link = $j("#external_link_href").val();
        if(ext_link == "" || ext_link == "http://")
            errormsg += "You must define the link\n";
            
        var title = $j("#external_link_title").val();
        href = '[['+ext_link+']['+link_name+']]';  
    }
    if(errormsg != "") {
        alert(errormsg);
        return;
    }
    tinyMCEPopup.restoreSelection();
    tinyMCEPopup.execCommand("mceBeginUndoLevel");
    tinyMCEPopup.execCommand("mceInsertContent", false, href);
    tinyMCEPopup.execCommand("mceEndUndoLevel");
    tinyMCEPopup.close();
}
// While loading
preinit();
