jQuery(function() {
    $("#navigate").change(function(e) {
	this.form.topic.value = this.options[this.selectedIndex].value;
	this.form.submit();
    });
});
