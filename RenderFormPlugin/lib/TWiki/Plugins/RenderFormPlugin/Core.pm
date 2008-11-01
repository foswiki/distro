package TWiki::Plugins::RenderFormPlugin::Core;

### todo:
# + additional form field definitions that can be used with URLPARAM in the templatetopic
# + AJAX form data submit

use strict;

use Switch;

use vars qw( $pluginName %defaults @requiredOptions @flagOptions %validOptions %options $defaultsInitialized @unknownParams @missingParams @invalidParams $formCounter );

$pluginName="RenderFormPlugin";

# =========================
sub _initDefaults {

	%defaults = 
		( 
			form => undef,			## TWikiForms definition
			_DEFAULT => undef,		## same as form
			topic => undef, 		## default %TOPIC%XXXXXXXXXXX
			script => 'save',
			templatetopic => undef,
			topicparent => undef,
			dontnotify => undef,
			createbutton => 'Create',
			editbutton => 'Update',
			onlynewtopic => undef,
			onlywikiname => undef,
			hidden => undef,		## hidden form elements
			mode => 'create',		## allowed: create / edit / view
			dateformat => undef,		## date format for date form fields
			hideheader => 0,
			template => undef,
			formName => undef,
			order => undef,
			text => undef,
			missingparamsmsg => '%RED% Sorry, missing required parameters: %MISSINGPARAMSLIST% %ENDCOLOR% <br/> Required parameters are %REQUIREDPARAMSLIST%',
			unknownparamsmsg => '%RED% Sorry, some parameters are unknown: %UNKNOWNPARAMSLIST% %ENDCOLOR% <br/> Allowed parameters are (see TWiki.RenderFormPlugin topic for more details): %KNOWNPARAMSLIST%',
			invalidparamsmsg => '%RED% Sorry, some parameters are invalid for: %INVALIDPARAMSLIST% %ENDCOLOR% <br/> Valid parameters are (see TWiki.RenderFormPlugin topic for more details): %VALIDPARAMSLIST%',
			layout => undef,
			fieldmarker => '@',
		);

	@requiredOptions = ( 'form' );

	@flagOptions = ( 'dontnotify', 'onlywikiname', 'onlynewtopic', 'hideheader' );

	%validOptions = ( 'script' => [ 'edit','save' ] , 
			  'mode' => [ 'create', 'edit', 'view' ], 
			);

	$formCounter = 0;

	$defaultsInitialized = 1;

}
# =========================
sub _initOptions {
	my ($attributes, $topic, $web) = @_;

	my %params = &TWiki::Func::extractParameters($attributes);

	## handle default parameter:
	$params{form}=$params{_DEFAULT} if (defined $params{_DEFAULT}) && (!defined $params{form});


	my @allOptions = keys %defaults;

        @unknownParams= ( );
        foreach my $option (keys %params) {
                push (@unknownParams, $option) unless grep(/^\Q$option\E$/, @allOptions);
        }
        return 0 if $#unknownParams != -1; 

	my $tmplName = $params{template};
	$tmplName = ( TWiki::Func::getPreferencesValue("\U${pluginName}_TEMPLATE\E") || undef) unless defined $tmplName;

	my $cgi = TWiki::Func::getCgiQuery();


	$formCounter++;
	my $formName = defined $params{formName} ? $params{formName} : "renderForm$web$formCounter"; 


        %options= ();
        foreach my $option (@allOptions) {
                my $v = (!defined $cgi->param('rfp_s_formName')) || ($cgi->param('rfp_s_formName') eq $formName) 
				? $cgi->param("rfp_${option}") : undef;
                $v = $params{$option} unless defined $v;

		if ((defined $tmplName)&&(!defined $v)) {
			$v = (TWiki::Func::getPreferencesFlag("\U${pluginName}_TEMPLATE_${tmplName}_${option}\E") || undef) if grep /^\Q$option\E$/, @flagOptions;
			$v = (TWiki::Func::getPreferencesValue("\U${pluginName}_TEMPLATE_${tmplName}_${option}\E") || undef) unless defined $v;
			$v = undef if (defined $v) && ($v eq "");
		}

                if (defined $v) {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $options{$option} = ($v!~/^(0|false|no|off)$/i);
                        } else {
                                $options{$option} = $v;
                        }
                } else {
                        if (grep /^\Q$option\E$/, @flagOptions) {
                                $v = TWiki::Func::getPreferencesFlag("\U${pluginName}_$option\E") || undef;
                        } else {
                                $v = TWiki::Func::getPreferencesValue("\U${pluginName}_$option\E") || undef;
                        }
                        $v = undef if (defined $v) && ($v eq "");
                        $options{$option}=(defined $v)? $v : $defaults{$option};
                }

        }

	$options{formName}=$formName unless defined $options{formName};

	# automatic topic naming:
	$options{topic} = $topic.'XXXXXXXXXX' unless defined $options{topic};

	# automatic mode change:
	my ($w,$t) = _getWebAndTopic($options{topic},$web);
	my $topicExists = TWiki::Func::topicExists($w,$t);
	$options{mode}='view' if (($options{mode} eq $defaults{mode}) && ($options{topic} ne $topic.'XXXXXXXXXX') && $topicExists);

	# automatic form detection:
	$options{form} = _detectForm($web) if (!defined $options{form}) && (defined $options{topic}) && $topicExists;

	# check required options:
	@missingParams= ( );
	foreach my $option (@requiredOptions) {
		push (@missingParams, $option) unless defined $options{$option};
	}
	return 0 if $#missingParams != -1;

	# validate options:
	@invalidParams = ( );
	foreach my $option (keys %validOptions) {
		push (@invalidParams,$option) if (defined $options{$option}) && (!grep(/^\Q$options{$option}\E$/i,@{$validOptions{$option}}));
	}
	return 0 if $#invalidParams != -1;

	return 1;
}
# =========================
sub _detectForm {
	my ($theWeb) = @_;
	my ($web,$topic) = _getWebAndTopic($options{topic},$theWeb);
	my $text = _readTopicText($web,$topic,0);
	my $formTopic = undef;

	if ($text =~ /\%META:FORM{(.*?)}\%/s) {
		my %params = TWiki::Func::extractParameters($1);
		my ($w,$t) = _getWebAndTopic($params{name}, $web);
		$formTopic = "$w.$t" if TWiki::Func::topicExists($w,$t);
	}
	return $formTopic;
}
# =========================
sub render {
	my($attributes, $theTopic, $theWeb) = @_;

	_initDefaults() unless $defaultsInitialized;

	## prevent possible mod_perl problems:
	local(%options, @unknownParams, @missingParams, @invalidParams);

	_initOptions($attributes, $theTopic, $theWeb) 
		|| return ($#unknownParams != -1  ? _createUnknownParamsMessage() : ($#missingParams != -1 ? _createMissingParamsMessage() : _createInvalidParamsMessage()));

	my $topic = defined $options{topic} ? $options{topic} : $theTopic.'XXXXXXXXXX';

	my ($defsRef,$attrRef,$mandRef,$titlRef)  = _readTWikiFormsDef($theWeb);

	_readTopicFormData($attrRef, $topic, $theWeb) if $options{mode} ne 'create';

	$defsRef = _reorderDefs($defsRef,$titlRef) if defined $options{order};

	my @defs = @{$defsRef};
	my %attr = %{$attrRef};
	my @mand = @{$mandRef};
	my %titl = %{$titlRef};

	my $text = "";
	my $cgi = TWiki::Func::getCgiQuery();

	#_dump(\@defs);

	my $formName = $options{formName};


	$text .= $cgi->start_form(-method=>"post", 
					-onSubmit=>"return ${formName}CheckFormData();",
					-name=>$formName, 
					-action=>TWiki::Func::getScriptUrl($theWeb, $topic, $options{script}));
	$text .= $cgi->a({-name=>"$formName"},"");

	$options{topicparent} = "$theWeb.$theTopic" unless defined $options{topicparent};

	$text .= $cgi->hidden(-name=>'formtemplate', -default=>$options{form});
	$text .= $cgi->hidden(-name=>'templatetopic', -default=>$options{templatetopic}) if defined $options{templatetopic};
	$text .= $cgi->hidden(-name=>'text', -default=>$options{text}) if defined $options{text} && !defined $options{templatetopic};
	$text .= $cgi->hidden(-name=>'topicparent', -default=>$options{topicparent}) if defined $options{topicparent};
	$text .= $cgi->hidden(-name=>'onlynewtopic', -default=>($options{mode} eq 'edit'?'off':'on')) if(!defined $options{onlynewtopic}) || $options{onlynewtopic};
	$text .= $cgi->hidden(-name=>'onlywikiname', -default=>'on') if $options{onlywikiname};
	$text .= $cgi->hidden(-name=>'dontnotify', -default=>$options{dontnotify}) if defined $options{dontnotify};

	$text .= _createJavaScript(\@mand, $formName) unless $options{mode} eq 'view';


	if (defined $options{layout} && _layoutTopicExists($theWeb)) {
		$text .= _renderUserLayout($topic,$theWeb,$titlRef);
	} else {
		my @hidden = (defined $options{hidden} && $options{hidden}!~/^\s*$/) ? split(/[,\|\;]/, $options{hidden}) :  ( );
		my $hiddenText = "";
		$text .= "\n";

		my $button= _getSwitchButton($theTopic,$theWeb);
		$text .= "|  * ".($options{mode} eq 'create'?"<nop>":"")."$topic$button / $options{form} * ||\n" unless $options{hideheader};
	
		foreach my $def (@defs) {
			if (grep(/^\Q$$def{name}\E$/,@hidden)) {
				$hiddenText .= $cgi->hidden(-name=>$$def{name}, -default=>$$def{values}[0]{name});
				next;
			}
			my ($td,$tadd) = _renderFormField($cgi,$def,$formName);
			$text .= '|  *'.$cgi->span({title=>$$def{tooltip}}, " ".$$def{title} . ($$def{attr}=~/M/ ?" %RED%*%ENDCOLOR%":" ") . $tadd  ) . '*|'.$td.'|';
			$text .= "\n";
		}
		$text .= "||  %RED%*%ENDCOLOR% indicates mandatory fields|\n" if $#mand != -1;
		$text .= $cgi->submit(-name=>'Save', -value=>$options{$options{mode}.'button'}) unless $options{mode}  eq 'view';
		$text .= $hiddenText;
	}
	$text .= $cgi->end_form();
	$text .= "\n";
	return $text;
}
# =========================
sub _layoutTopicExists {
	my ($theWeb) = @_;
	my ($topic,$web);
	($topic) = split(/\#/,$options{layout});
	($web,$topic) =  _getWebAndTopic($topic,$theWeb);
	return TWiki::Func::topicExists($web,$topic);
}
# =========================
sub _renderUserLayout {
	my ($topic,$web,$a) = @_;

	my $cgi = TWiki::Func::getCgiQuery();
	my $formName = $options{formName};

	my $text = _readUserLayout($web);

	$text=~s/\Q$options{fieldmarker}FORMTOPIC$options{fieldmarker}\E/$options{form}/g;

	$text=~s/\Q$options{fieldmarker}TOPIC$options{fieldmarker}\E/$topic/g;

	my $button = $options{mode} ne 'view' ? $cgi->submit(-name=>'Save', -value=>$options{$options{mode}.'button'}) : "";
	$text=~s/\Q$options{fieldmarker}SUBMIT$options{fieldmarker}\E/$button/g;

	my $switch = _getSwitchButton($topic,$web);
	$text=~s/\Q$options{fieldmarker}SWITCH$options{fieldmarker}\E/$switch/g;

	$text=~s/\Q$options{fieldmarker}\EOPTION[\(\[\{]([^\)\}\]\Q$options{fieldmarker}\E]+)[\)\}\]]\Q$options{fieldmarker}\E/$options{$1}/sg;
	$text=~s/\Q$options{fieldmarker}OPTION$options{fieldmarker}\E/join(", ",sort keys %options)/eg;

	my $hidden="";
	foreach my $name (keys %{$a}) {
		my $def = $$a{$name};
		my $title = $$def{title};

		if ($text=~s/(\Q$options{fieldmarker}$title$options{fieldmarker}\E)/join(" ",_renderFormField($cgi,$def,$formName))/eg) {
			TWiki::Func::writeDebug("$1 substituted") if $TWiki::Plugins::RenderFormPlugin::debug;
		} else {
			$hidden .= $cgi->hidden(-name=>$name, -default=>$$def{values}[0]{name});
		}
	}
	$text.="\n$hidden";

	return $text;
}
# =========================
sub _readUserLayout {
	my ($web) = @_;

	my $layout = undef;

	my ($lt,$name) = split(/\#/,$options{layout});
	
	my ($w,$t) = _getWebAndTopic($lt,$web);
	my $text = _readTopicText($w,$t);

	my $firstlayout = undef;

	while ((!defined $layout)&&($text=~s/\%STARTRENDERFORMLAYOUT\{(.*?)\}\%(.*?)\%STOPRENDERFORMLAYOUT\%//s)) {
		my ($p,$l) = ($1,$2);
		my %params = TWiki::Func::extractParameters($p);
		my $pname = $params{name};
		$pname = $params{_DEFAULT} unless defined $pname;
		if ((defined $name) && (defined $pname) && ($pname eq $name) && ((!defined $params{mode}) || ($params{mode} eq $options{mode}))) { 
			$layout = $l ;
		} elsif ((!defined $name)&&(!defined $pname)) {
			if ((defined $params{mode}) && ($params{mode} eq $options{mode})) {
				$layout = $l ;
			} elsif ((defined $params{_DEFAULT})&&($params{_DEFAULT} eq $options{mode})) {
				$layout = $l ;
			}
		}

		$firstlayout = $l unless defined $firstlayout;
	}

	if ((!defined $layout) && ($text=~s/\%STARTRENDERFORMLAYOUT\%(.*?)\%STOPRENDERFORMLAYOUT\%//s)) {
		$layout = $1;
	}

	$layout = $firstlayout unless defined $layout;

	if (!defined $layout) {
		$text =~ s/\%META[^\%]*\%//sg;
		$layout = $text;
	}

	return $layout;
}
# =========================
sub _getSwitchButton {
	my ($theTopic,$theWeb) = @_;
	my $formName = $options{formName};
	my $cgi = TWiki::Func::getCgiQuery();
	my $buttonmode = $options{mode} eq 'view' ? 'edit' : $options{mode} eq 'edit' ? 'view' : '';

	## preserve all query parameters and overwrite some 
	my $newcgi = new CGI($cgi);
	$newcgi->param('rfp_mode',$buttonmode);
	$newcgi->param('rfp_s_formName', $formName);
	$newcgi->param('t',time());
	my $href = $newcgi->self_url()."#$formName";

	
	my $button = $buttonmode ne '' ? $cgi->span({-style=>'font-size: 0.6em;'},
				$cgi->a({-title=>uc($buttonmode),-href=>$href },"[\U$buttonmode form\E]"))
				: "";

	return $button;
}
# =========================
sub _reorderDefs {
	my ($defs,$attr) = @_;
	
	my @newdefs = ( );
	if ($options{order} =~ /\[\:(alpha|dalpha|ralpha|num|dnum|rnum)\:\]/i) {
		my $sfvar = lc($1);
		my @sattr ;
		@sattr = sort { $a cmp $b } keys %{$attr} if ($sfvar eq 'alpha'); 
		@sattr = sort { $b cmp $a } keys %{$attr} if ($sfvar eq 'dalpha') || ($sfvar eq 'ralpha');
		@sattr = sort { _int($a) <=> _int($b) } keys %{$attr} if ($sfvar eq 'num');
		@sattr = sort { _int($b) <=> _int($a) } keys %{$attr} if ($sfvar eq 'dnum') || ($sfvar eq 'rnum');
		for my $a (@sattr) {
			push(@newdefs, $$attr{$a}) if defined $$attr{$a}{name}; 
		}
		
	} else {
		my @order = split(/\s*[,\|\;]\s*/, $options{order}); 
		foreach my $a (@order) {
			push @newdefs, $$attr{$a} if defined $$attr{$a};
		}

		foreach my $def (@{$defs}) {
			push @newdefs, $def unless grep(/^\Q$$def{name}\E$/, @order);
		}
	}

	return \@newdefs;
}
# =========================
sub _renderFormField {
	my ($cgi,$def,$formName) = @_;
	my $td = "";   # form field cell
	my $tadd = ""; # addition to the form field name

	switch ( lc($$def{type}) ) {
		case 'label' { $td = $$def{value}; }
		case 'select' { 
			$td = _renderOptions($def);
			$td = '<select name="'._encode($$def{name}).'" size="'._encode($$def{size}).'">'.$td.'</select>'
				if $options{mode} ne 'view';
		}
		case 'select+multi' { 
			$td = _renderOptions($def);
			$td = '<select multiple="multiple" name="'._encode($$def{name}).'" size="'._encode($$def{size}).'">'.$td.'</select>'
				if $options{mode} ne 'view';
		}
		case 'checkbox+buttons' { 
			$td = _renderButtons($def); 
			$tadd="<br/>".$cgi->button(-value=>"Set all",-onClick=>qq@${formName}CheckAll("$$def{name}",true)@)
					.' '.$cgi->button(-value=>"Clear all", -onClick=>qq@${formName}CheckAll("$$def{name}",false)@ )
				if ($options{mode} ne 'view');
		}
		case 'checkbox' { 
			$td = _renderButtons($def);
		}
		case 'radio' { 
			$td = _renderButtons($def);
		}
		case 'textarea' { 
			$$def{size}=~/(\d+)x(\d+)/i; 
			my ($cols,$rows) = ($1,$2); 
			my $tadata=$$def{value};
			$tadata=~s/%([0-9a-f]{2})/chr(hex("0x$1"))/eig;
			if ($options{mode} eq 'view') {
				$tadata=~s/\r?\n/<br \/>/g;
				$td = $tadata;
				$td = '&nbsp;' if $tadata eq "";
			} else {
				$tadata =~ s/([\r\n])/'&#'.ord($1).';'/eg;
				my $old = $cgi->autoEscape();
				$cgi->autoEscape(0);
				$td = '<noautolink>'.$cgi->textarea({-title=>$$def{tooltip},-rows=>$rows,-columns=>$cols,-name=>$$def{name},-default=>qq@$tadata@}).'</noautolink>';
				$cgi->autoEscape($old);

			}
		}
		case 'date' { 
			if ($options{mode} eq 'view') {
				$td = $$def{value};
				$td = '&nbsp;' if $$def{value} eq "";
			} else {
				my $dateformat = defined $options{dateformat} ? $options{dateformat} : TWiki::Func::getPreferencesValue('JSCALENDARDATEFORMAT');
				$dateformat="%d %b %Y" unless defined $dateformat;
				my $id=$formName.$$def{name}; 
				$td = $cgi->textfield({-id=>$id,-name=>$$def{name},-default=>$$def{value},-size=>$$def{size},-readonly=>'readonly'})
					.$cgi->image_button(-name=>'calendar', -src=>'%PUBURLPATH%/TWiki/JSCalendarContrib/img.gif', 
							-alt=>'Calendar', -title=>'Calendar', -onClick=>qq@javascript: return showCalendar('$id','$dateformat')@);
			}
		}
		else { 
			if ($options{mode} eq 'view') {
				$td = (!defined $$def{value} || $$def{value} eq "") ? "&nbsp;" : $$def{value};
			} else {
				$td = $cgi->textfield({-size=>$$def{size}, -name=>$$def{name}, -default=>$$def{value}});
			}
		}
	}
	return ($td,$tadd);
}
# =========================
sub _createJavaScript {
	my ($mandRef,$formName) = @_;
	my $mandatoryFields= '"'.join('","', map(_encode($_),@{$mandRef})).'"';
	my $text = qq@<noautolink><script type="text/javascript">\n
                    //<!--[
	                function ${formName}CheckAll(name, check) {
				var formname="${formName}";
				for (var i=0; i<document.forms[formname].elements[name].length; i++) {
					document.forms[formname].elements[name][i].checked=check;
				}
			}
			function ${formName}CheckFormData() {
				var formname="$formName";
				var mandatoryFields = new Array(${mandatoryFields});
				var errorFields = new Array();
				for (var i=0; i<mandatoryFields.length; i++) {
					var fieldname = mandatoryFields[i];
					var element = document.forms[formname].elements[mandatoryFields[i]];
					var error = true;

					if (element.options) {
						for (var j=0; j<element.options.length; j++) {
							if (element.options[j].selected == true) { error = false; break; }
						}
					} else if (element.length) {
						for (var j=0; j<element.length; j++) {
							if (element[j].checked == true) { error = false; break; }
						}
						
					} else {
						error = (element.value.search(/^ *\$/)!=-1);
					}
					if (error) errorFields.push(fieldname);
				}

				if (errorFields.length>0) alert("Please fill in mandatory fields: \\n"+errorFields.join(", "));

				return errorFields.length==0;
			}
		    //]-->
	    </script></noautolink>\n@;
	return $text;
}
# =========================
sub _readTopicFormData {
	my($attr,$topic,$theWeb)=@_;
	
	my ($w,$t) = _getWebAndTopic($topic,$theWeb);

	my $data = _readTopicText($w,$t,0);

	my $foundForm=0;
	foreach my $line (split(/[\r\n]/,$data)) {
		if ($line=~/\%META:FORM{(.*?)}\%/) {
			my %params = TWiki::Func::extractParameters($1);
			$foundForm = ($params{name} eq $options{form}) || ($params{name} eq "$theWeb.$options{form}");
			next;
		}

		if ($foundForm &&($line=~/\%META:FIELD{(.*?)}\%/)) {
			my %params = TWiki::Func::extractParameters($1);

			if (defined $$attr{$params{name}} && $$attr{$params{name}}{type} =~ /^(text|textarea|label|date)$/) {
				$$attr{$params{name}}{value}=$params{value};
			} else {
				$$attr{$params{name}}{default}=$params{value};
			}

		}

	}

}
# =========================
sub _encode {
	my ($text) = @_;
	
	$text=~s/\"/\&quot;/g;
	$text=~s/[\r\n]/<br\/>/g;
	#$text=~s/\w/<nop>/g;
	return $text;
}
# =========================
sub _renderButtons {
	my ($def) = @_;
	my $name = $$def{name};
	my $type = $$def{type};
	my $size = $$def{size};
	my $valuesRef = $$def{values};

	my @defaults = defined $$def{default} ? split(/,\s*/, $$def{default}) : ();

	$type='checkbox' if $type=~/^checkbox/;

	my $text = "";
	my $counter = 0;
	foreach my $value (@{$valuesRef}) {
		if ($options{mode} eq 'view') {
			if (grep(/^\Q$$value{name}\E$/,@defaults)) {
				$text .= qq@<span title="@._encode($$value{tooltip}).qq@"> $$value{name} </span>@ ;
			} else {
				$counter--;
			}

		} else {
			my $checked = grep(/^\Q$$value{name}\E$/,@defaults) ? 'checked="ckecked"' : "";
			$text .= '<input '.$checked.' type="'.$type.'" name="'._encode($name).'" title="'._encode($$value{tooltip}).'" value="'._encode($$value{name}).'"> '.$$value{name}.' </input> ';
		}
		$counter++;
		if (($size>0)&&($counter>=$size)) {
			$text .= '<br />';
			$counter=0;
		}
	}
	return $text eq "" ? '&nbsp;' : $text;
}
# =========================
sub _renderOptions {
	my ($defRef) = @_;
	my $text = "";
	my $valuesRef = $$defRef{values};
	my @defaults = defined $$defRef{default} ? split(/,\s*/,$$defRef{default}) : ( );
	foreach  my $value ( @{$valuesRef} ) {
		if ($options{mode} eq 'view') {
			$text.=qq@<span title="@._encode($$value{tooltip}).qq@"> $$value{name} </span>@
				if grep(/^\Q$$value{name}\E$/,@defaults);
		} else {
			my $selected = grep(/^\Q$$value{name}\E$/,@defaults) ? 'selected="selected"' : "";
			$text.='<option '.$selected.' title="'._encode($$value{tooltip}).'"><nop>'.$$value{name}.'</option>';
		}
	}
	return $text eq "" ? '&nbsp;' : $text;
}
# =========================
sub _getWebAndTopic {
	my ($topic, $web) = @_;
	my ($w,$t) = split(/\./, $topic);
	if (!defined $t) {
		$t = $w;
		$w = $web;
	}

	return ($w,$t);
		
}
# =========================
sub _readTWikiFormsDef {
	my ($theWeb) = @_;

	my ($web,$topic) = _getWebAndTopic($options{form}, $theWeb);

	my @defs = ();
	my %attr = ();
	my @mand = ();
	my %titl =  ();


	my $data = _readTopicText($web,$topic);

	foreach my $line (split(/[\r\n]+/, $data)) {
		my @cols = split(/\s*\|\s*/,$line);
		chomp($line);
		next if ($#cols < 3);
		next if $cols[1] =~ /\*[^\*]*\*/; ## ignore header

		my @values = ( );
		my $value = $cols[4];

		if ( !defined $value || $value =~ /^\s*$/ ) {
			@values = @ { _getFormFieldValues($cols[1], $web) } ;
		} else {
			foreach my $name (split(/\s*,\s*/,$value)) {
				push(@values, { name=>$name, type=>'option', tooltip=>$name });
			}
		}

		my $name = $cols[1];
		$name=~s/\W//g;

		push @defs, { name=>$name, title=>$cols[1],  type=>_get($cols[2],'text'), size=>_get($cols[3],80), value=>_get($value,""), values=>\@values, tooltip=>_get($cols[5],$cols[1]), attr=>_get($cols[6],"") };
		$attr{$name}=$defs[$#defs];
		$titl{$cols[1]}=$defs[$#defs];

		push @mand, $name if $defs[$#defs]{attr}=~/M/i;
		
	}
	return (\@defs,\%attr,\@mand,\%titl);
}
# =========================
sub _getFormFieldValues {
	my ($topic, $web) = @_;

	my @values = ();
	my $data = _readTopicText($web,$topic);
	foreach my $line (split(/[\r\n]+/, $data)) {
		chomp($line);
		my @cols = split(/\s*\|\s*/,$line);
		next if $#cols < 1;
		next if $cols[1] =~ /\*[^\*]*\*/;
		push(@values, { name=>$cols[1], value=>$cols[1], type=>_get($cols[2],'option'), tooltip=>_get($cols[3],$cols[1]) });
	}


	return \@values;
}
# =========================
sub _createMissingParamsMessage {
        my $msg;
        $msg = TWiki::Func::getPreferencesValue("MISSINGPARAMSMSG") || undef;
        $msg = $defaults{missingparamsmsg} unless defined $msg;
        $msg =~ s/\%MISSINGPARAMSLIST\%/join(', ', sort @missingParams)/eg;
        $msg =~ s/\%REQUIREDPARAMSLIST\%/join(', ', sort @requiredOptions)/eg;
        return $msg;
}
# =========================
sub _createUnknownParamsMessage {
        my $msg;
        $msg = TWiki::Func::getPreferencesValue("UNKNOWNPARAMSMSG") || undef;
        $msg = $defaults{unknownparamsmsg} unless defined $msg;
        $msg =~ s/\%UNKNOWNPARAMSLIST\%/join(', ', sort @unknownParams)/eg;
        $msg =~ s/\%KNOWNPARAMSLIST\%/join(', ', sort keys %defaults)/eg;
        return $msg;
}
# =========================
sub _createInvalidParamsMessage {
        my $msg;
        $msg = TWiki::Func::getPreferencesValue("INVALIDPARAMSMSG") || undef;
        $msg = $defaults{invalidparamsmsg} unless defined $msg;
        $msg =~ s/\%INVALIDPARAMSLIST\%/join(', ', sort @invalidParams)/eg;
	my $list = "";
	foreach my $p (@invalidParams) {
		$list.="$p=(".join('|',@{$validOptions{$p}}).") ";
	}
        $msg =~ s/\%VALIDPARAMSLIST\%/$list/eg;
        return $msg;
}
# =========================
sub _readTopicText
{
        my( $theWeb, $theTopic, $dontExpand ) = @_;
        my $text = '';
        if( $TWiki::Plugins::VERSION >= 1.010 ) {
                $text = &TWiki::Func::readTopicText( $theWeb, $theTopic, '', 1 );
        } else {
                $text = &TWiki::Func::readTopic( $theWeb, $theTopic );
        }

	#if ((!defined $dontExpand) || (!$dontExpand)) {
		$text =~ s/(\%RENDERFORM{.*?}%)/<verbatim>\n$1<\/verbatim>/g;
		$text =~ s/(\%STARTRENDERFORMLAYOUT.*?STOPRENDERFORMLAYOUT\%)/<verbatim>\n$1\n<\/verbatim>/sg;

		$text = TWiki::Func::expandCommonVariables($text, $theTopic, $theWeb);
	#}
        # return raw topic text, including meta data
        return $text;
}
# =========================
sub _get {
	return defined $_[0] ? $_[0] : $_[1];
}
# =========================
sub _int {
	return  $_[0]=~/(\d+)/ ? $1: ord(substr($_[0],0,1));
}
# =========================
sub _dump {
	eval {
		use Data::Dumper;
		TWiki::Func::writeWarning(Data::Dumper->Dump( \@_ ));
	};
}
1;
