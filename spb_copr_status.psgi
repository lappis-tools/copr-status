#!/usr/bin/perl
use strict;
use warnings;
use LWP::Simple;
use JSON;
use Text::Template;
use Plack::Builder;

sub copr_info {
  my $result_v4 = get("http://copr.fedoraproject.org/api/coprs/softwarepublico/v4/monitor/");
  my $result_v5 = get("http://copr.fedoraproject.org/api/coprs/softwarepublico/v5/monitor/");

  my $json = JSON->new->allow_nonref;

  my $dec_result_v4 = $json->decode($result_v4);
  my $dec_result_v5 = $json->decode($result_v5);
  my %info;
  my $inforef = \%info;

  foreach(@{$dec_result_v4->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $status = $_->{'results'}{'epel-7-x86_64'}{'status'};
    my $version = $_->{'results'}{'epel-7-x86_64'}{'pkg_version'};
    $inforef->{$package}->{'v4_version'} = $version if $status eq "succeeded";
  }

  foreach(@{$dec_result_v5->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $status = $_->{'results'}{'epel-7-x86_64'}{'status'};
    my $version = $_->{'results'}{'epel-7-x86_64'}{'pkg_version'};
    $inforef->{$package}->{'v5_version'} = $version if $status eq "succeeded";
  }

  return $inforef;
}

sub info2html {
  my $inforef = copr_info();
  my $table_entries="";
  foreach my $key (%{$inforef}) {
    next if(ref($key) eq 'HASH');
    $table_entries .= "<tr>
    <td>$key</td>
    <td>$inforef->{$key}->{'v4_version'}</td>
    <td>$inforef->{$key}->{'v5_version'}</td>
    </tr>";
  }

  return $table_entries;
}

sub build_html {
  my $data = {
    title => "SPB Copr Stats",
    table_entries => info2html()
  };
  my $template = Text::Template->new(
    TYPE => 'FILE',
    SOURCE => 'template.html.tt'
  );
  return $template->fill_in(HASH => $data);
}

my $app = sub {
  return [
    '200',
    [ 'Content-Type' => 'text/html'],
    [ build_html() ],
  ];
};

builder {
    enable "Static", path => qr!^(/css|/js|/fonts)!;
      $app;
}
