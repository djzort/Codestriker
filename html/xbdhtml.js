/* xbdhtml.js (Cross-Browser Nav4/Gecko/IE DHTML API) 
   14 May 98, Eric Krock, Copyright Netscape Communications
   Permission is granted to reuse, redistribute, and modify 
   without charge.
	
   Updated 18 July 2000 by Vladimir Ermakov, Netscape Communications,
   and Marcell Ortutay, Plugged in Enterprises, to include support of 
   the new Netscape Gecko layout engine.

   Updated 15 of February 2001 by Vladimir Ermakov, Netscape Communications:
       New Features
        -showElt/hideElt                -convenience functions to use insead of setEltVisibility
        -setEltWidth/setEltHeight       -Set the width/height of a layer
        -getEltPageLeft/getEltPageTop   -XBrowser version of Nav4 pageX/pageY 
        -stringToNumber                 -Returns 0 instead of NaN
       Improved: 
        -getEltWidth/getEltHeight       -Return offsetWidth if width not specified.
        -Also, where possible, replaced detection by browser with detection by property 

   Updated October 02, 2001 by Bob Clary, Netscape Communications
       Misc
         - changed reference to Ultimate Browser Sniffer on mozilla.org
       Bugs Fixed
         - hideElt                      -fixed missing argument to setEltVisibility
	 - getEltPageTop                -added marginTop for IE5/Mac

   Makes CSSP functionality and properties of positioned, named
   elements accessible from JavaScript in Netscape 4.x, IE and user
   agents implementing Gecko layout engine offering a single set of functions which
   can be used on both browsers, bridging DOM differences.

   Allows you to do these things from JavaScript on Nav4+/IE4+/Gecko:
   - get element object by specifying its name
   - hide/show element
   - get/set X, Y, Z position of element
   - get element height/width
   - get/set clipping area (visible area) of element
   - get/set background color and background image of element

   Also includes simplified JavaScript client sniffer and
   functions to ease dynamic, conditional generation of HTML 
   markup via document.write() statements.

   Design goals:
   - forwardly compatible with future DOM enhancements
     - redefinable stub function API
   - coexist peacefully with other libraries
     - no function name conflicts with cbdhtml.js, etc.
   - keep # of functions reasonable and use parameters to specify values
   - naming convention for functions easy to learn and remember
     - make as short as possible to type
   - loadable (though not executable!) without error on Nav3 since Nav3
     sometimes loads <SCRIPT LANGUAGE="JavaScript1.2" SRC=___.js>
   - usable in part or in whole; don't have to use whole thing
     - can copy and paste individual functions into existing code
       Exceptions to this rule: 
       1) you must include Is() constructor function and an
          instance of "is" global variable; all functions depend on this.
       2) getEltBackgroundColor depends on the color-related functions;
          to use it, you must include the others as well;
       3) all the functions for getting the clipping area 
          (getEltClipLeft getEltClipTop getEltClipRight 
           getEltClipBottom getEltClipWidth getEltClipHeight)
          depend on tempClipObj for use on IE4.

   Usage notes:
   - Place the SCRIPT element which links to this JavaScript file, xbdhtml.js,
     before your own SCRIPT which calls its functions.

     Example of correct usage: in the HEAD, place this HTML markup:

     <!-- This external script defines cross-browser functions for
          accessing CSSP and element properties. -->
     <SCRIPT LANGUAGE="JavaScript1.2" SRC=xbdhtml.js> </SCRIPT>
     <!-- Make your function calls to manipulate elements in this
          SCRIPT, now that the functions have been loaded. -->
     <SCRIPT LANGUAGE="JavaScript1.2"><!--
     //-*** put your function calls here ***
     //--></SCRIPT>
*/


// This is a simplified version of the JavaScript Client Sniffer code 
// found at http://www.mozilla.org/docs/web-developer/sniffer/browser_type.html

