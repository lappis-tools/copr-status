#!/usr/bin/perl
use strict;
use warnings;
use CoprStatus;
use Plack::Builder;
use Plack::Request;

my $app = sub {
  my $env = shift;

  my $request = Plack::Request->new($env);
  my $route = $CoprStatus::ROUTING{$request->path_info};
  if ($route) {
    return $route->($env);
  }
  return [
    '404',
    [ 'Content-Type' => 'text/html' ],
    [ '404 Not Found' ],
    ];
};

builder {
    enable "Static", path => qr!^(/css|/js)!, pass_through => 1;
      $app;
}
