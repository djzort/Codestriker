// Global settings for overLIB.
ol_fgcolor = '#FFFFCC';
ol_textsize = '2';

// Handle to the popup window.
var windowHandle = '';

function myOpen(url,name)
{
    windowHandle = window.open(url,name,
	  		       'toolbar=no,width=800,height=600,status=yes,scrollbars=yes,resizable=yes,menubar=no');
    // Indicate who initiated this operation.
    windowHandle.opener = window;

    windowHandle.focus();
}

// Edit open function.  Name is kept short to reduce output size.
function eo(fn,line,newfile)
{
    add_comment_tooltip(fn,line,newfile);
}

function gotoAnchor(anchor, reload)
{
    if (anchor == "" || opener == null) return;

    var index = opener.location.href.lastIndexOf("#");
    if (index != -1) {
	opener.location.href =
	    opener.location.href.substr(0, index) + "#" + anchor;
    }
    else {
        opener.location.href += "#" + anchor;
    }
		
    if (reload) opener.location.reload(reload);
    opener.focus();
}

// Called by a body onload handler for the view topic page, to tooltip
// the comment associated with an anchor that has comments made
// against it.
function view_topic_on_load_handler()
{
    // If the URL loaded contains an anchor, check if there is a comment
    // associated with it.
    var anchor = window.location.hash;
    if (anchor != null) {
        // Remove the leading # character.
        anchor = anchor.substr(1);
        var comment_number = comment_hash[anchor];
        if (comment_number != null) {
            // We have a comment on this line, bring up the tooltip.
            overlib(comment_text[comment_number], STICKY, DRAGGABLE, ALTCUT,
                    FIXX, getEltPageLeft(getElt('c' + comment_number)),
                    FIXY, getEltPageTop(getElt('c' + comment_number)));
        }
    }
}

// Create a new tooltip window which contains an iframe used for adding
// a comment to the topic.
function add_comment_tooltip(file, line, new_value)
{
    var l = window.location;
    var url = l.protocol + '//' + l.host + l.pathname + '?' +
              'fn=' + file + '&line=' + line + '&new=' + new_value +
              '&topic=' + cs_topicid + '&action=edit';
    var html = '<a href="javascript:hideElt(getElt(\'overDiv\')); void(0);">' +
               'Close</a><p>' +
               '<iframe width="600" height="480" src="' + url + '">' +
                'Can\'t view iframe</iframe>';
    overlib(html, STICKY, DRAGGABLE, ALTCUT, CENTERPOPUP, WIDTH, 600,
            HEIGHT, 480);
}