function Is ()
{   // convert all characters to lowercase to simplify testing
    var agt=navigator.userAgent.toLowerCase()

    // --- BROWSER VERSION ---
    this.major = stringToNumber(navigator.appVersion)
    this.minor = parseFloat(navigator.appVersion)

    this.nav  = ((agt.indexOf('mozilla')!=-1) && ((agt.indexOf('spoofer')==-1)
                && (agt.indexOf('compatible') == -1)))
    this.nav2 = (this.nav && (this.major == 2))
    this.nav3 = (this.nav && (this.major == 3))
    this.nav4 = (this.nav && (this.major == 4))
	
	//Netscape 6
	this.nav5 =	(this.nav && (this.major == 5))
	this.nav6 = (this.nav && (this.major == 5))
	this.gecko = (this.nav && (this.major >= 5))

    this.ie   = (agt.indexOf("msie") != -1)
    this.ie3  = (this.ie && (this.major == 2))
    this.ie4  = (this.ie && (this.major == 3))
    this.ie5  = (this.ie && (this.major == 4))


    this.opera = (agt.indexOf("opera") != -1)
     
    this.nav4up = this.nav && (this.major >= 4)
    this.ie4up  = this.ie  && (this.major >= 4)
}


var is = new Is();

// Convenience functions to ease dynamic/conditional markup
// generation depending upon browser vendor/version/OS.

// convenience function to save typing out document.write("STRING");
// if optional second argument minVersion passed in, 
//    only write if >= that version;
// if optional third  argument maxVersion passed in, 
//    only execute if <= that version;

function dw(str, minVersion, maxVersion)
{   if ( ((dw.arguments.length < 3) || (is.major <= maxVersion)) 
         && ((dw.arguments.length < 2) || (is.major >= minVersion)))
    document.write(str)  
}



// document write boolean
// convenience function to save typing out 
// if (aBoolean) document.write("STRING");
// if optional second argument aBoolean passed in, only write if
// aBoolean is true.

function dwb (str, aBoolean)
{   if  ((dwb.arguments.length < 2) || aBoolean)
    document.write(str)  
}



// string version:
// convenience function to return str or "" depending on version;
// if optional second argument version passed in, 
//    only return str if >= that version;
// if optional third  argument maxVersion passed in, 
//    only return str if <= that version;

function sv(str, minVersion, maxVersion)
{   if ( ((sv.arguments.length < 3) || (is.major <= maxVersion)) 
         && ((sv.arguments.length < 2) || (is.major >= minVersion)))
    return str;
    else return "";
}



// string boolean
// convenience function to save typing out 
// (aBoolean)?"STRING":""
// if optional second argument aBoolean passed in, only return
// str if aBoolean is true, else return "".

function sb (str, aBoolean)
{   if  ((sb.arguments.length < 2) || aBoolean)
    return str;
    else return "";
}




/* The following stub function API for cross-browser HTML 
   element positioning and visibility (CSSP access) was
   derived from Mike Hall's excellent CBDHTML API.

   Thanks also to Danny Goodman (http://www.dannyg.com/)
   and Dan Steinman (http://members.xoom.com/dynduo/).

   USAGE NOTE: when using the functions which get element CSSP
   properties [getEltLeft, getEltTop, etc.], keep in mind the 
   following IE4 CSSP property initialization problem: if you
   initialize a property value by CSSP markup, e.g.:
   #foo { left: 100px }
   rather than initializing them from JavaScript, e.g.:
   var fooElt = getElt ("foo");
   setEltLeft (fooElt, 100);
   ... the property value for the element's JavaScript style
   object (i.e. document.all.foo.style.left) is not set to the
   initial value! This is true for a number of IE4 style object
   properties including left, top, and clip. Before you get one of these
   properties in IE4, you must first set it from JavaScript.
   Workaround: set the property via JavaScript instead of CSSP
   markup, or set it from both to the same value.
*/


