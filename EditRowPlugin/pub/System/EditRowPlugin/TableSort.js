function sortTable(el,rev,headrows,footrows){var tdEl=el;while(tdEl!=null&&tdEl.tagName.toUpperCase()!="TD"&&tdEl.tagName.toUpperCase()!="TH"){tdEl=tdEl.parentNode;}
if(tdEl==null){return;}
var trEl=tdEl;while(trEl!=null&&trEl.tagName.toUpperCase()!="TR"){trEl=trEl.parentNode;}
if(trEl==null){return;}
var tblEl=trEl;while(tblEl!=null&&tblEl.tagName.toUpperCase()!="TABLE"){tblEl=tblEl.parentNode;}
if(tblEl==null){return;}
var col=0;var i=0;while(i<trEl.childNodes.length){if(trEl.childNodes[i].tagName!=null){if(trEl.childNodes[i]==tdEl)
break;col++;}
i++;}
if(i==trEl.childNodes.length){return null;}
var tblBody=null;var gotBody=false;for(var i=0;i<tblEl.childNodes.length;i++){var tn=tblEl.childNodes[i].tagName;if(tn!=null)
tn=tn.toUpperCase();if(tn=="THEAD"){if(gotBody)
footrows-=tblEl.childNodes[i].rows.length;else
headrows-=tblEl.childNodes[i].rows.length;}
else if(tn=="TBODY"){tblBody=tblEl.childNodes[i];gotBody=true;}
else if(tn=="TFOOT"){footrows-=tblEl.childNodes[i].rows.length;}}
if(tblEl.reverseSort==null){tblEl.reverseSort=new Array();tblEl.lastColumn=1;}
if(tblEl.reverseSort[col]==null)
tblEl.reverseSort[col]=rev;if(col==tblEl.lastColumn)
tblEl.reverseSort[col]=!tblEl.reverseSort[col];tblEl.lastColumn=col;var oldDsply=tblEl.style.display;tblEl.style.display="none";var tmpEl;var i,j;var minVal,minIdx;var testVal;var cmp;var start=(headrows>0?headrows:0);var end=tblBody.rows.length-(footrows>0?footrows:0);for(i=start;i<end-1;i++){minIdx=i;minVal=getTextValue(tblBody.rows[i].cells[col]);for(j=i+1;j<end;j++){testVal=getTextValue(tblBody.rows[j].cells[col]);cmp=compareValues(minVal,testVal);if(tblEl.reverseSort[col])
cmp=-cmp;if(cmp>0){minIdx=j;minVal=testVal;}}
if(minIdx>i){tmpEl=tblBody.removeChild(tblBody.rows[minIdx]);tblBody.insertBefore(tmpEl,tblBody.rows[i]);}}
tblEl.style.display=oldDsply;return false;}
if(document.ELEMENT_NODE==null){document.ELEMENT_NODE=1;document.TEXT_NODE=3;}
function getTextValue(el){if(!el)
return'';var i;var s;s="";for(i=0;i<el.childNodes.length;i++)
if(el.childNodes[i].nodeType==document.TEXT_NODE)
s+=el.childNodes[i].nodeValue;else if(el.childNodes[i].nodeType==document.ELEMENT_NODE&&el.childNodes[i].tagName=="BR")
s+=" ";else
s+=getTextValue(el.childNodes[i]);return normalizeString(s);}
var months=new Array();months["jan"]=0;months["feb"]=1;months["mar"]=2;months["apr"]=3;months["may"]=4;months["jun"]=5;months["jul"]=6;months["aug"]=7;months["sep"]=8;months["oct"]=9;months["nov"]=10;months["dec"]=11;var TWIKIDATE=new RegExp("^\\s*([0-3]?[0-9])[-\\s/]*"+
"(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"+
"[-\\s/]*([0-9]{2}[0-9]{2}?)"+
"(\\s*(-\\s*)?([0-9]{2}):([0-9]{2}))?","i");var RFC8601=new RegExp("([0-9]{4})(-([0-9]{2})(-([0-9]{2})"+
"(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?"+
"(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?");function s2d(s){var d=s.match(TWIKIDATE);if(d!=null){var nd=new Date();nd.setDate(Number(d[1]));nd.setMonth(months[d[2].toLowerCase()]);if(d[3].length==2){var year=d[3];if(year>59)
year+=1900;else
year+=2000;nd.setYear(year);}else
nd.setYear(d[3]);if(d[6]!=null&&d[6].length)
nd.setHours(d[6]);if(d[7]!=null&&d[7].length)
nd.setMinutes(d[7]);return nd.getTime();}
var d=s.match(RFC8601);if(d==null)
return 0;var offset=0;var date=new Date(d[1],0,1);if(d[3])date.setMonth(d[3]-1);if(d[5])date.setDate(d[5]);if(d[7])date.setHours(d[7]);if(d[8])date.setMinutes(d[8]);if(d[10])date.setSeconds(d[10]);if(d[12])date.setMilliseconds(Number("0."+d[12])*1000);if(d[14]){offset=(Number(d[16])*60)+Number(d[17]);offset*=((d[15]=='-')?1:-1);}
offset-=date.getTimezoneOffset();time=(Number(date)+(offset*60*1000));return time;}
function compareValues(v1,v2){var d1=s2d(v1);if(d1){var d2=s2d(v2);if(d2){v1=d1;v2=d2;}}else{var f1=parseFloat(v1);if(!isNaN(f1)){var f2=parseFloat(v2);if(!isNaN(f2)){v1=f1;v2=f2;}}}
if(v1==v2)
return 0;if(v1>v2)
return 1;return-1;}
var whtSpEnds=new RegExp("^\\s*|\\s*$","g");var whtSpMult=new RegExp("\\s\\s+","g");function normalizeString(s){s=s.replace(whtSpMult," ");s=s.replace(whtSpEnds,"");return s;}
