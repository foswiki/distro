# See bottom of file for license and copyright information

package Foswiki::Configure::TemplateParser::SimpleFreeMarker;

use strict;
use warnings;

use Foswiki::Configure::TemplateParser ();
our @ISA = ('Foswiki::Configure::TemplateParser');

my $PATTERN_LOGICAL_OPERATORS    = '\|\||&&|!';
my $PATTERN_COMPARISON_OPERATORS = '!=|==|<|>|<=|>=|=';

=pod

parse( $templateText, \%keyValues ) 

Example:

$parser->parse( $text, {
	'depth' => $depth,
	'headline' => $headline,
});	

FreeMarker macros like ${depth} are substituted with the value of $depth.

=cut

sub parse {

    #my $this = $_[0]
    #my $template = $_[1]
    #my $keyValues = $_[2]

    # remove <#-- ... --> comments
    $_[1] =~ s/\<\#--.*?--\>//gos;

    my $pattern = '
      \<                    # open tag
      \#                    # #
      [[:space:]]*          # any space
      (if|list|assign)      # i1: operator
      [[:space:]]*          # any space
      (.*?)                 # i2: expression
      [[:space:]]*          # any space
      \>                    # close tag
      (.*?)                 # i3: contents
      \<                    # open tag
      /#                    # /#
      [[:space:]]*          # any space
      \\1                   # reference to operator
      [[:space:]]*          # any space
      \>                    # close tag
      ';
    _stripCommentsFromRegex($pattern);

    #Foswiki::log("pattern=$pattern");

    $_[1] =~ s/$pattern/$_[0]->_evaluateExpression($1, $2, $3, $_[2])/ges;

    while ( my ( $key, $value ) = each %{ $_[2] } ) {
        $value = '' if !defined $value;    # preserve 0 value
                                           # simple key-value substitution
        $_[1] =~ s/\$\{$key\}/$value/gs;
    }

    $_[1] =~ s/\$\{(.*?)(\?.*?)\}/_handleQueryExpressions($1,$2,$_[2])/ges;

}

=pod

=cut

sub _evaluateExpression {
    my ( $this, $operator, $rawExpression, $contents, $keyValues ) = @_;

    return '' if !$operator;

    my $method = '_operator_' . $operator;
    die "Undefined operator method $method" unless defined(&$method);

    no strict 'refs';
    my $result = &$method( $this, $rawExpression, $contents, $keyValues );
    use strict 'refs';

    return $result;
}

=pod

See http://freemarker.org/docs/ref_directive_if.html

Not implemented:
<#elseif statement>

Not implemented:
nested if statements

=cut