/* functions genElt, writeElt, and layerClipOrder
 
   Sometimes dynamically generating markup which is optimized for the
   current browser will simplify development. genElt will generate
   a named DIV on IE4 and Netscape6, and a LAYER/ILAYER tag on Nav4 as a string.
   writeElt will create the same string and write it out.

   These three functions must be reused as a group. writeElt calls 
   genElt, and those two both call layerClipOrder.

   ARGUMENTS OF FUNCTIONS genElt AND writeElt

   genElt and writeElt have identical argument lists.

   The first argument, name, is required. All of the other arguments 
   default to false and can be explicitly set to false or 
   omitted.  Those properties will be hard coded into the HTML markup
   if the argument is provided, and left unset if the argument is set 
   to false or omitted.  

   For example, both of these function calls have the same effect.
   They will generate a named, positioned element but not specify 
   any of the properties, and will write out
   the element and content even on Nav3/IE3 and earlier:
   writeElt ("foo");
   writeElt ("foo", false, false, false);

   name     STRING.  Name of element's ID.
   content  STRING.  Content written within element.
   left     INTEGER. Left edge of element in pixels.
   top      INTEGER. Top  edge of element in pixels.
   z        INTEGER. z-index of element.
   width    INTEGER. width in pixels.
   height   INTEGER. height in pixels.
   visibility        STRING. "visible", "hidden", or "inherit". 
   backgroundColor   STRING. Background color of element.
   backgroundImage   STRING. Background image of element.
   clip              STRING. Comma-delimited list (no spaces!) of 4 
                     integers in top-right-bottom-left order. Sets clip.
   relative          BOOLEAN. If true, position relatively, else absolutely.
                     On Nav4, this determines whether LAYER (absolute) or
                     ILAYER (relative) is generated.
   hideEltOnOlderBrowsers  BOOLEAN. If true, return '' on Nav3, IE3, and older.
   useDivInsteadOfLayer    BOOLEAN. If true, generate DIV on Nav4 not I/LAYER.
   classname               STRING.  CLASS attribute value for element.

   'genElt' is short for 'generate element markup'.
*/

/* maps css order <top>,<right>,<bottom>,<left> to 
   LAYER CLIP= order <left>,<top>,<right>,<bottom> */
function layerClipOrder (cssClipString)
{  var commaPos = cssClipString.lastIndexOf(",");
   return (cssClipString.substring(commaPos+1) + "," + cssClipString.substring(0,commaPos));
}

function genElt (name, content, left, top, z, width, height, visibility, 
                 backgroundColor, backgroundImage, clip, relative, 
                 hideEltOnOlderBrowsers, useDivInsteadOfLayer, classname) 
{ var markup = "";
  if (is.gecko)
  {
    markup = '<DIV ID="' + name + '"' +  
        ((classname)?' CLASS="' + classname + '"':'') + 
        ' STYLE="position:' + ((relative)?'relative;':'absolute;') + 
        ' overflow:none;' + 
        ((left)?' left:' + left + 'px;':'') + 
        ((top)?' top:' + top + 'px;':'') + 
        ((height)?' height:' + height + 'px;':'') + 
        ((width)?' width:' + width + 'px;':'') + 
        ((visibility && (visibility!='')) ? ' visibility:' + visibility + ';' : '') + 
        ((z)?' z-index:' + z + ';':'') + 
        ((backgroundColor)?' background-color:' + backgroundColor + ';':'') + 
        ((backgroundImage)?' background-image:url("' + backgroundImage + '");':'') +  
        ((clip)?' clip:rect("' + clip + '");':'') + 
        '">' + ((content)?content:'') + '</DIV>';
  }

  else if (is.nav && (is.major == 4 || !hideEltOnOlderBrowsers) && 
      !useDivInsteadOfLayer)
  { var tagname = (relative)?'ILAYER':'LAYER';
    if (visibility && (visibility!=''))
    {  if (visibility=="hidden") visibility = "hide";
       else if (visibility=="visible") visibility = "show";
    }
    markup = '<' + tagname + ' ID="' + name + '"' + ((classname)?' CLASS="' + 
        classname + '"':'') + ((left)?' LEFT="' + left + '"':'') + 
        ((top)?' TOP="' + top + '"':'') + ((width)?' WIDTH="' + width + '"':'') + 
        ((height)?' HEIGHT="' + height + '"':'') + 
        ((visibility && (visibility!='')) ? ' VISIBILITY="' + visibility + '"' : '') + 
        ((z)?' Z-INDEX="' + z + '"':'') + 
        ((backgroundColor)?' BGCOLOR="' + backgroundColor + '"':'') + 
        ((backgroundImage)?' BACKGROUND="' + backgroundImage + '"':'') +  
        ((clip)?' CLIP="' + layerClipOrder(clip) + '"':'') + 
        '>' + ((content)?content:'') + '</' + tagname + '>';
  }
 
  else if ((is.ie || (is.nav && useDivInsteadOfLayer)) && (is.major>=4 || !hideEltOnOlderBrowsers))
  { markup = '<DIV ID="' + name + '"' +  
        ((classname)?' CLASS="' + classname + '"':'') + 
        ' STYLE="position:' + ((relative)?'relative;':'absolute;') + 
        ' overflow:none;' + 
        ((left)?' left:' + left + 'px;':'') + 
        ((top)?' top:' + top + 'px;':'') + 
        ((height)?' height:' + height + 'px;':'') + 
        ((width)?' width:' + width + 'px;':'') + 
        ((visibility && (visibility!='')) ? ' visibility:' + visibility + ';' : '') + 
        ((z)?' z-index:' + z + ';':'') + 
        ((backgroundColor)?' background-color:' + backgroundColor + ';':'') + 
        ((backgroundImage)?' background-image:url("' + backgroundImage + '");':'') +  
        ((clip)?' clip:rect("' + clip + '");':'') + 
        '">' + ((content)?content:'') + '</DIV>';
  }

  return markup;
}

