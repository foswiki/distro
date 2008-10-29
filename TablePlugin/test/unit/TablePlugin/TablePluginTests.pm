use strict;

# tests for basic formatting

package TablePluginTests;

use base qw( TWikiFnTestCase );

use TWiki;
use Error qw( :try );
my $TEST_WEB_NAME = 'TemporaryTableFormattingTestWebTableFormatting';

sub new {
    my $self = shift()->SUPER::new('TableFormatting', @_);
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();
#    $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AntiSpam}{EmailPadding} = 'STUFFED';
    $TWiki::cfg{AllowInlineScript} = 1;
    $ENV{SCRIPT_NAME} = ''; #  required by fake sort URLs in expected text
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_test {
    my ($this, $expected, $actual) = @_;
    my $session = $this->{twiki};
    my $webName = $this->{test_web};
    my $topicName = $this->{test_topic};

    $actual = $session->handleCommonTags( $actual, $webName, $topicName );
    $actual = $session->renderer->getRenderedVersion( $actual, $webName, $topicName );

    $this->assert_html_equals($expected, $actual);
}

sub test_simpleTableusing {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> b </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| a | b |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}


sub test_simpleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
		</tr>
	</tbody>
</table>
EXPECTED
    my $actual = <<ACTUAL;
| *a* | *b* |
| 2 | 3 |
| ok | bad |
ACTUAL
    $this->do_test($expected, $actual);
}

sub test_simpleTfootTableusingTablePlugin {
    my $this = shift;
    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tfoot>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <font color="#ffffff">ok</font> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> a </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> b </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
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
    $this->do_test($expected, $actual);
}

sub test_doubleTheadTableUsingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">a</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">b</font></a> </th>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <font color="#ffffff">c</font> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <font color="#ffffff">c</font> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
			<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> ok </td>
			<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> bad </td>
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
    $this->do_test($expected, $actual);
}

sub test_doubleTheadandTfootTableusingTablePlugin {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <font color="#ffffff">a</font> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <font color="#ffffff">b</font> </th>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">c</font></a> </th>
		</tr>
	</thead>
	<tfoot>
		<tr class="twikiTableEven twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
				<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <font color="#ffffff">ok</font> </th>
				<th bgcolor="#687684" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <font color="#ffffff">bad</font> </th>
		</tr>
	</tfoot>
	<tbody>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
				<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> 2 </td>
				<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> 3 </td>
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
    $this->do_test($expected, $actual);
}

=pod

Test sorting of Size column (format: '1.1 K')

=cut

sub test_sort_size {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);
    my $pubUrlTWikiWeb = TWiki::Func::getPubUrlPath() . '/TWiki';
    
    my $actual = <<ACTUAL;
%TABLE{initsort="3" initdirection="up"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 5.6 K | <span class="twikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 0.2 K | <span class="twikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | 0.2 K | <span class="twikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 10.2 K | <span class="twikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 3.4 K | <span class="twikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Title</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Date</font></a> </th>
			<th bgcolor="#334455" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=1;up=2#sorted_table" title="Sort by this column"><font color="#ffffff">Size</font></a><span class="tableSortIcon tableSortDown"><img width="11" alt="Sorted descending" src="$pubUrlTWikiWeb/TWikiDocGraphics/tablesortdown.gif" title="Sorted descending" height="13" border="0" /></span> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol3 twikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Span date</font></a> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> jkl </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1"> 16 Sep 2008 - 09:48 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol"> 10.2 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol3 twikiLastCol"> <span class="twikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> ABC </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol1"> 26 May 2007 - 22:36 </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol"> 5.6 K </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol3 twikiLastCol"> <span class="twikiNoBreak">26 May 2007 - 22:36</span> </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> MNO </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1"> 06 Feb 2006 - 19:02 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol"> 3.4 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol3 twikiLastCol"> <span class="twikiNoBreak">06 Feb 2006 - 19:02</span> </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> def </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol1"> 07 Feb 2006 - 13:23 </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol"> 0.2 K </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol3 twikiLastCol"> <span class="twikiNoBreak">07 Feb 2006 - 13:23</span> </td>
		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> GHI </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1 twikiLast"> 26 Jul 2007 - 13:23 </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol2 twikiSortedDescendingCol twikiSortedCol twikiLast"> 0.2 K </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol3 twikiLastCol twikiLast"> <span class="twikiNoBreak">26 Jul 2007 - 13:23</span> </td>
		</tr>
	</tbody>
</table>
EXPECTED
    
    $this->do_test($expected, $actual);
}

