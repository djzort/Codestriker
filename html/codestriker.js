// Global settings for overLIB.
ol_fgcolor = '#FFFFCC';
ol_textsize = '2';

// Records what topicid is being processed.
var topicid = '';

// Handle to the popup window.
var windowHandle = '';

function myOpen(url,name) {
    windowHandle = window.open(url,name,
	  		       'toolbar=no,width=800,height=600,status=yes,scrollbars=yes,resizable=yes,menubar=no');
    // Indicate who initiated this operation.
    windowHandle.opener = window;

    windowHandle.focus();
}

// Edit open function.  Name is kept short to reduce output size.
function eo(fn,line,newfile) {
    var location = window.location;
    myOpen(location.protocol + '//' + location.host +
           location.pathname + '?fn=' + fn + '&line=' + line +
	   '&new=' + newfile + '&topic=' + topicid + '&action=edit&a=' +
           fn + '|' + line + '|' + newfile, 'e');
}

function gotoAnchor(anchor, reload) {
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

