jQuery(function($) {
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