=pod

Test sorting of Date column with HTML tags before the date

=cut

sub test_sort_dateWithHtml {
    my $this = shift;

    my $cgi = $this->{request};
    my $url = $cgi->url(-absolute => 1);
    my $pubUrlTWikiWeb = TWiki::Func::getPubUrlPath() . '/TWiki';
    
    my $actual = <<ACTUAL;
%TABLE{initsort="4" initdirection="up"}%
| *Title* | *Date* | *Size* | *Span date* |
| ABC | 26 May 2007 - 22:36 | 5.6 K | <span class="twikiNoBreak">26 May 2007 - 22:36</span> |
| def | 07 Feb 2006 - 13:23 | 0.2 K | <span class="twikiNoBreak">07 Feb 2006 - 13:23</span> |
| GHI | 26 Jul 2007 - 13:23 | 0.2 K | <span class="twikiNoBreak">26 Jul 2007 - 13:23</span> |
| jkl| 16 Sep 2008 - 09:48 | 10.2 K | <span class="twikiNoBreak">16 Sep 2008 - 09:48</span> |
| MNO | 06 Feb 2006 - 19:02 | 3.4 K | <span class="twikiNoBreak">06 Feb 2006 - 19:02</span> |
ACTUAL

    my $expected = <<EXPECTED;
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="table1" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<thead>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<th bgcolor="#687684" valign="top" class="twikiTableCol0 twikiFirstCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=0;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Title</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol1"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=1;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Date</font></a> </th>
			<th bgcolor="#687684" valign="top" class="twikiTableCol2"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=2;table=1;up=0#sorted_table" title="Sort by this column"><font color="#ffffff">Size</font></a> </th>
			<th bgcolor="#334455" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol"> <a rel="nofollow" href="$url/$TEST_WEB_NAME/TestTopicTableFormatting?sortcol=3;table=1;up=2#sorted_table" title="Sort by this column"><font color="#ffffff">Span date</font></a><span class="tableSortIcon tableSortDown"><img width="11" alt="Sorted descending" src="$pubUrlTWikiWeb/TWikiDocGraphics/tablesortdown.gif" title="Sorted descending" height="13" border="0" /></span> </th>
		</tr>
	</thead>
	<tbody>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> jkl </td>

			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1"> 16 Sep 2008 - 09:48 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol2"> 10.2 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol"> <span class="twikiNoBreak">16 Sep 2008 - 09:48</span> </td>
		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">

			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> GHI </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol1"> 26 Jul 2007 - 13:23 </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol2"> 0.2 K </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol"> <span class="twikiNoBreak">26 Jul 2007 - 13:23</span> </td>

		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> ABC </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1"> 26 May 2007 - 22:36 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol2"> 5.6 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol"> <span class="twikiNoBreak">26 May 2007 - 22:36</span> </td>

		</tr>
		<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol"> def </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol1"> 07 Feb 2006 - 13:23 </td>
			<td bgcolor="#edf4f9" rowspan="1" valign="top" class="twikiTableCol2"> 0.2 K </td>
			<td bgcolor="#ddebf6" rowspan="1" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol"> <span class="twikiNoBreak">07 Feb 2006 - 13:23</span> </td>

		</tr>
		<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> MNO </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol1 twikiLast"> 06 Feb 2006 - 19:02 </td>
			<td bgcolor="#ffffff" rowspan="1" valign="top" class="twikiTableCol2 twikiLast"> 3.4 K </td>
			<td bgcolor="#f1f7fc" rowspan="1" valign="top" class="twikiTableCol3 twikiSortedDescendingCol twikiSortedCol twikiLastCol twikiLast"> <span class="twikiNoBreak">06 Feb 2006 - 19:02</span> </td>

		</tr>
	</tbody>
</table>
EXPECTED
    
    $this->do_test($expected, $actual);
}

1;
