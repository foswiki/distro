jQuery.validator.addMethod("maxWords",function(value,element,params){return this.optional(element)||value.match(/\b\w+\b/g).length<params;},"Please enter {0} words or less.");jQuery.validator.addMethod("minWords",function(value,element,params){return this.optional(element)||value.match(/\b\w+\b/g).length>=params;},"Please enter at least {0} words.");jQuery.validator.addMethod("rangeWords",function(value,element,params){return this.optional(element)||value.match(/\b\w+\b/g).length>=params[0]&&value.match(/bw+b/g).length<params[1];},"Please enter between {0} and {1} words.");jQuery.validator.addMethod("letterswithbasicpunc",function(value,element){return this.optional(element)||/^[a-z-.,()'\"\s]+$/i.test(value);},"Letters or punctuation only please");jQuery.validator.addMethod("alphanumeric",function(value,element){return this.optional(element)||/^\w+$/i.test(value);},"Letters, numbers, spaces or underscores only please");jQuery.validator.addMethod("lettersonly",function(value,element){return this.optional(element)||/^[a-z]+$/i.test(value);},"Letters only please");jQuery.validator.addMethod("nowhitespace",function(value,element){return this.optional(element)||/^\S+$/i.test(value);},"No white space please");jQuery.validator.addMethod("ziprange",function(value,element){return this.optional(element)||/^90[2-5]\d\{2}-\d{4}$/.test(value);},"Your ZIP-code must be in the range 902xx-xxxx to 905-xx-xxxx");jQuery.validator.addMethod("vinUS",function(v){if(v.length!=17)
return false;var i,n,d,f,cd,cdv;var LL=["A","B","C","D","E","F","G","H","J","K","L","M","N","P","R","S","T","U","V","W","X","Y","Z"];var VL=[1,2,3,4,5,6,7,8,1,2,3,4,5,7,9,2,3,4,5,6,7,8,9];var FL=[8,7,6,5,4,3,2,10,0,9,8,7,6,5,4,3,2];var rs=0;for(i=0;i<17;i++){f=FL[i];d=v.slice(i,i+1);if(i==8){cdv=d;}
if(!isNaN(d)){d*=f;}
else{for(n=0;n<LL.length;n++){if(d.toUpperCase()===LL[n]){d=VL[n];d*=f;if(isNaN(cdv)&&n==8){cdv=LL[n];}
break;}}}
rs+=d;}
cd=rs%11;if(cd==10){cd="X";}
if(cd==cdv){return true;}
return false;},"The specified vehicle identification number (VIN) is invalid.");jQuery.validator.addMethod("dateITA",function(value,element){var check=false;var re=/^\d{1,2}\/\d{1,2}\/\d{4}$/
if(re.test(value)){var adata=value.split('/');var gg=parseInt(adata[0],10);var mm=parseInt(adata[1],10);var aaaa=parseInt(adata[2],10);var xdata=new Date(aaaa,mm-1,gg);if((xdata.getFullYear()==aaaa)&&(xdata.getMonth()==mm-1)&&(xdata.getDate()==gg))
check=true;else
check=false;}else
check=false;return this.optional(element)||check;},"Please enter a correct date");jQuery.validator.addMethod("phoneUS",function(phone_number,element){phone_number=phone_number.replace(/\s+/g,"");return this.optional(element)||phone_number.length>9&&phone_number.match(/^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/);},"Please specify a valid phone number");jQuery.validator.addMethod("phone",function(phone_number,element){phone_number=phone_number.replace(/^\s+/g,"");phone_number=phone_number.replace(/\s+$/g,"");var isOptional=this.optional(element);return isOptional||phone_number.length>9&&phone_number.match(/^\+[\d]+ [\d]+ [\d ]+$/);},"Please specify a valid phone number");jQuery.validator.addMethod("strippedminlength",function(value,element,param){return jQuery(value).text().length>=param;},jQuery.format("Please enter at least {0} characters"));jQuery.validator.addMethod("email2",function(value,element,param){return this.optional(element)||/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)*(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i.test(value);},jQuery.validator.messages.email);jQuery.validator.addMethod("url2",function(value,element,param){return this.optional(element)||/^(https?|ftp):\/\/(((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:)*@)?(((\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])\.(\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5]))|((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)*(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?)(:\d*)?)(\/((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)+(\/(([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)*)*)?)?(\?((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|[\uE000-\uF8FF]|\/|\?)*)?(\#((([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(%[\da-f]{2})|[!\$&'\(\)\*\+,;=]|:|@)|\/|\?)*)?$/i.test(value);},jQuery.validator.messages.url);var lastPasswordMessage='';jQuery.validator.addMethod("password",function(password,element,params){score=0
params=$.extend({shortPass:'Password too short',veryBadPass:'Very bad password',badPass:'Bad password',goodPass:'Good password',strongPass:'Strong password'},params||{});if(password.length<4){lastPasswordMessage=params.shortPass;return false;}
var username=$(params.username).val().toLowerCase();var wikiname=$(params.wikiname).val().toLowerCase();var lcpassword=password.toLowerCase();if(username.indexOf(lcpassword)>=0||wikiname.indexOf(lcpassword)>=0){lastPasswordMessage=params.veryBadPass;return false;}
score+=password.length*4
score+=(checkRepetition(1,password).length-password.length)*1
score+=(checkRepetition(2,password).length-password.length)*1
score+=(checkRepetition(3,password).length-password.length)*1
score+=(checkRepetition(4,password).length-password.length)*1
if(password.match(/(.*[0-9].*[0-9].*[0-9])/))score+=5
if(password.match(/(.*[!,@,#,$,%,^,&,*,?,_,~].*[!,@,#,$,%,^,&,*,?,_,~])/))score+=5
if(password.match(/([a-z].*[A-Z])|([A-Z].*[a-z])/))score+=10
if(password.match(/([a-zA-Z])/)&&password.match(/([0-9])/))score+=15
if(password.match(/([!,@,#,$,%,^,&,*,?,_,~])/)&&password.match(/([0-9])/))score+=15
if(password.match(/([!,@,#,$,%,^,&,*,?,_,~])/)&&password.match(/([a-zA-Z])/))score+=15
if(password.match(/^\w+$/)||password.match(/^\d+$/))score-=10
if(score<0)score=0
if(score>100)score=100
if(score<34){lastPasswordMessage=params.badPass;return false;}
if(score<68){lastPasswordMessage=params.goodPass;return true;}
lastPasswordMessage=params.strongPass;return true;},function(){return lastPasswordMessage;});function checkRepetition(pLen,str){res=""
for(i=0;i<str.length;i++){repeated=true
for(j=0;j<pLen&&(j+i+pLen)<str.length;j++)
repeated=repeated&&(str.charAt(j+i)==str.charAt(j+i+pLen))
if(j<pLen)repeated=false
if(repeated){i+=pLen-1
repeated=false}
else{res+=str.charAt(i)}}
return res}
$.validator.addMethod("wikiword",function(value,element){return this.optional(element)||/[A-Z]+[a-z0-9]+[A-Z]+[A-Za-z0-9]*/.test(value);},"Not a WikiWord");;
