/**
 *
 * @author Eugen Mayer
 * @copyright Copyright Impressive.media GbR
 */

/* Import plugin specific language pack */
tinyMCE.importPluginLanguagePack('foswikilink');

var TinyMCE_FoswikiLinkPlugin = {
	getInfo : function() {
		return {
			longname : 'Foswiki link',
			author : 'Eugen Mayer - Impressive.media GbR',
			authorurl : 'http://impressive-media.de',
			infourl : 'http://impressive-media.de',
			version : "0.1"
		};
	},

	getControlHTML : function(cn) {
		switch (cn) {
			case "link":
				return tinyMCE.getButtonHTML(cn, 'lang_link_desc', '{$themeurl}/images/link.gif', 'mceAdvLink');
		}

		return "";
	},

	execCommand : function(editor_id, element, command, user_interface, value) {
		switch (command) {
			case "mceAdvLink":
				var inst = tinyMCE.getInstanceById(editor_id), anySelection = false;
				var focusElm = inst.getFocusElement(), selectedText = inst.selection.getSelectedText();

				if (tinyMCE.selectedElement)
					anySelection = (tinyMCE.selectedElement.nodeName.toLowerCase() == "img") || (selectedText && selectedText.length > 0);

				if (anySelection || (focusElm != null && focusElm.nodeName == "A")) {
					tinyMCE.openWindow({
						file : '../../plugins/foswikilink/link.htm',
						width : 380 + tinyMCE.getLang('lang_advlink_delta_width', 0),
						height : 400 + tinyMCE.getLang('lang_advlink_delta_height', 0)
					}, {
						editor_id : editor_id,
						inline : "yes"
					});
				}

				return true;
		}

		return false;
	},

	handleNodeChange : function(editor_id, node, undo_index, undo_levels, visual_aid, any_selection) {
		if (node == null)
			return;

		do {
			if (node.nodeName == "A" && tinyMCE.getAttrib(node, 'href') != "") {
				tinyMCE.switchClass(editor_id + '_advlink', 'mceButtonSelected');
				return true;
			}
		} while ((node = node.parentNode));

		if (any_selection) {
			tinyMCE.switchClass(editor_id + '_advlink', 'mceButtonNormal');
			return true;
		}

		tinyMCE.switchClass(editor_id + '_advlink', 'mceButtonDisabled');

		return true;
	}
};

tinyMCE.addPlugin("foswikilink", TinyMCE_FoswikiLinkPlugin);
