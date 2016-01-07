use warnings;
use strict;

package PackagingStatus;

# Data structure

# { repo =>
#           latest_packaging_ref =>
#                                   tag => 
#                                          value
#                                          commit => value
#                                   commit => value
#           latest_devel_ref =>
#                               tag => 
#                                       value
#                                       commit => value
#                               commit => value
# }

# Methods

# get_last_tag($repo)
# get_last_commit($repo, $branch)
# set_package_ref($repo, $tag_value, $tag_commit, $commit)
# get_devel_ref($repo)
# update_package_ref()
