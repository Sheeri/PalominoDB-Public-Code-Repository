#!/usr/bin/perl
use lib '/usr/share/mysql-zrm/plugins';
use strict;
use warnings;
use Getopt::Long;
use Nagios::RemoteCmd;
use Text::ParseWords;

my $nagios_host = "";
my @nagios_services = qw();

my $nagios_user = "zrm";
my $nagios_pass = "zrm";
my $nagios_url  = "https://nagios.example.com/nagios/";

my $backup_directory = "";
my $all_databases = 0;
my $database = "";
my @databases = qw();

my @db_checkips;

@ARGV = shellwords(@ARGV) unless(scalar @ARGV > 1);

my $getopt_result = GetOptions(
  "nagios-host=s" => \$nagios_host,
  "nagios-service|s=s" => \@nagios_services,
  "backup-directory=s" => \$backup_directory,
  "all-databases" => \$all_databases,
  "databases=s" => \@databases,
  "database=s" => \$database
);

# XXX: Grab client DSN, and check it.

my $nagios = Nagios::RemoteCmd->new($nagios_url, $nagios_user, $nagios_pass);

# XXX: We disable notifications, instead of 'downtiming' because
# XXX: there is no way to get the 'downtime id' back from nagios
# XXX: with the limited API provided by nagios.
# XXX: Technically, it's not even an API, because they say not to use it.
if($nagios_host ne "") {
  print "Disabling Nagios alerts for $nagios_host\n";
  foreach my $s (@nagios_services) {
    print "Disabling: $s service.\n";
    $nagios->disable_notifications($nagios_host, $s, "Backup: $backup_directory");
  }
}
