#!/usr/bin/perl

use POSIX ":sys_wait_h";

my $UsageStatement = "\n Invalid or Missing Arguments!!!" .
                     "\n Usage: $0 <CMD File Name> \n";

die $UsageStatement unless @ARGV >= 1;

my $cmd_file = $ARGV[0];
if( ! -e $cmd_file ) {
    die "\n $cmd_file does NOT exist.";
}

open(CMDS,"<$cmd_file") || die("Failed to open $cmd_file in read mode");


my %CPU_CORE = ( 1 => "0x00000001", 
                 2 => "0x00000002",
                 3 => "0x00000004",
                 4 => "0x00000008",
                 5 => "0x00000010",
                 6 => "0x00000020",
                 7 => "0x00000040",
                 8 => "0x00000080",
               );

my %PID_CORE;
my %PID_CMD;
my @available_cores = ( 1, 2, 3, 4, 5, 6, 7, 8 );

while( <CMDS> ) 
{
	#skip blank lines
    next if( $_ =~ /^\s*$/ );  
    next if( $_ =~ /^\s*\n$/ );  
	chop($_);

	do {
	    $cmd_executed = 0;	
		if( $num_cores_available = @available_cores ) {
			$core = pop @available_cores;
			$cmd = "taskset $CPU_CORE{$core} $_";
			$childpid = fork();
			if( 0 == $childpid ) { # CHILD
				print STDOUT "\n On Core $core Executing Command: $cmd \n";
				exec $cmd; 
				print STDERR "\n Failed Execution of Cmd: $cmd \n";
				return -1;
			}
			else { #PARENT
				$cmd_executed = 1;
				$PID_CORE{$childpid} = $core;
				$PID_CMD{$childpid} = $_;
			}
		}
		else {
			while( 0 == ($num_cores_available = @available_cores) ) {
				print STDOUT "\n Waiting for some childs to finish!!! \n";
				$terminated_child = wait();
				if( -1 == $terminated_child ) {
					print STDERR "\n FATAL ERROR!! No child to wait for!!! \n";
					exit -1
				}
				print STDOUT "\n [$PID_CMD{$terminated_child}]: $terminated_child child terminated with status $?. \n";

				if( exists $PID_CORE{$terminated_child} ) {
					push (@available_cores, $PID_CORE{$terminated_child})
				}
				else {
					print STDERR "\n Terminated PID " + $terminated_child + " doesnt have entry in PID_CORE map \n";
				}
			}
		}
	} while( !$cmd_executed );
}

#wait for the other childs to finish
print STDOUT "\n Waiting for remaining childs to finish before existing!!! \n";
while ( -1 != ($terminated_child = wait()) )  {
				print STDOUT "\n [$PID_CMD{$terminated_child}]: $terminated_child child terminated with status $?. \n";
}

close(CMDS);
print STDERR "Done!!!";
