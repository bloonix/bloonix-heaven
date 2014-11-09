use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    create_readme => 0,
    create_makefile_pl => "traditional",
    module_name => "Bloonix::Heaven",
    dist_author => "Jonny Schulz",
    dist_abstract => "Bloonix Web Framework",
    dist_version => "0.4",
    sign => 0,
    requires => {
        "Bloonix::Core" => 0,
        "Bloonix::FCGI" => 0,
        "Getopt::Long" => 0,
        "JSON" => 0,
        "Log::Handler" => 0,
        "POSIX" => 0
    },
);

$build->create_build_script;