function writeElt (name, content, left, top, z, width, height, visibility, 
                   backgroundColor, backgroundImage, clip, relative, 
                   hideEltOnOlderBrowsers, useDivInsteadOfLayer, classname) 
{ if (writeElt.arguments.length < 15) classname = false;
  if (writeElt.arguments.length < 14) useDivInsteadOfLayer = false;
  if (writeElt.arguments.length < 13) hideEltOnOlderBrowsers = false;
  if (writeElt.arguments.length < 12) relative = false;
  if (writeElt.arguments.length < 11) clip = false;
  if (writeElt.arguments.length < 10) backgroundImage = false;
  if (writeElt.arguments.length < 9) backgroundColor = false;
  if (writeElt.arguments.length < 8) visibility = false;
  if (writeElt.arguments.length < 7) height = false;
  if (writeElt.arguments.length < 6) width = false;
  if (writeElt.arguments.length < 5) z = false;
  if (writeElt.arguments.length < 4) top = false;
  if (writeElt.arguments.length < 3) left = false;
  if (writeElt.arguments.length < 2) content = false;
  document.write (genElt (name, content, left, top, z, width, height, visibility, 
                    backgroundColor, backgroundImage, clip, relative, 
                 hideEltOnOlderBrowsers, useDivInsteadOfLayer, classname));
}


/* CALLING SYNTAX: each Name is a string which is an element's 
   ID attribute value or a LAYER tag's NAME attribute value.

   getElt (topLevelElementName, childElementName, grandchildElementName ...
                 targetElementName)

   Example of getting a top-level element: 
   var fooElement = getElt ("foo")

   Example of getting a nested element: 
   var fooElement = getElt ("bar", "baz", "foo")
   ... where baz is foo's containing parent, and bar is a top-level 
       element which is baz's containing parent.
*/

function getElt () 
{ if (is.nav4)
  {
    var currentLayer = document.layers[getElt.arguments[0]];
    for (var i=1; i<getElt.arguments.length && currentLayer; i++)
    {   currentLayer = currentLayer.document.layers[getElt.arguments[i]];
    }
    return currentLayer;
  } 
  else if(document.getElementById && document.getElementsByName)
  { 
    var name = getElt.arguments[getElt.arguments.length-1];
    if(document.getElementById(name))                      //First try to find by id
       return document.getElementById(name);
    else if (document.getElementsByName(name))             //Then if that fails by name
	   return document.getElementsByName(name)[0];
  }
  else if (is.ie4up) {
    var elt = eval('document.all.' + getElt.arguments[getElt.arguments.length-1]);
    return(elt);
  }

}

function showElt(elt)
{
	setEltVisibility(elt,'visible');
}

function hideElt(elt)
{
	setEltVisibility(elt, 'hidden');
}

/* value must be "visible", "hidden", or "inherit".
   These values work on Nav4, Gecko and IE for setting visibility.
*/
function setEltVisibility (elt, value)
{  if (is.nav4) elt.visibility = value;
   else if (elt.style) elt.style.visibility = value;
}



