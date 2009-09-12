use strict;

# tests for basic formatting

package TablePluginTests;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTableFormattingTestWebTableFormatting';
my $tableCount = 1;

sub new {
    my $self = shift()->SUPER::new( 'TableFormatting', @_ );
    return $self;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{TablePlugin}{Enabled} = 1;
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ( $this, $expected, $actual ) = @_;
    my $session   = $this->{session};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );
    $actual = Foswiki::Func::renderText( $actual, $webName, $topicName );

    $this->assert_html_equals( $expected, $actual );
}

=pod

=cut

sub test_simpleTableusing {
    my $this     = shift;
    
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table id="table$tableCount" class="foswikiTable" rules="rows" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_simpleTheadTableUsingTablePlugin {
    my $this = shift;
    
    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table id="table$tableCount" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" title="Sort by this column">a</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" title="Sort by this column">b</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_simpleTfootTableusingTablePlugin {
    my $this     = shift;
	
    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table id="table$tableCount" class="foswikiTable" rules="rows" border="1">
	<tfoot>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" title="Sort by this column">ok</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol foswikiLast"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" title="Sort by this column">bad</a> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="0" footerrows="1"}%
| a | b |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_doubleTheadTableUsingTablePlugin {
    my $this = shift;
    
    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table id="table$tableCount" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" title="Sort by this column">a</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" title="Sort by this column">b</a> </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> c </th>
			<th class="foswikiTableCol1 foswikiLastCol"> c </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| *c* | *c* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_doubleTheadandTfootTableusingTablePlugin {
    my $this = shift;
    
    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="table$tableCount" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" title="Sort by this column">a</a> </th>
				<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" title="Sort by this column">b</a> </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th class="foswikiTableCol0 foswikiFirstCol"> c </th>
				<th class="foswikiTableCol1 foswikiLastCol"> c </th>
		</tr>
	</thead>
	<tfoot>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
				<th class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </th>
				<th class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<td class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
				<td class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="2" footerrows="1"}%
| *a* | *b* |
| *c* | *c* |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

Test sorting of Size column (format: '1.1 K')

=cut

sub test_sort_size {
    my $this = shift;
    
    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{initsort="3" initdirection="up"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 5.6 K | <span class="foswikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 0.2 K | <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | -0.2 K | <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 10.2 K | <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 3.4 K | <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table rules="rows" border="1" class="foswikiTable" id="table1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" rel="nofollow">Title</a> </th>
			<th class="foswikiTableCol1"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" rel="nofollow">Date</a> </th>
			<th class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=1;up=2#sorted_table" rel="nofollow">Size</a><span class="tableSortIcon tableSortDown"><img width="11" height="13" border="0" title="Sorted descending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortdown.gif" alt="Sorted descending"/></span> </th>
			<th class="foswikiTableCol3 foswikiLastCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=1;up=0#sorted_table" rel="nofollow">Span date</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> jkl </td>
			<td class="foswikiTableCol1" rowspan="1"> 16 Sep 2008 - 09:48 </td>
			<td class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol" rowspan="1"> 10.2 K </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> ABC </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 May 2007 - 22:36 </td>
			<td class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol" rowspan="1"> 5.6 K </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> MNO </td>
			<td class="foswikiTableCol1" rowspan="1"> 06 Feb 2006 - 19:02 </td>
			<td class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol" rowspan="1"> 3.4 K </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> def </td>
			<td class="foswikiTableCol1" rowspan="1"> 07 Feb 2006 - 13:23 </td>
			<td class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol" rowspan="1"> 0.2 K </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast" rowspan="1"> GHI </td>
			<td class="foswikiTableCol1 foswikiLast" rowspan="1"> 26 Jul 2007 - 13:23 </td>
			<td class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol foswikiLast" rowspan="1"> -0.2 K </td>
			<td class="foswikiTableCol3 foswikiLastCol foswikiLast" rowspan="1"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Test sorting of a numbers column

=cut

sub test_sort_numbers {
    my $this = shift;
    
    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{initsort="3" initdirection="down"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 70 | <span class="foswikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 0 | <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | -2 | <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 100 | <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 1.5 | <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table rules="rows" border="1" class="foswikiTable" id="table$tableCount">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" rel="nofollow">Title</a> </th>
			<th class="foswikiTableCol1"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" rel="nofollow">Date</a> </th>
			<th class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=$tableCount;up=1#sorted_table" rel="nofollow">Size</a><span class="tableSortIcon tableSortUp"><img width="11" height="13" border="0" title="Sorted ascending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortup.gif" alt="Sorted ascending"/></span> </th>
			<th class="foswikiTableCol3 foswikiLastCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=$tableCount;up=0#sorted_table" rel="nofollow">Span date</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> GHI </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 Jul 2007 - 13:23 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> -2 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> def </td>
			<td class="foswikiTableCol1" rowspan="1"> 07 Feb 2006 - 13:23 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 0 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> MNO </td>
			<td class="foswikiTableCol1" rowspan="1"> 06 Feb 2006 - 19:02 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 1.5 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> ABC </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 May 2007 - 22:36 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 70 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast" rowspan="1"> jkl </td>
			<td class="foswikiTableCol1 foswikiLast" rowspan="1"> 16 Sep 2008 - 09:48 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol foswikiLast" rowspan="1"> 100 </td>
			<td class="foswikiTableCol3 foswikiLastCol foswikiLast" rowspan="1"> <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Test sorting of Date column with HTML tags before the date

=cut

sub test_sort_dateWithHtml {
    my $this = shift;
    
    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{initsort="4" initdirection="down"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 5.6 K | <span class="foswikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 0.2 K | <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | 0.2 K | <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 10.2 K | <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 3.4 K | <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table rules="rows" border="1" class="foswikiTable" id="table$tableCount">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" rel="nofollow">Title</a> </th>
			<th class="foswikiTableCol1"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" rel="nofollow">Date</a> </th>
			<th class="foswikiTableCol2"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=$tableCount;up=0#sorted_table" rel="nofollow">Size</a> </th>
			<th class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol"> <a title="Sort by this column" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=$tableCount;up=1#sorted_table" rel="nofollow">Span date</a><span class="tableSortIcon tableSortUp"><img width="11" height="13" border="0" title="Sorted ascending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortup.gif" alt="Sorted ascending"/></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> MNO </td>
			<td class="foswikiTableCol1" rowspan="1"> 06 Feb 2006 - 19:02 </td>
			<td class="foswikiTableCol2" rowspan="1"> 3.4 K </td>
			<td class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> def </td>
			<td class="foswikiTableCol1" rowspan="1"> 07 Feb 2006 - 13:23 </td>
			<td class="foswikiTableCol2" rowspan="1"> 0.2 K </td>
			<td class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> ABC </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 May 2007 - 22:36 </td>
			<td class="foswikiTableCol2" rowspan="1"> 5.6 K </td>
			<td class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> GHI </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 Jul 2007 - 13:23 </td>
			<td class="foswikiTableCol2" rowspan="1"> 0.2 K </td>
			<td class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast" rowspan="1"> jkl </td>
			<td class="foswikiTableCol1 foswikiLast" rowspan="1"> 16 Sep 2008 - 09:48 </td>
			<td class="foswikiTableCol2 foswikiLast" rowspan="1"> 10.2 K </td>
			<td class="foswikiTableCol3 foswikiSortedAscendingCol foswikiSortedCol foswikiLastCol foswikiLast" rowspan="1"> <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

1;
