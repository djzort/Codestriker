// Global settings for overLIB.
ol_fgcolor = '#FFFFCC';
ol_textsize = '2';
ol_width = 300;
ol_height= 150;

// Codestriker XMLHttpRequest object that is used.
var cs_request;

// Reference to status element.
var cs_status_element;

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

// Retrieve the value of a cookie by name.
function getCookie(name)
{
   var regexp = new RegExp(name + "=([^;]+)");
   var value = regexp.exec(document.cookie);
   return (value != null) ? value[1] : null;
}

// Set the value of the cookie to the specific value.
function setCookie(name, value, expirySeconds)
{
   if (!expirySeconds) {
       // Default to one hour
       expirySeconds = 60 * 60;
   }

   var now = new Date();
   var expiry = new Date(now.getTime() + (expirySeconds * 1000))
   document.cookie = name + "=" + value +
                     "; expires=" + expiry.toGMTString() +
                     "; path=" + document.location.pathname;
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
            overlib(comment_text[comment_number], STICKY, DRAGGABLE,
                    FIXX, getEltPageLeft(getElt('c' + comment_number)),
                    FIXY, getEltPageTop(getElt('c' + comment_number)));
        }
    }
}

// Create the HTML necessary for adding a comment.
function add_comment_html(file, line, new_value)
{
    // Get the location of the codestriker URL.
    var url = cs_add_comment_url + '/' + file + '|' + line + '|' + new_value + '/add';
              
    // Create the hidden error span, and the initial form, with the
    // appropriate hidden fields.
    var html = '<html><head>' +
            '<link rel="stylesheet" type="text/css" ' +
            '      href="' + cs_css + '"/>\n' +
            '<script src="' + cs_xbdhtml_js + '" type="text/javascript"></script>\n' +
            '</head>\n' +
            '<body bgcolor="#eeeeee">\n' +
            '<span class="hidden" id="statusField">&nbsp;</span>\n' +
	    '<form name="add_comment" method="POST" ' +
            'action="' + url + '" ' +
            'accept-charset="UTF-8" ' +
            'onSubmit="return top.verify(document.add_comment, getElt(\'statusField\'));" ' +
            'enctype="application/x-www-form-urlencoded" action="' + url + '">\n' +
	    '<input type="hidden" name="action" value="submit_comment">\n' +
	    '<input type="hidden" name="line" value="' + line + '">\n' +
	    '<input type="hidden" name="topic" value="' + cs_topicid + '">\n' +
	    '<input type="hidden" name="fn" value="' + file + '">\n' +
	    '<input type="hidden" name="newval" value="' + new_value + '">\n' +
	    '<textarea name="comments" rows="5" cols="50" wrap="hard">\n' +
	    '</textarea>\n';

    // Now add in the metric dropdowns.
    if (top.cs_metric_data.length > 0) {
        html += '<p><table>\n';
    }
    for (var i = 0; i < top.cs_metric_data.length; i++) {
        if (i % 2 == 0) {
            html += '<tr>\n';
        }
        html += '<td align="right">' + top.cs_metric_data[i].name + ':</td>\n';
        html += '<td align="left">\n';
        html += '<select name="comment_state_metric_' +
		top.cs_metric_data[i].name + '">\n';
        
	// Check if a value has been selected for this metric.
	var key = file + '|' + line + '|' + new_value;
	var comment_number = comment_hash[key];
        var current_value = null;
        if (comment_number != null &&
            comment_metrics[comment_number] != null) {
            current_value = 
               comment_metrics[comment_number][top.cs_metric_data[i].name];
        }
        if (current_value == null) {
	    // If there is no default value defined, create an empty setting.
	    if (top.cs_metric_data[i].default_value == null) {
                html += '<option value="Select Value">' +
		        '&lt;Select Value&gt;</option>\n';
            }
	    for (var j = 0; j < top.cs_metric_data[i].values.length; j++) {
                html += '<option ';
                var value = top.cs_metric_data[i].values[j];
                if (value == top.cs_metric_data[i].default_value) {
                    html += 'selected ';
                }
                html += 'value="' + value + '">' + value + '</option>\n';
            }
        }
        else {
            // This metric does have a current value selected.
            var found_current_value = 0;
	    for (var j = 0; j < top.cs_metric_data[i].values.length; j++) {
                var value = top.cs_metric_data[i].values[j];
                if (value == current_value) {
                    html += '<option selected value="' + value + '">' +
                            value + '</option>\n';
                    found_current_value = 1;
                }
                else {
                    html += '<option value="' + value + '">' + value +
                            '</option>\n';
                }
            }
            
            // Check if the current value was found, and if not, it must
            // represent an old metric value no longer represented in the
            // configuration file.
            if (found_current_value == 0) {
                html += '<option value="' + current_value + '">' +
                        current_value + '</option>\n';
            }
       }
       html += '</select>\n';
       html += '&nbsp;&nbsp;&nbsp;&nbsp;</td>\n';
       if (i % 2 == 1 || i == top.cs_metric_data.length-1) {
           html += '</tr>\n';
       }
    }
    if (top.cs_metric_data.length > 0) {
        html += '</table>\n';
    }

    // Now add in the email address, CC and submit buttons.
    html += '<p><table><tr>\n' +
            '<td>Your email address: </td>\n' +
            '<td>' +
            '<input type="text" name="email" size="25" maxlength="100" ' +
                   'value="' + cs_email + '">\n' +
            '</td><td></td></tr><tr>' +
	    '<td>Cc: <font size="-1">' +
            '<a href="javascript:top.add_other_reviewers(document.add_comment);">' +
            '(add other reviewers)</a></font> </td>' +
            '<td>' +
	    '<input type="text" name="comment_cc" size="25" ' +
                    'maxlength="1024"></td>\n' +
            '<td><input type="submit" name="submit" value="Submit"></td>' +
            '</tr></table></form></body></html>\n';

    // Return the generated html.
    return html;
}