sub _operator_if {
    my ( $this, $rawExpression, $contents, $keyValues ) = @_;

#Foswiki::log("_operator_if; rawExpression=$rawExpression \ncontents=$contents");

    # substitute entity references for arithmetical comparisons.
    $rawExpression =~ s/&lt;/</go;
    $rawExpression =~ s/ lt / < /go;
    $rawExpression =~ s/ lte / <= /go;
    $rawExpression =~ s/&gt;/>/go;
    $rawExpression =~ s/ gt / > /go;
    $rawExpression =~ s/ gte / >= /go;
    $rawExpression =~ s/ = / == /go;

    # note: does not handle parenthesis
    my @expressions = _getExpressions($rawExpression);

    foreach my $e (@expressions) {
        if ( not $e =~ m/($PATTERN_LOGICAL_OPERATORS)/ ) {
            $e = _handleSubExpression( $e, $keyValues );
        }
    }

    my $logicalString = join( ' ', @expressions );
    my $evaluation = eval($logicalString);

    #Foswiki::log("\t logicalString=$logicalString");
    #Foswiki::log("\t evaluation=$evaluation") if $evaluation;

    my $result;

    if ( $contents =~
m/^[[:space:]]*(.*?)[[:space:]]*((?:\<\#else\>)[[:space:]]*(.*?))*[[:space:]]*$/s
      )
    {

        # else statement
        $result = $evaluation ? $1 : ( defined $3 ? $3 : '' );
    }
    else {

        # no else
        $result = $evaluation ? $contents : '';
    }

    #Foswiki::log("\t result=$result");

    $this->parse( $result, $keyValues );

    return $result;
}

=pod

See http://freemarker.org/docs/ref_directive_list.html

Not implemented: sequence notation:
["winter", "spring", "summer", "autumn"]

Not implemented:
<#break>

=cut

sub _operator_list {
    my ( $this, $rawExpression, $contents, $keyValues ) = @_;

    #Foswiki::log("rawExpression=$rawExpression");
    #Foswiki::log("contents=$contents");

    my $list = '';
    if ( $rawExpression =~ m/^(.*?)[[:space:]]*as[[:space:]]*(.*?)$/s ) {
        my $itemsRef = _getValue( $1, $keyValues );
        my @items = @{$itemsRef};
        return '' if !scalar @items;

        _trimSpaces($contents);
        my $local = $2;

        foreach my $item (@items) {
            my $listItem = $contents;

            # get property
            $listItem =~ s/\${$local\}/$item/g;
            $listItem =~ s/\${$local\.(.*?)\}/
              defined $item->{$1} ? $item->{$1} : ''/ge;
            $list .= $listItem;
        }
    }
    return $list;
}

=pod

See http://freemarker.org/docs/ref_directive_assign.html

Currently only implemented:

<#assign name>
  capture this
</#assign>

=cut

sub _operator_assign {
    my ( $this, $rawExpression, $contents, $keyValues ) = @_;

    my $name = $rawExpression;
    _trimSpaces($name);
    _trimSpaces($contents);
    $this->parse( $contents, $keyValues );
    $keyValues->{$name} = $contents;

    return '';
}

=pod

=cut

sub _getExpressions {
    my ($expression) = @_;

    return ( split /($PATTERN_LOGICAL_OPERATORS)/, $expression );
}

=pod

=cut

sub _handleSubExpression {
    my ( $expression, $keyValues ) = @_;

    #Foswiki::log("_handleSubExpression: $expression");

    # ?? (exists) syntax
    return $expression
      if $expression =~
      s/([[:alnum:]]+)(\?\?)/_valueExists($1, $keyValues) ? 1 : 0/e;

    # size propery
    return $expression
      if $expression =~ s/(.*?)\.size/scalar @{_getValue($1, $keyValues)}/e;

    # comparison operators
    return $expression
      if $expression =~
s/[[:space:]]*([[:alnum:]]+)[[:space:]]*($PATTERN_COMPARISON_OPERATORS)[[:space:]]*(.*?)/_handleComparison($1, $2, $3, $keyValues)/ge;
}

=pod

=cut

sub _handleComparison {
    my ( $left, $operator, $right, $keyValues ) = @_;

    my $value = _getValue( $left, $keyValues );
    if ( _isNumber($value) ) {
        $operator = '==' if $operator eq 'eq';
        $operator = '!=' if $operator eq 'ne';
    }
    else {
        $operator = 'eq' if $operator eq '==';
        $operator = 'ne' if $operator eq '!=';
    }
    return "$value $operator $right";
}

=pod

_handleQueryExpressions($key, $query, \%keyValues) -> $text

Only implemented:

replace (string): replace text string by another text string
syntax: text?replace("from", "to")
	
join (array): join elements from a list
syntax: list?join(",")

=cut

sub _handleQueryExpressions {
    my ( $key, $query, $keyValues ) = @_;

    my $text = _getValue( $key, $keyValues );
    return '' if !$text;

    # from left to right
    while ( $query =~ s/\?(replace|join)+(\((.*?)\))*// ) {
        my $subName = "_handleQuery_$1";
        my $sub_ref = \&$subName;
        $text = $sub_ref->( $text, $3, $keyValues );
    }

    return $text;
}

sub _handleQuery_replace {
    my ( $text, $expression ) = @_;

    # preserve quotes
    my $quotedPattern =
'(?-xism:((\")([^\\\"]*(?:\\.[^\\\"]*)*)(\")|(\')([^\\\']*(?:\\.[^\\\']*)*)(\')|(\`)([^\\\`]*(?:\\.[^\\\`]*)*)(\`)))';

    if ( $expression =~ m/($quotedPattern)[,[:space:]]*($quotedPattern)/ ) {
        my $from = $4  || '';
        my $to   = $15 || '';
        $text =~ s/$from/$to/gs;
    }

    return $text;
}

sub _handleQuery_join {
    my ( $array, $expression ) = @_;

    return join( $expression, @{$array} );
}

sub _handleReplace {
    my ( $text, $replaceThis, $withThis ) = @_;

    $text        ||= '';
    $replaceThis ||= '';
    $withThis    ||= '';
    $text =~ s/$replaceThis/$withThis/gs;

    return $text;
}

=pod

_getValue( $key, \%keyValues ) => $value

Gets the value from the $keyValues hash.
Dies if the key was not found - see
http://fmpp.sourceforge.net/freemarker/app_faq.html#faq_picky_about_missing_vars
("Why is FreeMarker so picky about null-s and missing variables, and what to do with it?")

=cut

sub _getValue {
    my ( $key, $keyValues ) = @_;

    return $key if _isNumber($key);

    die "No key-values passed" if !defined $keyValues;
    use Data::Dumper;
    die( "Variable '$key' not found:" . Dumper($keyValues) )
      if !defined $keyValues->{$key};

    my $value = $keyValues->{$key};

    return $value if _isNumber($value);
    return undef if $value eq '';
    return $value;
}

sub _valueExists {
    my ( $key, $keyValues ) = @_;

    return defined $keyValues->{$key};
}

sub _isNumber {
    my ($n) = @_;

    eval {
        local $SIG{__WARN__} = sub { die $_[0] };
        $n += 0;
    };
    if   ($@) { return 0; }
    else      { return 1; }

}

=pod

cleanupTemplateResidues( $templateText )

Removes remaining template rubble.

=cut

sub cleanupTemplateResidues {

    #my $this = $_[0]
    #my $template = $_[1]

    # remove <#-- ... --> comments
    $_[1] =~ s/\<\#--.*?--\>//go;

# handle <#if>...<#else>...<#/if> statements
# drop if value is empty
#$_[1] =~ s/\<\#(if)\s*(.*?)\s*\>(.*?)(\<\#else\>(.*?))*\<\/\#\1\>/$2 ? $3 : ($4 ? $5 : '')/gse;

    # drop unresolved template code
    #$_[1] =~ s/\<\#(.*?)(.*?)\>(.*?)\<\/\#\1\>//gs;

    # drop unresolved variable names
    #$_[1] =~ s/\$\{.*?\}//go;

    # remove duplicate newlines
    $_[1] =~ s/[\n]+/\n/go;
}

sub _stripCommentsFromRegex {

    #my $regex = $_[0]

    $_[0] =~ s/\s*(.*?)\s+(#.*?)*(\r|\n|$)/$1/go;
}

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2010 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

Additional copyrights apply to some or all of the code in this
file as follows:

Copyright (C) 2000-2006 TWiki Contributors. All Rights Reserved.
TWiki Contributors are listed in the AUTHORS file in the root
of this distribution. NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
