package Copr::Api;
use strict;
use warnings;
use LWP::Simple;
use JSON;
# this package is not available on Debian
use RPM::VersionCompare;

my $copr_base_url = "https://copr.fedorainfracloud.org";

sub get_project_id {
  my ( $user, $repo ) = @_;
  my $project_json = get("$copr_base_url/api_2/projects?owner=$user&name=$repo");
  my $json = JSON->new->allow_nonref;
  my $project_data = $json->decode($project_json);
  return $project_data->{projects}[0]->{project}->{id};
}

sub get_project_builds {
  my ( $user, $repo ) = @_;
  my $project_id = get_project_id($user, $repo);
  my @builds;
  my $limit = 100;
  my $offset = 0;
  while($limit == 100) {
    my $builds_json = get("$copr_base_url/api_2/builds?project_id=$project_id&limit=100&offset=$offset");
    my $json = JSON->new->allow_nonref;
    my $builds_data = $json->decode($builds_json);
    push(@builds, @{$builds_data->{builds}});
    $offset += (scalar @builds);
    $limit = (scalar @builds);
  }
  return @builds;
}

# gets all latest builds of each package
sub get_latest_packages {
  my ( $user, $repo ) = @_;
  my %latest_packages;
  my @builds =  get_project_builds($user, $repo);
  foreach my $build (@builds) {
    next if $build->{build}->{state} ne "succeeded";
    my $package_name = $build->{build}->{package_name};
    my $package_version = $build->{build}->{package_version};
    my $package_submitter = $build->{build}->{submitter};
    if(!(defined $latest_packages{$package_name})) {
      $latest_packages{$package_name}{version} = $package_version;
      $latest_packages{$package_name}{submitter} = $package_submitter;
    }
    elsif(RPM::VersionCompare::labelCompare($latest_packages{$package_name}{version}, $package_version) == 1) {
      next;
    }
    else {
      $latest_packages{$package_name}{version} = $package_version;
      $latest_packages{$package_name}{submitter} = $package_submitter;
    }
  }

  return %latest_packages;
}

1;