// Verify that a comment is ready to be shipped out.
function verify(comment_form, status_field)
{
    // Set the global status element so it can be updated when
    // the request is being sent and received.
    top.cs_status_element = status_field;

    // Check that the comment field has a comment entered in it.
    if (comment_form.comments.value == '') {
        alert('No comment has been entered.');
        return false;
    }

    // Check that the email field has an email address in it.
    if (comment_form.email.value == '') {
        alert('No email address has been entered.');
        return false;
    }

    // Check that the metrics have been set.
    for (var i = 0; i < top.cs_metric_data.length; i++) {
        var metric_name = top.cs_metric_data[i].name;
        var name = 'comment_state_metric_' + metric_name;
        var index = comment_form.elements[name].options.selectedIndex;
        if (index == -1) {
            alert('Metric "' + metric_name + '" has not been specified.');
            return false;
        }

        var value = comment_form.elements[name].options[index].value;
        if (value == 'Select Value') {
            alert('Metric "' + metric_name + '" has not been specified.');
	    return false;
        }
    }

    // Make sure the email field is stored into the Codestriker
    // cookie, so that it is remembered for the next add comment tooltip.
    var cookie = getCookie('codestriker_cookie');
    cs_email = comment_form.email.value;
    var email_value = encodeURIComponent(cs_email);
    if (cookie == null || cookie == '') {
        cookie = 'email&' + email_value;
    }
    else if (cookie.match(/[&^]email&[^&]+/)) {
        // Email field is already in cookie.
        cookie = cookie.replace(/([&^])email&([^&]+)/, "$1email&" + email_value);
    } else {
        // Tack the email field onto the end.
        cookie += '&email&' + email_value;
    }
    setCookie('codestriker_cookie', cookie, 10 * 356 * 24 * 60 * 60);

    // If we reached here, then all metrics have been set.  Send the 
    // request as an XMLHttpRequest, and return false so the browser
    // does nothing else.
    var url = cs_add_comment_url + '/' + 
              comment_form.fn.value + '|' + comment_form.line.value + '|' +
              comment_form.newval.value + '/add';
    var params = 'action=submit_comment';
    params += '&line=' + encodeURIComponent(comment_form.line.value);
    params += '&topic=' + encodeURIComponent(comment_form.topic.value);
    params += '&fn=' + encodeURIComponent(comment_form.fn.value);
    params += '&new=' + encodeURIComponent(comment_form.newval.value);
    params += '&comments=' + encodeURIComponent(comment_form.comments.value);
    params += '&email=' + encodeURIComponent(comment_form.email.value);
    params += '&comment_cc=' + encodeURIComponent(comment_form.comment_cc.value);
    params += '&format=xml';
    
    for (var i = 0; i < top.cs_metric_data.length; i++) {
        var comment_param =
            encodeURIComponent('comment_state_metric_' + top.cs_metric_data[i].name);
        params += '&' + comment_param + '=' +
                  encodeURIComponent(eval('comment_form.' + comment_param + '.value'));
    }

    setStatusText('Submitting comment...');

    postXMLDoc(url, params);
    return false;
}

