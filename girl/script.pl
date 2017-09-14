#!/usr/bin/perl


my %visited;
fun(100);

print "\nThe script has completed its execution\n";

sub fun{
 

	my $person_id = shift;

	return if(exists $visited{$person_id});
	print "\nCurrently looking at id $person_id";
	my $cmd = "wget -O out.html https://people.us.oracle.com/pls/oracle/f?p=8000:2:::::PERSON_ID:$person_id";

	$visited{"$person_id"} = 1;
	my $out = `$cmd`;

	my $text = `cat out.html`;

	if($text =~ /2A132/ && $text =~ /Hyderabad - Cyber Park/){
		print "Person ID $person_id is the girl you are looking for\n";
		exit 0;
	}


	my @person  = ($text =~ m/PERSON_ID:\d+/g);
	
	foreach my $person(@person){
       		$person =~ s/PERSON_ID://g;
		fun($person);
	}

}
