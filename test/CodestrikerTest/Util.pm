
package CodestrikerTest::Util;

require Exporter;

@ISA =    qw( Exporter );
@EXPORT = qw( MakeNewTopicName $topicTitlePrefix  );
@EXPORT_OK  = qw( );

use strict;
use warnings;

our $topicTitlePrefix = "Codestriker Test Topic: ";
our $session = int( rand() * 100000);

sub MakeNewTopicName
{
    return $topicTitlePrefix . $session . ":";
}



1;