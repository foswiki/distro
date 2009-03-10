use strict;

# tests for basic formatting

package TablePluginTests;

use base qw( FoswikiFnTestCase );

use Foswiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTableFormattingTestWebTableFormatting';

sub new {
    my $self = shift()->SUPER::new( 'TableFormatting', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    #    $this->{sup} = $this->{session}->getScriptUrl(0, 'view');
    $Foswiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $Foswiki::cfg{AntiSpam}{EmailPadding}     = 'STUFFED';
    $Foswiki::cfg{AllowInlineScript}          = 1;
    $ENV{SCRIPT_NAME} = '';    #  required by fake sort URLs in expected text
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

sub test_simpleTableusing {
    my $this     = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
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

sub test_simpleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
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

sub test_simpleTfootTableusingTablePlugin {
    my $this     = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<tfoot>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <font color="#ffffff">ok</font> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol"> b </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol1 foswikiLastCol"> 3 </td>
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

sub test_doubleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url( -absolute => 1 );

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <font color="#ffffff">c</font> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol"> <font color="#ffffff">c</font> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol"> 3 </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="foswikiTableCol1 foswikiLastCol foswikiLast"> bad </td>
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
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <font color="#ffffff">a</font> </th>
				<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol"> <font color="#ffffff">b</font> </th>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
				<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
		</tr>
	</thead>
	<tfoot>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
				<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> <font color="#ffffff">ok</font> </th>
				<th bgcolor="#687684" valign="top" class="foswikiTableCol1 foswikiLastCol foswikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
				<td bgcolor="#ffffff" valign="top" class="foswikiTableCol0 foswikiFirstCol"> 2 </td>
				<td bgcolor="#ffffff" valign="top" class="foswikiTableCol1 foswikiLastCol"> 3 </td>
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
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Title</font></a> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Date</font></a> </th>
			<th bgcolor="#334455" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=1;up=2#sorted_table" title="Sort by this column"><font color="#ffffff">Size</font></a><span class="tableSortIcon tableSortDown"><img width="11" alt="Sorted descending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortdown.gif" title="Sorted descending" height="13" border="0" /></span> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol3 foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Span date</font></a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> jkl </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1"> 16 Sep 2008 - 09:48 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> 10.2 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol3 foswikiLastCol"> <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> ABC </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol1"> 26 May 2007 - 22:36 </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> 5.6 K </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol3 foswikiLastCol"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> MNO </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1"> 06 Feb 2006 - 19:02 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> 3.4 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol3 foswikiLastCol"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> def </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol1"> 07 Feb 2006 - 13:23 </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol"> 0.2 K </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol3 foswikiLastCol"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> GHI </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1 foswikiLast"> 26 Jul 2007 - 13:23 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol2 foswikiSortedDescendingCol foswikiSortedCol foswikiLast"> 0.2 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol3 foswikiLastCol foswikiLast"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
	</tbody>
</table>
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
%TABLE{initsort="4" initdirection="up"}%
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
<table cellspacing="0" id="table1" cellpadding="0" class="foswikiTable" rules="rows" border="1">
	<thead>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="foswikiTableCol0 foswikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Title</font></a> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol1"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Date</font></a> </th>
			<th bgcolor="#687684" valign="top" class="foswikiTableCol2"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Size</font></a> </th>
			<th bgcolor="#334455" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=1;up=2#sorted_table" title="Sort by this column"><font color="#ffffff">Span date</font></a><span class="tableSortIcon tableSortDown"><img width="11" alt="Sorted descending" src="$pubUrlSystemWeb/DocumentGraphics/tablesortdown.gif" title="Sorted descending" height="13" border="0" /></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> jkl </td>

			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1"> 16 Sep 2008 - 09:48 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol2"> 10.2 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol"> <span class="foswikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">

			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> GHI </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol1"> 26 Jul 2007 - 13:23 </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol2"> 0.2 K </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol"> <span class="foswikiNoBreak">26 Jul 2007 - 13:23</span> </td>

		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> ABC </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1"> 26 May 2007 - 22:36 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol2"> 5.6 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol"> <span class="foswikiNoBreak">26 May 2007 - 22:36</span> </td>

		</tr>
		<tr class="foswikiTableOdd foswikiTableRowdataBgSorted1 foswikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol"> def </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol1"> 07 Feb 2006 - 13:23 </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="foswikiTableCol2"> 0.2 K </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol"> <span class="foswikiNoBreak">07 Feb 2006 - 13:23</span> </td>

		</tr>
		<tr class="foswikiTableEven foswikiTableRowdataBgSorted0 foswikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol0 foswikiFirstCol foswikiLast"> MNO </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol1 foswikiLast"> 06 Feb 2006 - 19:02 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="foswikiTableCol2 foswikiLast"> 3.4 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="foswikiTableCol3 foswikiSortedDescendingCol foswikiSortedCol foswikiLastCol foswikiLast"> <span class="foswikiNoBreak">06 Feb 2006 - 19:02</span> </td>

		</tr>
	</tbody>
</table>
EXPECTED

    $this->do_test( $expected, $actual );
}

1;
