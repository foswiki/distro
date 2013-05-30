jQuery(function($) {
	/* call supersubs first, then superfish, so that subs are
		 not display:none when measuring. Call before initialising
		 containing tabs for same reason. */

	jQuery('#tree-demo, #sample-menu-5').supersubs({
		minWidth: 12, /* minimum width of sub-menus in em units */
		maxWidth: 30, /* maximum width of sub-menus in em units */
		extraWidth: 1 /* extra width can ensure lines don't sometimes turn over
						 due to slight rounding differences and font-family */
	}).superfish();

	jQuery('#tree-demo, #sample-menu-1').superfish();

        $('#sample-menu-3').superfish({
                animation: {height:'show'},
                delay: 1200
        });
        
        $('#sample-menu-4').superfish({
                pathClass: 'current'
        });

	jQuery('#sample-menu-4').superfish({
		delay:	1000,
		pathClass:  'current' 	
	});
});
