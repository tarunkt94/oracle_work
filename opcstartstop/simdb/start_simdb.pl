#!/usr/bin/perl


use Cwd;

use strict;
use warnings;

my $idmdbDir = "/u01/database/idmdb";
unless(-d $idmdbDir){
	print "The directory $idmdbDir does not exist.\n";
	exit(1);
}

chdir("$idmdbDir");
my $cmd1 = './startup.csh' ;
my $cmd2 = './startIDMDB.sh' ;
my $cmd3 = './startOIMDB.sh' ;

my $cmd = "$cmd1 ; $cmd2 ; $cmd3";
system($cmd);

my $oiddbDir = "/u01/database/oiddb";
unless(-d $oiddbDir){
	print "The directory $oiddbDir does not exist.\n";
	exit(1);
}

chdir("$oiddbDir");

 $cmd1 = './startup.csh' ;
 $cmd2 = './startOIDPDB.sh' ;
 $cmd3 = './startOIDIDDB.sh' ;

$cmd = "$cmd1 ; $cmd2 ; $cmd3";
system($cmd);