// Add all the other reviews into the Cc field of the comment frame.
function add_other_reviewers(comment_form)
{
    // Find out who the reviewers are for this review.
    var reviewers = topic_reviewers.split(/[\s,]+/);
    
    // Now check each reviewer to see if it can be added into the Cc field.
    for (var i = 0; i < reviewers.length; i++) {
        // Get the value of the Cc field and check if the reviewer is present.
        var cc_addresses = comment_form.comment_cc.value.split(/[\s,]+/);
        var found = 0;
        for (var j = 0; j < cc_addresses.length; j++) {
            if (reviewers[i] == cc_addresses[j]) {
                found = 1;
                break;
            }
        }

        // Also check if the reviewer is already in the email field.
        if (reviewers[i] == comment_form.email.value) {
            found = 1;
        }

        // If not found, append it to the Cc field.
        if (found == 0) {
            if (comment_form.comment_cc.value != '') {
                comment_form.comment_cc.value += ', ';
            }
            comment_form.comment_cc.value += reviewers[i];
        }
    }
}
    

// Create a new tooltip window which contains the html used for adding
// a comment to the topic.
function add_comment_tooltip(file, line, new_value)
{
    var html = '<a href="javascript:hideElt(getElt(\'overDiv\')); void(0);">' +
               'Close</a><p>' +
               '<iframe width="480" height="300" name="comment_frame" ' +
               'src="javascript:top.add_comment_html(' +
               file + ',' + line + ',' + new_value + ');">' +
                'This browser is not supported.  Please use ' +
                'a modern browser, such as Firefox or IE which ' +
                'supports iframes.</iframe>';
    overlib(html, STICKY, DRAGGABLE, ALTCUT, CENTERPOPUP, WIDTH, 480,
            HEIGHT, 300);
}

// Create a new tooltip window which creates a sticky, draggable
// window with a close link.
function create_window(text)
{
    overlib(text, DRAGGABLE, ALTCUT, CENTERPOPUP);
}

// Function for posting to Codestriker using the XMLHttpRequest object.
function postXMLDoc(url, params)
{
    // Check for Mozilla/Safari.
    if (window.XMLHttpRequest) {
        cs_request = new XMLHttpRequest();
    }
    // Check for IE.
    else if (window.ActiveXObject) {
        cs_request = new ActiveXObject("Microsoft.XMLHTTP");
    }

    // If the request object was created, generate the request.
    if (cs_request) {
        cs_request.onreadystatechange = top.processReqChange;
        cs_request.open("POST", url, true);
        cs_request.setRequestHeader("Content-Type",
                                    "application/x-www-form-urlencoded");
        cs_request.send(params);
    }
}

// Function for updating the status text in the add comment tooltip.
function setStatusText(newStatusText)
{
    cs_status_element.className = 'error';
    if (is.ie) {
        cs_status_element.innerText = newStatusText;
    }
    else {
        var newStatusTextNode = document.createTextNode(newStatusText);
        cs_status_element.replaceChild(newStatusTextNode, cs_status_element.childNodes[0]);
    }
}

// Function for handling state changes to the request object.
function processReqChange()
{
    // Only check for completed requests.
    if (cs_request.readyState == 4) {
        if (cs_request.status == 200) {
            var response = top.cs_request.responseXML.documentElement;
            result = response.getElementsByTagName('result')[0].firstChild.data;
            if (result == 'OK') {
                // Hide the popup if the comment was successful.
                hideElt(getElt('overDiv'));
            }
            else {
                // An error occurred, show this in the tooltip, and leave
                // it up.
                setStatusText(result);
            }
        }
        else {
            alert("There was a problem retrieving the XML data:\n" +
                  cs_request.statusText);
        }
    }
    else if (cs_request.readyState == 3) {
        setStatusText('Receiving response...');
    }
    else if (cs_request.readyState == 2) {
        setStatusText('Request sent...');
    }
}

