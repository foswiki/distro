# See bottom of file for license and copyright information
use strict;
use warnings;

# tests for basic formatting

package TablePluginTests;

use FoswikiFnTestCase;
our @ISA = qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTableFormattingTestWebTableFormatting';
my $tableCount    = 1;
my $debug         = 0;

sub new {
    my $self = shift()->SUPER::new( 'TableFormatting', @_ );
    return $self;
}

sub loadExtraConfig {
    my $this = shift;
    $this->SUPER::loadExtraConfig();

    $Foswiki::cfg{Plugins}{TablePlugin}{Enabled} = 1;
    $Foswiki::cfg{Plugins}{TablePlugin}{DefaultAttributes} =
'tableborder="1" valign="top" headercolor="#fff" headerbg="#687684" headerbgsorted="#334455" databg="#ddd,#edf4f9" databgsorted="#f1f7fc,#ddebf6" tablerules="rows" headerrules="cols"';
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

sub test_simpleTable {
    my $this = shift;

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table class="foswikiTable" rules="none" border="1">
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
<table class="foswikiTable" rules="none" border="1">
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

sub test_simpleTfootTableUsingTablePlugin {
    my $this = shift;

    my $cgi      = $this->{request};
    my $url      = $cgi->url( -absolute => 1 );
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}$tableCount" class="foswikiTable" rules="none" border="1">
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
<table class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> a </th>
			<th class="foswikiTableCol1 foswikiLastCol"> b </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column">c</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column">c</a> </th>
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
	</tbody></table>
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

sub test_doubleTheadandTfootTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}$tableCount" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th class="foswikiTableCol0 foswikiFirstCol"> a </th>
				<th class="foswikiTableCol1 foswikiLastCol"> b </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=$tableCount;up=0#sorted_table" title="Sort by this column">c</a> </th>
				<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=$tableCount;up=0#sorted_table" title="Sort by this column">d</a> </th>
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
| *c* | *d* |
| 2 | 3 |
| *ok* | *bad* |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

=cut

sub test_onlyHeaderRow {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<table class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column">a</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol foswikiLast"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column">b</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr style="display:none;">
			<td></td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
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
<table rules="none" border="1" class="foswikiTable" id="table$this->{test_topic}$tableCount">
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
<table rules="none" border="1" class="foswikiTable" id="table$this->{test_topic}$tableCount">
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

Test sorting of a numbers column with additional strings. One cell is empty.

=cut

sub test_sort_numbers_with_strings_mixed {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="on" initsort="1"}%
| *Number of things* |
| 1 thingy |
| 10.1 thingies |
| -1.1 thingies |
| 9.99 thingies |
| 2 thingies |
| 2.0 thingies |
| |
| 20 thingies |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=1#sorted_table" title="Sort by this column">Number of things</a><span class="tableSortIcon tableSortUp"><img width="11" alt="Sorted ascending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortup.gif" title="Sorted ascending" height="13" border="0" /></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> &nbsp; </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> -1.1 thingies </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 1 thingy </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2 thingies </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2.0 thingies </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 9.99 thingies </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 10.1 thingies </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol foswikiLast"> 20 thingies </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Test sorting of a numbers column that contains an empty cell and a cell with a string.

=cut

sub test_sort_numbers__mixed {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="on" initsort="1"}%
| *Mostly numbers* |
| -1 |
| 0 |
| 1 |
| ls -al |
|  |
| 3 |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=1#sorted_table" title="Sort by this column">Mostly numbers</a><span class="tableSortIcon tableSortUp"><img width="11" alt="Sorted ascending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortup.gif" title="Sorted ascending" height="13" border="0" /></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> &nbsp; </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> -1 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 0 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 1 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol foswikiLast"> ls -al </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Test sorting of a numbers column that contains an empty cell and a cell with a string.

Note that we cannot interpret 4 digit numbers as dates because thet goofs up normal number
sorting of 4 digit numbers that have nothing to do with dates (Item9374)

=cut

sub test_sort_dates {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="on" initsort="1"}%
| *Dates* |
| 2001/12/27 23:59:59 |
| 2001.12.26.23.59.59 |
| 2001/12/28 23:59 |
| 2001.12.30.23.59 |
| 2001-12-31 23:59 |
| 2001-12-29 - 23:59 |
| 2009-1-12 |
| 2009-1 |
| 2009-2 |
| 2001-12-25T23:59:59 |
| 2001-12-24T |
| 2001-12-22T23:59:59+01:00 |
| 2001-12-23T23:59Z |
| 01 Jan 1970 |
| 31 Dec 1969 - 23:59 |
| 21 Dec 2001 |
| 18-Dec-2001 |
| 20 Dec 2001 - 23:59 |
| 19-Dec-2001 - 23:59 |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=1#sorted_table" title="Sort by this column">Dates</a><span class="tableSortIcon tableSortUp"><img width="11" alt="Sorted ascending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortup.gif" title="Sorted ascending" height="13" border="0" /></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 31 Dec 1969 - 23:59 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 01 Jan 1970 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 18-Dec-2001 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 19-Dec-2001 - 23:59 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 20 Dec 2001 - 23:59 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 21 Dec 2001 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-22T23:59:59+01:00 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-23T23:59Z </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-24T </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-25T23:59:59 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001.12.26.23.59.59 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001/12/27 23:59:59 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001/12/28 23:59 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-29 - 23:59 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001.12.30.23.59 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2001-12-31 23:59 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2009-1 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol"> 2009-1-12 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLastCol foswikiLast"> 2009-2 </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Test sorting of 4 digit numbers making sure they are not misinterpreted as dates (Item9374)

=cut

sub test_sort_4_digit_numbers {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{initsort="3" initdirection="down"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 1704 | <span class="foswikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 1009 | <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | 0735 | <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 2002 | <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 1209 | <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table rules="none" border="1" class="foswikiTable" id="table$this->{test_topic}$tableCount">
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
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 0735 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> def </td>
			<td class="foswikiTableCol1" rowspan="1"> 07 Feb 2006 - 13:23 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 1009 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> MNO </td>
			<td class="foswikiTableCol1" rowspan="1"> 06 Feb 2006 - 19:02 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 1209 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol" rowspan="1"> ABC </td>
			<td class="foswikiTableCol1" rowspan="1"> 26 May 2007 - 22:36 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol" rowspan="1"> 1704 </td>
			<td class="foswikiTableCol3 foswikiLastCol" rowspan="1"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast" rowspan="1"> jkl </td>
			<td class="foswikiTableCol1 foswikiLast" rowspan="1"> 16 Sep 2008 - 09:48 </td>
			<td class="foswikiTableCol2 foswikiSortedAscendingCol foswikiSortedCol foswikiLast" rowspan="1"> 2002 </td>
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
<table rules="none" border="1" class="foswikiTable" id="table$this->{test_topic}$tableCount">
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

sub test_sort_off {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="off"}%
| *Title* | *Date* | *Size* | *Span date* |
| def | 07 Feb 2006 - 13:23 |
| jkl| 16 Sep 2008 - 09:48 |
| GHI | 26 Jul 2007 - 13:23 |
| ABC | 26 May 2007 - 22:36 |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> Title </th>
			<th class="foswikiTableCol1"> Date </th>
			<th class="foswikiTableCol2"> Size </th>
			<th class="foswikiTableCol3 foswikiLastCol"> Span date </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> def </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 07 Feb 2006 - 13:23 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol"> jkl </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 16 Sep 2008 - 09:48 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> GHI </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 26 Jul 2007 - 13:23 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ABC </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 26 May 2007 - 22:36 </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Item11083: Table should sort if sort is off but initsort has a column number 

=cut

sub test_sort_off_initsort {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="off" initsort="  1  "}%
| *Title* | *Date* | *Size* | *Span date* |
| def | 07 Feb 2006 - 13:23 |
| jkl| 16 Sep 2008 - 09:48 |
| GHI | 26 Jul 2007 - 13:23 |
| ABC | 26 May 2007 - 22:36 |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> Title </th>
			<th class="foswikiTableCol1"> Date </th>
			<th class="foswikiTableCol2"> Size </th>
			<th class="foswikiTableCol3 foswikiLastCol"> Span date </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> ABC </td>
			<td rowspan="1" class="foswikiTableCol1 foswikiLastCol"> 26 May 2007 - 22:36 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> def </td>
			<td rowspan="1" class="foswikiTableCol1 foswikiLastCol"> 07 Feb 2006 - 13:23 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol"> GHI </td>
			<td rowspan="1" class="foswikiTableCol1 foswikiLastCol"> 26 Jul 2007 - 13:23 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td rowspan="1" class="foswikiTableCol0 foswikiSortedAscendingCol foswikiSortedCol foswikiFirstCol foswikiLast"> jkl </td>
			<td rowspan="1" class="foswikiTableCol1 foswikiLastCol foswikiLast"> 16 Sep 2008 - 09:48 </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}

=pod

Item11083: second test, with invalid column

=cut

sub test_sort_off_initsort_invalid_col {
    my $this = shift;

    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $actual = <<ACTUAL;
%TABLE{sort="off" initsort="  0  "}%
| *Title* | *Date* | *Size* | *Span date* |
| def | 07 Feb 2006 - 13:23 |
| jkl| 16 Sep 2008 - 09:48 |
| GHI | 26 Jul 2007 - 13:23 |
| ABC | 26 May 2007 - 22:36 |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="none" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th class="foswikiTableCol0 foswikiFirstCol"> Title </th>
			<th class="foswikiTableCol1"> Date </th>
			<th class="foswikiTableCol2"> Size </th>
			<th class="foswikiTableCol3 foswikiLastCol"> Span date </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> def </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 07 Feb 2006 - 13:23 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol"> jkl </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 16 Sep 2008 - 09:48 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> GHI </td>
			<td class="foswikiTableCol1 foswikiLastCol"> 26 Jul 2007 - 13:23 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ABC </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 26 May 2007 - 22:36 </td>
		</tr>
	</tbody></table>
EXPECTED

    $this->do_test( $expected, $actual );
}


=pod

Includes a topic that has an EDITTABLE with param 'include' set: the table definition is in a third topic.

=cut

sub test_INCLUDE_include {
    my $this = shift;

    # Create topic with table definition
    my $tableDefTopic = "QmsCommentTable";
    Foswiki::Func::saveTopic( $this->{test_web}, $tableDefTopic, undef, <<THIS);
%TABLE{ tablerules="all" datacolor="#f00" tableborder="5" }%
THIS

    my $includeTopic = "ProcedureSysarch000Comments";
    Foswiki::Func::saveTopic( $this->{test_web}, $includeTopic, undef, <<THIS);
%TABLE{ include="QmsCommentTable" }%
|*A*|*B*|
| a | b |
THIS

    # include this in our test topic
    my $topicName       = $this->{test_topic};
    my $webName         = $this->{test_web};
    my $cgi             = $this->{request};
    my $url             = $cgi->url( -absolute => 1 );
    my $pubUrlSystemWeb = Foswiki::Func::getPubUrlPath() . '/System';

    my $input = '%INCLUDE{"ProcedureSysarch000Comments"}%';

    my $expected = <<END;
<nop>
<nop>
<nop>
<table id="tableTestTopicTableFormatting1" class="foswikiTable" rules="all" border="5">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0 foswikiTableRowdataColor0">
			<th class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/$topicName?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column">A</a> </th>
			<th class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/$topicName?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column">B</a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0 foswikiTableRowdataColor0">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> b </td>
		</tr>
	</tbody></table>
END

    my $result =
      Foswiki::Func::expandCommonVariables( $input, $topicName, $webName );
    _trimSpaces($expected);
    _trimSpaces($result);
    $this->do_test( $expected, $result );
}

=pod

This test should set table attribute sort="off" in WebPreferences, so that table sorting is disabled. But I can't get it to work.

=cut

=pod
sub test_pluginAttributes {
	my $this = shift;
	
    my $meta =
      Foswiki::Meta->new( $this->{session}, "$this->{test_web}",
        'WebPreferences' );
    $meta->text('   * Set TABLEPLUGIN_TABLEATTRIBUTES = sort="off"');
    $meta->save();

    # Have to restart to clear prefs cache
    $this->{session}->finish();
    $this->{session} =
      new Foswiki( $this->{test_user_login}, new Unit::Request() );
    $Foswiki::Plugins::SESSION = $this->{session};
    
    my $cgi      = $this->{request};
    my $url      = $cgi->url( -absolute => 1 );
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table class="foswikiTable" rules="none" border="1">
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
%TABLE{}%
| *a* | *b* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test( $expected, $actual );
}
=cut

=pod

Tests that two tables have IDs suffixed by 1 and 2

=cut

sub test_tableIdNumbering {
    my $this = shift;

    my $cgi      = $this->{request};
    my $url      = $cgi->url( -absolute => 1 );
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 3 </td>
		</tr>
	</tbody>
</table>
<p></p>
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}2" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 3 </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="0" footerrows="0"}%
| a | b |
| 2 | 3 |

%TABLE{headerrows="0" footerrows="0"}%
| a | b |
| 2 | 3 |
ACTUAL
    $this->do_test( $expected, $actual );
}

=pod

Tests that two tables have IDs suffixed by 1 and 1 if the 
initialiseWhenRender is called between two calls to Foswiki::Func::renderText
(as used by rdiff and CompareRevisionsAddOn) where two revisions of same topic
is called twice.

This test also tests the initialiseWhenRender API call

=cut

sub test_tableIdNumberingInitialiseWhenRender {
    my $this = shift;

    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};
    my $expected  = <<EXPECTED;
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 3 </td>
		</tr>
	</tbody>
</table>
<nop>
<nop>
<nop>
<table id="table$this->{test_topic}1" class="foswikiTable" rules="none" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td class="foswikiTableCol0 foswikiFirstCol foswikiLast"> 2 </td>
			<td class="foswikiTableCol1 foswikiLastCol foswikiLast"> 3 </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
%TABLE{headerrows="0" footerrows="0"}%
| a | b |
| 2 | 3 |

ACTUAL

    # We render the same table twice and append the result
    my $actual1 =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );

    $actual1 = Foswiki::Func::renderText( $actual1, $webName, $topicName );

    # Resetting the table counter (the objective of this test)
    Foswiki::Plugins::TablePlugin::initialiseWhenRender();

    my $actual2 =
      Foswiki::Func::expandCommonVariables( $actual, $topicName, $webName );

    $actual2 = Foswiki::Func::renderText( $actual2, $webName, $topicName );

    $this->assert_html_equals( $expected, $actual1 . $actual2 );
}

