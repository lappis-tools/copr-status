use strict;
use warnings;
use Plack::Test;
use Test::More;

test_psgi $app, sub {
  my $cb = shift;
};
done_testing; 
