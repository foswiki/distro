describe("foswikiDate", function() {

  it("should be able to parse Foswiki formatted date strings", function() {
    var test, expected;

    test = new Date(foswiki.Date.parseDate('10 Dec 2001 - 18:01'));
    expected = new Date('2001/12/10 18:01');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('10 Dec 2001'));
    expected = new Date('2001/12/10 00:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('10-Dec-2001 - 18:01'));
    expected = new Date('2001/12/10 18:01');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('10-Dec-2001'));
    expected = new Date('2001/12/10 00:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('14 Jan 2012'));
    expected = new Date('2012/01/14 00:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2009-1-12'));
    expected = new Date('2009/01/12 00:00');
    expect(test).toEqual(expected);
  });
  
  it("should be able to parse RCS formatted date strings", function() {
    var test, expected;

    test = new Date(foswiki.Date.parseDate('2001/12/2 18:01:02'));
    expected = new Date('2001/12/02 18:01:02');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001.12.2.01.02.03'));
    expected = new Date('2001/12/02 01:02:03');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001/12/2 21:59'));
    expected = new Date('2001/12/02 21:59');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02 21:59'));
    expected = new Date('2001/12/02 21:59');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02 - 21:59'));
    expected = new Date('2001/12/02 21:59');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02.21:59'));
    expected = new Date('2001/12/02 21:59');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1976.12.2.23.59'));
    expected = new Date('1976/12/02 23:59');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02 18:01:02'));
    expected = new Date('2001/12/02 18:01:02');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02 - 18:01:02'));
    expected = new Date('2001/12/02 18:01:02');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('2001-12-02-18:01:02'));
    expected = new Date('2001/12/02 18:01:02');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('2001-12-02.18:01:02'));
    expected = new Date('2001/12/02 18:01:02');
    expect(test).toEqual(expected);    
  });
  
  it("should be able to parse ISO8601 formatted date strings", function() {
    var test, expected;

    test = new Date(foswiki.Date.parseDate('1995-02-04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1995-02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1995-07-03T20:59:07'));
    expected = new Date('1995/07/03 20:59:07');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1995-07-03T20:59'));
    expected = new Date('1995/07/03 20:59');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995-07-02T23'));
    expected = new Date('1995/07/02 23:00');
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1995-07-02T06:59:07+01:00'));
    expected = new Date('1995/07/02 05:59:07');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995-07-02T06:59:07+01'));
    expected = new Date('1995/07/02 05:59:07');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995-07-02T06:59:07Z'));
    expected = new Date('1995/07/02 06:59:07');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995-04-02T06:59:07+02', 1));
	var tzadj = new Date().getTimezoneOffset() * 60 * 1000;	
    expected = new Date(new Date('1995/04/02 06:59:07').getTime() + tzadj)
    ;
    expect(test).toEqual(expected);
    
    test = new Date(foswiki.Date.parseDate('1995-04-02T06:59:07Z', 1));
    expected = new Date('1995/04/02 06:59:07');
    expect(test).toEqual(expected);
  });

  it("should be able to parse less strict input", function() {
    var test, expected;

    test = new Date(foswiki.Date.parseDate('1995-02-04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995-02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995/02/04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995/02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995.02.04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995.02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995 - 02 -04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995 - 02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995 / 02/04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995 /02'));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995'));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995. 02 .04'));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('1995.02 '));
    expected = new Date('1995/02/01 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate('      1995-02-04 '));
    expected = new Date('1995/02/04 00:00');
    expect(test).toEqual(expected);

    test = new Date(foswiki.Date.parseDate(' 1995 '));
    expected = new Date('1995/01/01 00:00');
    expect(test).toEqual(expected);
  });

  it("should be able to handle erroneous input", function() {
    var test, expected = undefined;

    test = foswiki.Date.parseDate('wibble');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('1234-qwer-');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('1234-qwer-3');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('1234-1234-1234');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('2008^12^12');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('2008--12-23');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('2008-13-23');
    expect(test).toEqual(expected);

    test = foswiki.Date.parseDate('2008-10-32');
    expect(test).toEqual(expected);
  });
});