#!/usr/bin/perl

if( @ARGV <= 0 ) {
		die("Insufficient Arguemnts");
}

if( !-e $ARGV[0] ) {
	die "$ARGV[0] file doesn't exist";
}

if( -d $ARGV[0] ) {
	if( $ARGV[0] =~ /(.*)\/$/ ) {
		$ARGV[0] = $1;
	}

	print "\n $ARGV[0] is a directory. Creating $ARGV[0].tar file for mail attachement. \n";
	$command_string = "tar -cf $ARGV[0].tar $ARGV[0]";
	print "\n\n Executing Command : \n $command_string \n";
	system($command_string);
   
    $ARGV[0] = $ARGV[0] . ".tar";
}

$command = "echo \"Please find attached the file $ARGV[0]\" | mutt -s \"Attached $ARGV[0]\" -d 4 -a $ARGV[0] -- ";
$my_mail_id = "manoj.waghmare\@gmail.com";

$command_string = $command . $my_mail_id;
print "\n\n Executing Command : \n $command_string \n";
system($command_string);

foreach $argnum (1 .. $#ARGV) {
		$command_string = $command . $ARGV[$argnum];
		print "\n\n Executing Command : \n $command_string \n";
		system($command_string);
}

    	