# DEVELOPMENT TESTS

sub dev_test_convertStringToNumber_empty_string {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = '    ';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = undef;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToNumber_number_int {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = '1';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 1;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '0';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 0;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '-1';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = -1;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToNumber_number_float {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = '1.1';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 1.1;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '9.999';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 9.999;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '-9.999';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = -9.999;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '0.000';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 0;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToNumber_number_with_string {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = '1K';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 1;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '1 thing';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 1;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );

    $text = '9.99 kilos';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 9.99;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToNumber_ip_string {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = '1.1.1.1';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = undef;
    $this->assert_equals( $expected, $result );

    $text = '1.1.1.1 IP address';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = undef;
    $this->assert_equals( $expected, $result );

    $text = '1.1';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = 1.1;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToNumber_string {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $number );

    $text = 'thing';
    $number =
      Foswiki::Plugins::TablePlugin::Core::_convertStringToNumber($text);
    $result   = $number;
    $expected = undef;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToDate_date_string_1 {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $date );

    $text   = '12 Dec 2001';
    $date   = Foswiki::Plugins::TablePlugin::Core::_convertStringToDate($text);
    $result = $date;
    $expected = 1008115200;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToDate_date_string_2 {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $date );

    $text   = '2001-1';
    $date   = Foswiki::Plugins::TablePlugin::Core::_convertStringToDate($text);
    $result = $date;
    $expected = 978307200;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToDate_year {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $date );

    $text   = '2001';
    $date   = Foswiki::Plugins::TablePlugin::Core::_convertStringToDate($text);
    $result = $date;
    $expected = 978307200;
    print("RES=$result.\n")   if $debug;
    print("EXP=$expected.\n") if $debug;
    $this->assert_equals( $expected, $result );
}

sub dev_test_convertStringToDate_year_before_1970 {
    my $this = shift;

    use Foswiki::Plugins::TablePlugin::Core;
    my ( $text, $result, $expected, $date );

    $text   = '1940';
    $date   = Foswiki::Plugins::TablePlugin::Core::_convertStringToDate($text);
    $result = $date;
    $expected = undef;

    $this->assert_equals( $expected, $result );
}

sub _trimSpaces {

    #my $text = $_[0]

    $_[0] =~ s/^[[:space:]]+//s;    # trim at start
    $_[0] =~ s/[[:space:]]+$//s;    # trim at end
}

1;
__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2011 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
