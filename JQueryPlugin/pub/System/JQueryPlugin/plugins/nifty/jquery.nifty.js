jQuery.fn.nifty=function(options){if((document.getElementById&&document.createElement&&Array.prototype.push)==false)return;options=options||"";h=(options.indexOf("fixed-height")>=0)?this.offsetHeight:0;this.each(function(){var i,top="",bottom="";if(options!=""){options=options.replace("left","tl bl");options=options.replace("right","tr br");options=options.replace("top","tr tl");options=options.replace("bottom","br bl");options=options.replace("transparent","alias");if(options.indexOf("tl")>=0){top="both";if(options.indexOf("tr")==-1)top="left";}else if(options.indexOf("tr")>=0)top="right";if(options.indexOf("bl")>=0){bottom="both";if(options.indexOf("br")==-1)bottom="left";}else if(options.indexOf("br")>=0)bottom="right";}
if(top==""&&bottom==""&&options.indexOf("none")==-1){top="both";bottom="both";}
if(this.currentStyle!=null&&this.currentStyle.hasLayout!=null&&this.currentStyle.hasLayout==false)
jQuery(this).css("display","inline-block");if(top!=""){var d=document.createElement("b"),lim=4,border="",p,i,btype="r",bk,color;jQuery(d).css("marginLeft","-"+_niftyGP(this,"Left")+"px");jQuery(d).css("marginRight","-"+_niftyGP(this,"Right")+"px");if(options.indexOf("alias")>=0||(color=_niftyBC(this))=="transparent"){color="transparent";bk="transparent";border=_niftyPBC(this);btype="t";}
else{bk=_niftyPBC(this);border=_niftyMix(color,bk);}
jQuery(d).css("background",bk);d.className="niftycorners";p=_niftyGP(this,"Top");if(options.indexOf("small")>=0){jQuery(d).css("marginBottom",(p-2)+"px");btype+="s";lim=2;}
else if(options.indexOf("big")>=0){jQuery(d).css("marginBottom",(p-10)+"px");btype+="b";lim=8;}
else jQuery(d).css("marginBottom",(p-5)+"px");for(i=1;i<=lim;i++)
jQuery(d).append(CreateStrip(i,top,color,border,btype));jQuery(this).css("paddingTop","0px");jQuery(this).prepend(d);}
if(bottom!=""){var d=document.createElement("b"),lim=4,border="",p,i,btype="r",bk,color;jQuery(d).css("marginLeft","-"+_niftyGP(this,"Left")+"px");jQuery(d).css("marginRight","-"+_niftyGP(this,"Right")+"px");if(options.indexOf("alias")>=0||(color=_niftyBC(this))=="transparent"){color="transparent";bk="transparent";border=_niftyPBC(this);btype="t";}else{bk=_niftyPBC(this);border=_niftyMix(color,bk);}
jQuery(d).css("background",bk);d.className="niftycorners";p=_niftyGP(this,"Bottom");if(options.indexOf("small")>=0){jQuery(d).css("marginTop",(p-2)+"px");btype+="s";lim=2;}
else if(options.indexOf("big")>=0){jQuery(d).css("marginTop",(p-10)+"px");btype+="b";lim=8;}
else jQuery(d).css("marginTop",(p-5)+"px");for(i=lim;i>0;i--)
jQuery(d).append(CreateStrip(i,bottom,color,border,btype));jQuery(this).css("paddingBottom","0");jQuery(this).append(d);};});if(options.indexOf("height")>=0)
{this.each(function(){if(this.offsetHeight>h)h=this.offsetHeight;jQuery(this).css("height","auto");var gap=h-this.offsetHeight;if(gap>0)
{var t=document.createElement("b");t.className="niftyfill";jQuery(t).css("height",gap+"px");nc=this.lastChild;nc.className=="niftycorners"?this.insertBefore(t,nc):jQuery(this).append(t);}});}
return this;}
function CreateStrip(index,side,color,border,btype){var x=document.createElement("b");x.className=btype+index;jQuery(x).css("backgroundColor",color).css("borderColor",border);if(side=="left")jQuery(x).css("borderRightWidth","0").css("marginRight","0");else if(side=="right")jQuery(x).css("borderLeftWidth","0").css("marginLeft","0");return(x);}
function _niftyPBC(x){var el=x.parentNode,c;while(el.tagName.toUpperCase()!="HTML"&&(c=_niftyBC(el))=="transparent")
el=el.parentNode;if(c=="transparent")c="#FFFFFF";return(c);}
function _niftyBC(x){var c=jQuery(x).css("backgroundColor");if(c==null||c=="transparent"||c.indexOf("rgba(0, 0, 0, 0)")>=0)return("transparent");if(c.indexOf("rgb")>=0){var hex="";var regexp=/([0-9]+)[, ]+([0-9]+)[, ]+([0-9]+)/;var h=regexp.exec(c);for(var i=1;i<4;i++){var v=parseInt(h[i]).toString(16);if(v.length==1)hex+="0"+v;else hex+=v;}
c="#"+hex;}
return(c);}
function _niftyGP(x,side){var p=jQuery(x).css("padding"+side);if(p==null||p.indexOf("px")==-1)return(0);return(parseInt(p));}
function _niftyMix(c1,c2){var i,step1,step2,x,y,r=new Array(3);c1.length==4?step1=1:step1=2;c2.length==4?step2=1:step2=2;if(c1=='white')c1='#ffffff';if(c2=='white')c2='#ffffff';if(c1=='black')c1='#000000';if(c2=='black')c2='#000000';for(i=0;i<3;i++){x=parseInt(c1.substr(1+step1*i,step1),16);if(step1==1)x=16*x+x;y=parseInt(c2.substr(1+step2*i,step2),16);if(step2==1)y=16*y+y;r[i]=Math.floor((x*50+y*50)/100);r[i]=r[i].toString(16);if(r[i].length==1)r[i]="0"+r[i];}
return("#"+r[0]+r[1]+r[2]);};
