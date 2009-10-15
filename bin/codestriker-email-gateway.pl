#! /usr/bin/perl -w

use strict;

use Mail::Address;
use Email::MIME;
use Email::MIME::XPath;

my $codestriker_url;
my $codestriker_install_dir;

while (@ARGV) {
    my $arg = shift @ARGV;
    if ($arg eq '--codestriker-url') {
        $codestriker_url = shift @ARGV;
    }
    elsif ($arg eq '--codestriker-install-dir') {
        $codestriker_install_dir = shift @ARGV;
    }
}

if ( !(defined $codestriker_url) || !(defined $codestriker_install_dir) ) {
    die "Usage: codestriker-email-gateway.pl --codestriker-install-dir <dir> --codestriker-url <url>\n";
}

# Load the CodestrikerClient.pm module.
require $codestriker_install_dir . '/bin/CodestrikerClient.pm';

# Read the message text from stdin.
my $data;
{
    local $/ = undef;
    $data = <STDIN>;
}

# Construct the email object.
my $email = Email::MIME->new($data);

# Parse out the parameters from the message ID field.
$email->header('In-Reply-To') =~ /Codestriker\.(\d+)\.(.*)\.(.*)\.(.*)\@/;
my $topic_id = $1;
my $file_line = $2;
my $file_number = $3;
my $file_new = $4;

# Parse out the email addresses to remove the display part of the name.
my ($from) = Mail::Address->parse($email->header('From'));
$from = $from->address;

# Parse out the email CC addresses.
my @cc_list = Mail::Address->parse($email->header('Cc'));
my $cc_comment = '';
for my $cc (@cc_list) {
    $cc_comment .= ', ' if $cc_comment ne '';
    $cc_comment .= $cc->address;
}

# Grab the first text/plain part.
my ($text_part) = $email->xpath_findnodes('//plain');

my $client = CodestrikerClient->new($codestriker_url);
my $rc = $client->add_comment({topic_id => $topic_id,
                               file_number => $file_number,
                               file_line => $file_line,
                               file_new => $file_new,
                               email => $from,
                               cc => $cc_comment,
                               comment_text => $text_part->body});

# Exit with a non-zero exit code if the above call failed.
exit($rc == 0 ? 1 : 0);