/* Return values are strings "visible", "hidden", or "inherit".
   This is consistent with CSS1 and IE4 usage and the settable
   values on all three browsers. Note that Nav4
   by default returns "show" and "hide" and that these values
   are mapped to "visible" and "hidden" to provide consistent
   return values across browsers. */

function getEltVisibility (elt)
{  if (is.nav4) 
   {  var value = elt.visibility;
      if (value == "show") return "visible";
      else if (value == "hide") return "hidden";
      else return value;
   }
   else if (elt.style) return elt.style.visibility;
}



/* Move elt to pixel location x,y within its coordinate system,
   which is the window content area for top-level elements or
   the parent element's coordinates for nested elements which 
   have an absolutely positioned parent.
*/

function moveEltTo (elt, x, y) 
{ if (is.nav4) elt.moveTo(x, y);
  else if (is.ie4up) {
    elt.style.pixelLeft = x;
    elt.style.pixelTop  = y;
  }
  else if (is.gecko) {
    elt.style.left = x;
    elt.style.top  = y;
  }
}


/* Offset elt's pixel location by x,y pixels. */

function moveEltBy (elt, x, y) 
{ if (is.nav4) elt.moveBy(x, y);
  else if (is.ie4up)  {
    elt.style.pixelLeft += x;
    elt.style.pixelTop  += y;
  }
  else if (is.gecko)  {
    elt.style.left = (stringToNumber(elt.style.left) + x + "px");
    elt.style.top  = (stringToNumber(elt.style.top)  + y + "px");
  }
}

/* xbrowser pageX equivalent*/
function getEltPageLeft(elt) {
  var x;

  if (is.nav4)
    return elt.pageX;
  if (is.ie4up) {
    x = 0;
    while (elt.offsetParent != null) {
      x += elt.offsetLeft;
      elt = elt.offsetParent;
    }
    x += elt.offsetLeft;
    return x;
  }
  if (is.gecko) {
    x = 0;
    while (elt.offsetParent != null) {
      x += elt.offsetLeft;
      elt = elt.offsetParent;
    }
    x += elt.offsetLeft;
    return x;
  }
  return -1;
}

/* xbrowser pageY equivalent */
function getEltPageTop(elt) {
  var y = 0;

  if (is.nav4)
    return elt.pageY;
  if (is.ie4up) {
    while (elt.offsetParent != null) {
      y += elt.offsetTop;
      elt = elt.offsetParent;
    }
    y += elt.offsetTop;
    return y;
  }

  /* ie5/mac modification added per comment from David Weingard */
  if (is.mac && is.ie5)
  {
    y += stringToNumber(document.body.currentStyle.marginTop);
  }

  if (is.gecko) {
    while (elt.offsetParent != null) {
      y += elt.offsetTop;
      elt = elt.offsetParent;
    }
    y += elt.offsetTop;
    return y;
  }
  return -1;
}

/* Sets position of left edge of elt in pixels. */
function setEltLeft (elt, x) {
  if (is.nav4)     elt.left=x;
  else if (is.ie4up) elt.style.pixelLeft=x;
  else if (is.gecko) elt.style.left = (x + "px");
}


/* Returns left edge of elt in pixels. */
function getEltLeft (elt) {
  if (is.nav4)     return (elt.left);
  else if (is.ie4up) return (elt.style.pixelLeft);
  else if (is.gecko) return stringToNumber(elt.style.left);
}

/* Sets top edge of elt in pixels. */
function setEltTop (elt, y) 
{ if (is.nav4)     elt.top=y;
  else if (is.ie4up) elt.style.pixelTop=y;
  else if (is.gecko) elt.style.top= (y + "px");
}

/* Returns top edge of elt in pixels. */
function getEltTop (elt) 
{ if (is.nav4)     return (elt.top);
  else if (is.ie4up) return (elt.style.pixelTop);
  else if (is.gecko) return stringToNumber(elt.style.top);
}

