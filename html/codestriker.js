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

// Create the HTML necessary for adding a comment.
function add_comment_html(file, line, new_value)
{
    // Get the location of the codestriker URL.
    var l = top.location;
    var url = l.protocol + '//' + l.host + l.pathname;

    // Create the initial form, with the appropriate hidden fields.
    var html = '<html><body bgcolor="#eeeeee">\n' +
	    '<form name="add_comment" method="POST" ' +
            'action="' + url + '" ' +
            'onSubmit="return top.verify();" ' +
            'enctype="application/x-www-form-urlencoded">\n' +
	    '<input type="hidden" name="action" value="submit_comment">\n' +
	    '<input type="hidden" name="line" value="' + line + '">\n' +
	    '<input type="hidden" name="topic" value="' + cs_topicid + '">\n' +
	    '<input type="hidden" name="fn" value="' + file + '">\n' +
	    '<input type="hidden" name="new" value="' + new_value + '">\n' +
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
	var comment_number = top.comment_hash[key];
        var current_value = null;
        if (comment_number != null &&
            top.comment_metrics[comment_number] != null) {
            current_value = 
               top.comment_metrics[comment_number][top.cs_metric_data[i].name];
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
            '<a href="javascript:top.add_other_reviewers();">' +
            '(add other reviewers)</a></font> </td>' +
            '<td>' +
	    '<input type="text" name="comment_cc" size="25" ' +
                    'maxlength="150"></td>\n' +
            '<td><input type="submit" name="submit" value="Submit"></td>' +
            '</tr></table></form></body></html>\n';

    // Return the generated html.
    return html;
}

// Verify that a comment is ready to be shipped out.
function verify()
{
    // Get a reference to the comment form.
    var comment_form = top.comment_frame.document.add_comment;

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

    // If we reached here, then all metrics have been set.
    return true;
}

// Add all the other reviews into the Cc field of the comment frame.
function add_other_reviewers()
{
    // Get a reference to the comment form.
    var comment_form = top.comment_frame.document.add_comment;

    // Find out who the reviewers are for this review.
    var reviewers = top.topic_reviewers.split(/[\s,]+/);
    
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
    

// Create a new tooltip window which contains an iframe used for adding
// a comment to the topic.
function add_comment_tooltip(file, line, new_value)
{
    var html = '<a href="javascript:hideElt(getElt(\'overDiv\')); void(0);">' +
               'Close</a><p>' +
               '<iframe width="480" height="300" name="comment_frame" ' +
               'src="javascript:top.add_comment_html(' +
               file + ',' + line + ',' + new_value + ');">' +
                'Can\'t view iframe</iframe>';
    overlib(html, STICKY, DRAGGABLE, ALTCUT, CENTERPOPUP, WIDTH, 480,
            HEIGHT, 300);
}
