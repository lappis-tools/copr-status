package CoprStatus;
use strict;
use warnings;
use JSON;
use Text::Template;
use LWP::UserAgent;

$ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = 0;

sub copr_info {
  my $ua = LWP::UserAgent->new;
  $ua->timeout(300);
  $ua->env_proxy;
  $ua->ssl_opts(SSL_verify_mode => 0x00);

  my $result_v4 = $ua->get("http://copr.fedoraproject.org/api/coprs/softwarepublico/v4/monitor/");
  my $result_v5 = $ua->get("http://copr.fedoraproject.org/api/coprs/softwarepublico/v5/monitor/");

  my $json = JSON->new->allow_nonref;

  my $dec_result_v4 = $json->decode($result_v4->decoded_content);
  my $dec_result_v5 = $json->decode($result_v5->decoded_content);
  my $info = {};

  foreach(@{$dec_result_v4->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $status = $_->{'results'}{'epel-7-x86_64'}{'status'};
    my $version = $_->{'results'}{'epel-7-x86_64'}{'pkg_version'};
    $info->{$package}->{'v4_version'} = $version if $status eq "succeeded";
  }

  foreach(@{$dec_result_v5->{'packages'}}) {
    my $package = $_->{'pkg_name'};
    my $status = $_->{'results'}{'epel-7-x86_64'}{'status'};
    my $version = $_->{'results'}{'epel-7-x86_64'}{'pkg_version'};
    $info->{$package}->{'v5_version'} = $version if $status eq "succeeded";
  }

  foreach my $key (%{$info}) {
    next if(ref($key) eq 'HASH');

    my $spec = $ua->get("https://softwarepublico.gov.br/gitlab/softwarepublico/softwarepublico/raw/master/src/pkg-rpm/$key/$key.spec");
    my $version = $1 if $spec->decoded_content =~ /^Version:\s*([^\s]+)\s*$/m;
    if($version =~ /%\{version\}/) {
      $version = $1 if $spec->decoded_content =~ /define version\s*([^\s]+)\s*$/m;
    }

    my $release = $1 if $spec->decoded_content =~ /^Release:\s*([^\s]+)\s*$/m;
    $version = "$version-$release";
    $info->{$key}->{'git_version'} = $version;
  }

  return $info;
}

sub compare_versions {
  my $info = copr_info();
  my $match = {};
  foreach my $key (%{$info}) {
    next if(ref($key) eq 'HASH');
    if($info->{$key}->{'v5_version'} eq $info->{$key}->{git_version}) {
      $match->{$key} = 1;
    }
    else {
      $match->{$key} = 0;
    }
  }

  return $match;
}

sub info2html {
  my $info = copr_info();
  my $table_entries="";
  foreach my $key (%{$info}) {
    next if(ref($key) eq 'HASH');
    my $fill_v4_row;
    my $fill_v5_row;
    if($info->{$key}->{'v4_version'} eq $info->{$key}->{git_version}) {
      $fill_v4_row = "success";
    }
    else {
      $fill_v4_row = "danger";
    }

    if($info->{$key}->{'v5_version'} eq $info->{$key}->{git_version}) {
      $fill_v5_row = "success";
    }
    else {
      $fill_v5_row = "danger";
    }

    $table_entries .= "<tr>
    <td><b>$key</b></td>
    <td>$info->{$key}->{'git_version'}</td>
    <td class=\"$fill_v4_row\">$info->{$key}->{'v4_version'}</td>
    <td class=\"$fill_v5_row\">$info->{$key}->{'v5_version'}</td>
    </tr>";
  }

  return $table_entries;
}

sub build_html {
  my $data = {
    title => "SPB Copr Status",
    table_entries => info2html()
  };

  my $template = Text::Template->new(
    TYPE => 'FILE',
    SOURCE => 'template.html.tt'
  );

  return $template->fill_in(HASH => $data);
}

our %ROUTING = (
    '/'      => \&serve_html,
    '/api'  => \&serve_json,
    '/api/status'  => \&serve_json_status
    );

sub serve_html {
  return [
    '200',
    [ 'Content-Type' => 'text/html'],
    [ build_html() ],
  ];
};

sub serve_json {
  my $info = copr_info();
  my $json = JSON->new->allow_nonref;
  my $json_info = $json->encode($info);
  return [
    '200',
    [ 'Content-Type' => 'application/json'],
    [ $json_info ],
  ];
};

sub serve_json_status {
  my $info = compare_versions();
  my $json = JSON->new->allow_nonref;
  my $json_info = $json->encode($info);
  return [
    '200',
    [ 'Content-Type' => 'application/json'],
    [ $json_info ],
  ];
};

1;