/* Returns width of elt in pixels. */
function getEltWidth(elt) {

  if (is.nav4) {
    if (elt.document.width)
      return elt.document.width;
    else
      return elt.clip.right - elt.clip.left;
  }
  if (is.ie4up) {
    if (elt.style.pixelWidth)
      return elt.style.pixelWidth;

    else
      return elt.offsetWidth;
  }
  if (is.gecko) {
    if (elt.style.width)
      return stringToNumber(elt.style.width);
    else
      return stringToNumber(elt.offsetWidth);
  }
  return -1;
}

/* set width of elt in pixels */
function setEltWidth(elt,wdth)
{
	if(is.nav4)
    { 
	     elt.document.width = wdth;
    }
    else if(elt.style)
    { 
        elt.style.width = wdth;
    }
}

/* Returns height of elt in pixels. */
function getEltHeight(elt) {
  if (is.nav4) {
    if (elt.document.height)
      return elt.document.height;
    else
      return elt.clip.bottom - elt.clip.top;
  }
  if (is.ie4up) {
    if (elt.style.pixelHeight)
      return elt.style.pixelHeight;
    else
      return elt.clientHeight;
  }
  if (is.gecko) {
    if (elt.style.height)
      return stringToNumber(elt.style.height);
    else
      return stringToNumber(elt.offsetHeight);
  }
  return -1;
}

/* set width of elt in pixels */

function setEltHeight(elt,hght)
{
	if(is.nav4)
    { 
		elt.document.height = hght;
    }
    else if(elt.style)
    { 
        elt.style.height = hght;
    }
}

/* Sets element clipping area. 
   NOTE ORDER: top, right, bottom, left to be consistent with CSS usage.
   cliptop, clipright, clipbottom, and clipleft are integers. 
*/
function setEltClip (elt, cliptop, clipright, clipbottom, clipleft) 
{ if (is.nav4) {
    elt.clip.left   = clipleft;
    elt.clip.top    = cliptop;
    elt.clip.right  = clipright;
    elt.clip.bottom = clipbottom;
  }
  else if (is.ie4up)  elt.style.clip = 'rect(' + cliptop + ' ' +  
       clipright + ' ' + clipbottom + ' ' + clipleft +')';
  else if (is.gecko)  elt.style.clip = 'rect(' + cliptop + ' ' +  
       clipright + ' ' + clipbottom + ' ' + clipleft +')';
}

/* utility function for IE only -- does not use regular expressions
   in order to avoid triggering syntax error if parsed by Nav3 */
function tempClipObj (elt)
{  var clipStr = elt.style.clip;
  
   clipStr = clipStr.substring (clipStr.indexOf("(") + 1);
   this.top = stringToNumber(clipStr);
   clipStr = clipStr.substring (clipStr.indexOf(" ") + 1);
   this.right = stringToNumber(clipStr);
   clipStr = clipStr.substring (clipStr.indexOf(" ") + 1);
   this.bottom = stringToNumber(clipStr);
   clipStr = clipStr.substring (clipStr.indexOf(" ") + 1);
   this.left = stringToNumber(clipStr);
}

/* Returns left edge of clipping area of elt in pixels. */
function getEltClipLeft (elt) 
{ if (is.nav4)     return (elt.clip.left);
  else if (elt.style) 
  {  var tempClip = new tempClipObj (elt);
     return tempClip.left;
  }
}

/* Returns top edge of clipping area of elt in pixels. */
function getEltClipTop (elt) 
{ if (is.nav4)     return (elt.clip.top);
  else if (elt.style) 
  {  var tempClip = new tempClipObj (elt);
     return tempClip.top;
  }
}

/* Returns right edge of clipping area of elt in pixels. */
function getEltClipRight (elt) {
  if (is.nav4)     return (elt.clip.right);
  else if (elt.style) 
  {  var tempClip = new tempClipObj (elt);
     return tempClip.right;
  }

}

/* Returns bottom edge of clipping area of elt in pixels. */
function getEltClipBottom (elt) 
{ if (is.nav4)     return (elt.clip.bottom);
  else if (elt.style) 
  {  var tempClip = new tempClipObj (elt);
     return tempClip.bottom;
  }
}

/* Returns width of clipping area of elt in pixels. */

function getEltClipWidth (elt) 
{
    return (getEltClipRight(elt) - getEltClipLeft(elt));
}


/* Returns height of clipping area of elt in pixels. */

