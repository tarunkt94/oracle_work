#!/usr/bin/perl


use Cwd;

use strict;
use warnings;


chdir("/u01/database/idmdb");
my $cmd1 = './shutdown.csh' ;
my $cmd2 = './stopIDMDB.sh' ;
my $cmd3 = './stopOIMDB.sh' ;

system(" $cmd1 ; $cmd2 ; $cmd3 ");


chdir("/u01/database/oiddb");

 $cmd1 = './shutdown.csh' ;
 $cmd2 = './stopOIDPDB.sh' ;
 $cmd3 = './stopOIDIDDB.sh' ;

system(" $cmd1 ; $cmd2 ; $cmd3 ");