function getEltClipHeight (elt) 
{
    return (getEltClipBottom(elt) - getEltClipTop(elt));
}


/* Returns width of current window content area in pixels. */

function getCurrentWinWidth() 
{ if (is.nav4)     return(window.innerWidth);
  else if (is.ie4up) return(document.body.clientWidth);
  else if (is.gecko) return(window.innerWidth);
}



/* Returns height of current window content area in pixels. */
function getCurrentWinHeight() 
{ if (is.nav4)     return(window.innerHeight);
  else if (is.ie4up) return(document.body.clientHeight);
  else if (is.gecko) return(window.innerHeight);

}

/* Returns z-index (stacking order) of elt,
   which is a positive integer.  */

function getEltZIndex (elt) 
{ if (is.nav4) return(elt.zIndex);
  else if (elt.style) return (elt.style.zIndex);
}

/* Sets z-index (stacking order) of elt.
   z is a positive integer.  */

function setEltZIndex (elt, z) 
{ if (is.nav4) elt.zIndex = z;
  else if (elt.style) elt.style.zIndex = z;
}


/* end CBDHTML derivative functions  */
/* Sets background image of elt to image at imageFilePath.

   Note: although this function and the next provide the 
   ability to set and get the background image property of
   an element across Nav4/Gecko/IE4+, because of differences in
   the way background image support is implemented, it may
   require considerable experimentation with HTML/CSS markup
   and content to achieve the same visual effect.
*/
function setEltBackgroundImage (elt, imageFilePath) 
{ if (is.nav4) elt.background.src = imageFilePath;
  else if (is.ie4up) elt.style.backgroundImage = "url(" + imageFilePath + ")";
  else if (is.gecko) elt.style.backgroundImage = "url(" + imageFilePath + ")";
}

/* Returns file path or URL of background image of elt. 
   Note: the return value strings are not identical. 
   On Nav4, we get back a string like 
   "file:///F|/DHTML/xbdhtml/xbdhtml/images/redpole.gif".
   On IE4 and Gecko, we get back a string like "url(images/redpole.gif)".
   so we trim off the leading "url(" and the trailing ")".
*/

function getEltBackgroundImage (elt) 
{ if (is.nav4) return (elt.background.src);
  else if (elt.style) { 
     var theURL = elt.style.backgroundImage;
     if (typeof(theURL) == "string")
     {  var URLlen = theURL.length;
        return (theURL.substring (4, URLlen-1));
     }
     else return(theURL);
  }
}

/* Sets background color of elt to colorNumber.
   colorNumber is an numeric color code like 0xffffff for white,
   or one of the 16 standard color names from CSS1 like "red". 
   (DO NOT USE IE's extended list of color names strings; they  
   are not supported on Nav4!) 

   NOTE: even if you set the color to one of the 16 CSS1 color name
   strings (e.g. "red"), getEltBackgroundColor will always return 
   the integer code equivalent (e.g. 0xff0000 instead of "red"), 
   because getEltBackgroundColor automatically converts those names to
   an integer on IE4 and Gecko, and on Nav4 the conversion happens by default.
   To avoid the confusion of setting the value to a string but getting
   an integer back, it's simplest to use color numbers only.

   Note: although this function and the next provide the 
   ability to set and get the background color property of
   an element across Nav4/Gecko/IE4+, because of differences in
   the way background color support is implemented, it may
   require considerable experimentation with HTML/CSS markup
   and content to achieve the same visual effect.
*/

function setEltBackgroundColor (elt, colorNumber) 
{ if (is.nav4) elt.bgColor = colorNumber;
  else if (elt.style) elt.style.backgroundColor = colorNumber;
}

/* -------------------------------------------------------------
        FUNCTIONS FOR GETTING ELEMENT'S BACKGROUND COLOR
   These depend upon each other and must be reused as a group.
   ------------------------------------------------------------- */

var colorNameString = "aqua,black,blue,fuchsia,gray,green,lime,maroon,navy,olive,purple,red,silver,teal,yellow,white";
var colorNames   = new Array ("aqua", "black", "blue", "fuchsia", "gray",   "green", "lime", "maroon", "navy", "olive",  "purple", "red",    "silver", "teal", "yellow", "white");
var colorNumbers = new Array (0xffff, 0,       0xff,   0xff00ff,  0x808080, 0x8000,  0xff00, 0x800000, 0x80,   0x808000, 0x800080, 0xff0000, 0xc0c0c0, 0x8080, 0xffff00, 0xffffff);



/* Tests whether string aString is one of the 16 CSS1 color names.
*/
function isColorName (aString)
{ return ( (typeof(aString) == "string") && (colorNameString.indexOf(aString) != -1));
}

/* Converts color name string (like "white") to number (like 0xffffff). 
   ONLY supports 16 standard CSS1 color names, NOT IE4 extended list!
*/
function colorNameToNumber (colorName)
{ for (var i=0; i<16; i++) if (colorNames[i]==colorName) return colorNumbers[i];
  // Return string name unchanged if not found.
  // This handles IE4 non-CSS1-standard color names gracefully.
  return colorName;
}

/* Converts color number (like 0xffffff) to name string (like "white"). 
   ONLY supports 16 standard CSS1 color names, NOT IE4 extended list!
*/

function colorNumberToName (colorNumber)
{ for (var i=0; i<16; i++) if (colorNumbers[i]==colorNumber) return colorNames[i];
  return null;
}

/* Returns background color of elt as integer. 
   (NOT color name like "red", or IE4 default return value like "#ffffff".)
   Nav4 returns integer by default. IE4 returns string which is either:
   a) a leading "#" followed by a 6-digit hexadecimal RGB value, or
   b) one of the 16 string color names like "red"
   ... so we convert this to an integer for compatibility.
   and Gecko returns a string which is either:
   a) an rgb string like "rgb(255,0,255)"
   b) one of the 16 string color names like red.
   
   WARNING: There is a bug in Netscape6 (Gecko) that makes the browser interpret
			decimal color values as hexadecimal, so if you set the color to 65280
			the actual color would be 0x065280. Avoid using decimal color values!
            They are not standard and depricated.
   WARNING: only the 16 CSS1 color names will be converted to integers.
*/

function getEltBackgroundColor (elt) 
{
  if (is.nav4) return (elt.bgColor);
  else if (is.ie4up) 
  {
     var colorVal = elt.style.backgroundColor;
     if (isColorName(colorVal)) return colorNameToNumber (colorVal);
     else if (typeof(colorVal) == "string") 
          return (("0x" + colorVal.substring(1)) - 0);
     else return colorVal;
  }
  else if (is.gecko) {
    var colorVal = elt.style.backgroundColor;
    
	 if (typeof(colorVal) == "string")
	 { 	
		if (isColorName(colorVal)) 	
		{
			return colorNameToNumber (colorVal);
		}
		else if (colorVal.indexOf(["rgb"]) != -1) 
		{	
			var sR,sG,sB;
			var iR,iG,iB;
			var i=0;

			ColorString = (elt.style.backgroundColor);
			//ColorString = "rgb(255,20,255)";
			ColorString = ColorString.slice(4,-1);

			while(ColorString[i] != ',' && i < 20){i++;}
			sR = ColorString.slice(0,-(ColorString.length - i));
			i++;
			j = i;
			while(ColorString[j] != ',' && j < 20){j++;}
			sG = ColorString.slice(i,0-(ColorString.length - j));
			j++;
			sB = ColorString.slice(j);
			iR = stringToNumber(sR);
			iG = stringToNumber(sG);
			iB = stringToNumber(sB);
			sR = iR.toString(16);if(sR.length < 2)sR = "0" + sR;if(sR.length < 2)sR = "0" + sR;
			sG = iG.toString(16);if(sG.length < 2)sG = "0" + sG;if(sG.length < 2)sG = "0" + sG;
			sB = iB.toString(16);if(sB.length < 2)sB = "0" + sB;if(sB.length < 2)sB = "0" + sB;

			sRGB = sR.toUpperCase()+sG.toUpperCase()+sB.toUpperCase();
			return (("0x" + sRGB)-0);
		}
	 }
     else return colorVal;
  }
}

/* A version of stringToNumber that returns 0 if there is NaN returned, or number is part of a string, like 100px... */
function stringToNumber(s)
{
        return parseInt(('0' + s), 10)
}
