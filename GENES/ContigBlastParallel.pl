#!/usr/bin/perl -w

# This script connects to mysql and reads the table "Contig" from database "snp_database".
# For each Contig in the "Contig" table it does following 3 steps -
#  I) blastn the contig sequence against the NCBI nr database : 
#  		=> Extract E-Value, Description & Accession # from the result of blastn. 
#  		=> Insert these 3 extracted values into the table "ContigBlastn_NCBI_nr"
#		   Schema for ContigBlastn_NCBI_nr table is
#		   mysql> desc ContigBlastn_NCBI_nr;
#			+---------------+---------------+------+-----+---------+-------+
#			| Field         | Type          | Null | Key | Default | Extra |
#			+---------------+---------------+------+-----+---------+-------+
#			| name          | varchar(60)   | NO   | PRI | NULL    |       | 
#			| e_value       | varchar(10)   | YES  |     | NULL    |       | 
#			| description   | varchar(1000) | YES  |     | NULL    |       | 
#			| accession_num | varchar(50)   | YES  |     | NULL    |       | 
#			+---------------+---------------+------+-----+---------+-------+

#  II) blastx the contig sequence against the NCBI refseq_protein database :
#  		=>
#  		=>
#  III) 
#
#
#./blastn -remote -db nr -query ../Inputs/Ex_c16.fasta -outfmt 5 -max_target_seqs 1 -out ./sample.out

use DBI;
use Term::ReadKey;

#####################################
# Constant Declarations
#####################################
my $BLASTN = "blastn";
my $BLASTN_DB = "nr";
my $BLASTX = "blastx";
my $BLASTX_DB = "refseq_protein";
my $LOCAL_GRAIN_GENES_DB = "/mnt/DNA/mwaghmar/Database/GrainGenes/TC_EST_mapped.fasta";
my $DEFAULT_PROBE_EST_MAPPING_FILE = "/mnt/DNA/mwaghmar/Database/GrainGenes/ProbeESTMappings.txt";
my $TC_EST_MAPPING_FILE = "/mnt/DNA/mwaghmar/Database/GrainGenes/TC_EST_names.txt";

my $DEFAULT_DB= "snp_database";
my $DEFAULT_DB_USERNAME = "root";
my $DEFAULT_MAX_JOBS = 100;
my $NOT_AVAILABLE = "N/A";

my $DEBUG = 0;
my $INFO = 1;
my $WARNING = 2;
my $ERROR = 3;
my $FATAL = 4;
my %LOG_LEVEL_STRINGS = (	$DEBUG		=> 	"<DEBUG>", 
							$INFO 		=> 	"<INFO>", 
							$WARNING 	=>  "<WARNING>", 
							$ERROR		=>  "<ERROR>", 
							$FATAL		=>  "<FATAL>"	);

my $INSERT_QUERY = "insert into ";
my $INSERT_QUERY_OPENING = " values(";
my $QUERY_END = ");";
my $QUOTE = "'";
my $COMMA = ",";

my $BLASTN_GRAIN_GENES_TABLE = "ContigBlastn_GrainGenes";
my $BLASTN_NCBI_NR_TABLE = "ContigBlastn_NCBI_nr";
my $BLASTX_NCBI_REFSEQ_PROTEIN_TABLE = "ContigBlastx_NCBI_refseq_protein";
my $CONTIG_TABLE = "Contig";
my $CONTIG_SELECTION_QUERY = "select name, sequence from $CONTIG_TABLE";

#####################################
# Usage Statement
#####################################
my %CmdArgs;
if( @ARGV >= 1 ) {
	%CmdArgs = @ARGV[0..@ARGV-1];
}

if( (@ARGV % 2)  or exists $CmdArgs{"-h"} or exists $CmdArgs{"--help"} ) {

	my $USAGE = "\nUsage: $0 [OPTIONS]" . "\nBlasts contig sequences from Contig table against ncbi datases or local GrainGenes database." . 
				"\n\nOptions are as follows -" .
				"\n  -h, --help           See Command Help" . 
				"\n  -i, --inputdir       Input Directory Path. Default is ./Inputs" . 
				"\n  -o, --outputdir      Output Directory Path. Default is ./Outputs" . 
				"\n  -b, --blast          blast command to be used i.e. blastn or blastx or both. Default is 0 which means blastn" . 
				"\n                       Pass 0 to use blastn. Pass 1 to use blastx. Pass 2 to use both blastn & blastx" . 
				"\n                       Pass 3 to use blastn against local GrainGenes database." . 
				"\n  -j, --maxjobs        Maximum number of concurrent blast jobs. Default is $DEFAULT_MAX_JOBS" . 
				"\n  -p, --probeest       Probe EST Mapping File. Default is $DEFAULT_PROBE_EST_MAPPING_FILE" . 
				"\n  -u, --dbuser         Database user name to be used to connect to DB. Default is root" . 
				"\n  -d, --dbname         Name of the database that has Contig table. Default is snp_database" . 
				"\n  -e, --blastexe       Path of the blast executables. Default is env var PATH";

	print $USAGE, "\n\n";
	exit 0;
}

if( exists $CmdArgs{"-b"} ) {
	$CmdArgs{"--blast"} = $CmdArgs{"-b"};
}

if( exists $CmdArgs{"-e"} ) {
	$CmdArgs{"--blastexe"} = $CmdArgs{"-e"};
}

if( exists $CmdArgs{"-d"} ) {
	$CmdArgs{"--dbname"} = $CmdArgs{"-d"};
}

if( exists $CmdArgs{"-i"} ) {
	$CmdArgs{"--inputdir"} = $CmdArgs{"-i"};
}

if( exists $CmdArgs{"-o"} ) {
	$CmdArgs{"--outputdir"} = $CmdArgs{"-o"};
}

if( exists $CmdArgs{"-j"} ) {
	$CmdArgs{"--maxjobs"} = $CmdArgs{"-j"};
}

if( exists $CmdArgs{"-u"} ) {
	$CmdArgs{"--dbuser"} = $CmdArgs{"-u"};
}

if( exists $CmdArgs{"-p"} ) {
	$CmdArgs{"--probeest"} = $CmdArgs{"-p"};
}
#####################################
# Variable Declarations
#####################################
my %PARAMS = ( 	"--inputdir" 	=> ( exists $CmdArgs{"--inputdir"} ) ? $CmdArgs{"--inputdir"} : "./Inputs",
				"--outputdir" 	=> ( exists $CmdArgs{"--outputdir"} ) ? $CmdArgs{"--outputdir"} : "./Outputs",
				"--maxjobs" 	=> ( exists $CmdArgs{"--maxjobs"} ) ? $CmdArgs{"--maxjobs"} : 100,
				"--probeest" 	=> ( exists $CmdArgs{"--probeest"} ) ? $CmdArgs{"--probeest"} : $DEFAULT_PROBE_EST_MAPPING_FILE,
				"--dbuser" 		=> ( exists $CmdArgs{"--dbuser"} ) ? $CmdArgs{"--dbuser"} : $DEFAULT_DB_USERNAME,
				"--dbname" 		=> ( exists $CmdArgs{"--dbname"} ) ? $CmdArgs{"--dbname"} : $DEFAULT_DB,
				"--blast" 		=> ( exists $CmdArgs{"--blast"} ) ? $CmdArgs{"--blast"} : 0,
				"--blastexe"	=> ( exists $CmdArgs{"--blastexe"} ) ? $CmdArgs{"--blastexe"} : ""	);


my ($INPUT_DIR, $OUTPUT_DIR) = ( $PARAMS{"--inputdir"} , $PARAMS{"--outputdir"} );
my $BLAST_EXE_DIR_PATH = $PARAMS{"--blastexe"};
my $DB_USER_NAME = $PARAMS{"--dbuser"};
my $MYSQL_CONNECTION_STRING = 'dbi:mysql:' . $PARAMS{"--dbname"};

my %blastedContigs;
my %locallyBlastedContigs;

my $MAX_ACTIVE_JOBS = $PARAMS{"--maxjobs"};
my $current_active_jobs = 0;

my $RESULT_SET;
my $ContigBlastInsertQuery;

my $ContigTable_Row;
my %blast_parse;
my $blast_job_status;
my %probe_est_mapping;
my %tc_est_mapping;

#####################################
# Subroutines Forward Declarations
#####################################
sub ReadPasswordForUser;
sub blast_ncbi;
sub parse_blast_output;
sub print_log_message;
sub blast_locally;
sub parse_tc_est_mappings;
sub parse_probe_est_mappings;

#####################################
# Main Program Starts {
#####################################

$dbh = DBI->connect($MYSQL_CONNECTION_STRING, $DB_USER_NAME, &ReadPasswordForUser($DB_USER_NAME)) 
  || print_log_message($FATAL, "Connection Error: $DBI::errstr");

$RESULT_SET = $dbh->prepare($CONTIG_SELECTION_QUERY);
$RESULT_SET->execute or print_log_message($FATAL,"SQL Error: $DBI::errstr");

unless(-d $INPUT_DIR){
    mkdir $INPUT_DIR or print_log_message($FATAL, "Failed to create Input Directory $INPUT_DIR");
}

unless(-d $OUTPUT_DIR){
    mkdir $OUTPUT_DIR or print_log_message($FATAL, "Failed to create Output Directory $OUTPUT_DIR");
}

$current_active_jobs = 0;
while (@ContigTable_Row = $RESULT_SET->fetchrow_array) {

	if( 0 == $PARAMS{"--blast"} ) { #blastn against ncbi nr database.
		$blast_job_status = blast_ncbi($ContigTable_Row[0], $ContigTable_Row[1], 
									$INPUT_DIR, $OUTPUT_DIR, 
									$BLASTN, $BLASTN_DB, \$outfile); 

		if( -1 == $blast_job_status ) {
			print_log_message($ERROR, "$BLASTN failed for Contig " . $ContigTable_Row[0]);
		}
		else {
			$blastedContigs{$ContigTable_Row[0] . "_" . $BLASTN} = $outfile;
			if( 1 == $blast_job_status ) {
				$current_active_jobs++;
			}
		}
	} elsif( 1 == $PARAMS{"--blast"} ) { #blastx against ncbi refseq_protein database.
		$blast_job_status = blast_ncbi($ContigTable_Row[0], $ContigTable_Row[1], 
									$INPUT_DIR, $OUTPUT_DIR, 
									$BLASTX, $BLASTX_DB, \$outfile); 

		if( -1 == $blast_job_status ) {
			print_log_message($ERROR, "$BLASTX failed for Contig " . $ContigTable_Row[0]);
		}
		else {
			$blastedContigs{$ContigTable_Row[0] . "_" . $BLASTX} = $outfile;
			if( 1 == $blast_job_status ) {
				$current_active_jobs++;
			}
		}
	} elsif( 2 == $PARAMS{"--blast"} ) { #blastn & blastx against ncbi nr & refseq_protein databases resp.
		$blast_job_status = blast_ncbi($ContigTable_Row[0], $ContigTable_Row[1], 
									$INPUT_DIR, $OUTPUT_DIR, 
									$BLASTN, $BLASTN_DB, \$outfile); 

		if( -1 == $blast_job_status ) {
			print_log_message($ERROR, "$BLASTN failed for Contig " . $ContigTable_Row[0]);
		}
		else {
			$blastedContigs{$ContigTable_Row[0] . "_" . $BLASTN} = $outfile;
			if( 1 == $blast_job_status ) {
				$current_active_jobs++;
			}
		}

		$blast_job_status = blast_ncbi($ContigTable_Row[0], $ContigTable_Row[1], 
									$INPUT_DIR, $OUTPUT_DIR, 
									$BLASTX, $BLASTX_DB, \$outfile); 

		if( -1 == $blast_job_status ) {
			print_log_message($ERROR, "$BLASTX failed for Contig " . $ContigTable_Row[0]);
		}
		else {
			$blastedContigs{$ContigTable_Row[0] . "_" . $BLASTX} = $outfile;
			if( 1 == $blast_job_status ) {
				$current_active_jobs++;
			}
		}
	} elsif( 3 == $PARAMS{"--blast"} ) { #blastn against local TC_EST database.
		$blast_job_status = blast_locally($ContigTable_Row[0], $ContigTable_Row[1], 
								$INPUT_DIR, $OUTPUT_DIR, $BLASTN, 
								$LOCAL_GRAIN_GENES_DB, \$outfile); 

		if( -1 == $blast_job_status ) {
			print_log_message($ERROR, "$BLASTN failed for Contig " . $ContigTable_Row[0]);
		}
		else {
			$locallyBlastedContigs{$ContigTable_Row[0]} =  $outfile;
			if( 1 == $blast_job_status ) {
				$current_active_jobs++;
			}
		}
	}

	if( $current_active_jobs >= $MAX_ACTIVE_JOBS ) {
        print_log_message($INFO, "#### Maximum $current_active_jobs Jobs fired #####");	
		while( $current_active_jobs ) {
			while( 0 == ($child = waitpid(-1, WNOHANG)) ) {
			}
			print_log_message($INFO, "#### Job $child Terminated #####");	
			--$current_active_jobs;
		}
	}
} 

while( $current_active_jobs ) {
	while( 0 == ($child = waitpid(-1, WNOHANG)) ) {
	}
	print_log_message($INFO, "#### Job $child Terminated #####");	
	--$current_active_jobs;
}

if( 3 != $PARAMS{"--blast"} ) {
	foreach $contig (keys(%blastedContigs)) {
		#Empty the parsing result hash before calling parse_blast_output()
		%blast_parse = ();
		parse_blast_output($blastedContigs{$contig}, \%blast_parse) 
			|| (print_log_message($ERROR, "Failed to open blast output file: " . $outfile), next); 

		my $blast_suffix_length = length "_blastx";
		my $BLAST_TABLE = (($contig =~ /$BLASTN/) ? $BLASTN_NCBI_NR_TABLE : $BLASTX_NCBI_REFSEQ_PROTEIN_TABLE); 
		$contig = substr($contig, 0, ((length $contig) - (length "_blastx")));

		if( 0 == $blast_parse{'hit_found'} ) {
			print_log_message($ERROR, "No hits found for the Contig $contig"); 
		}

		$ContigBlastInsertQuery = $INSERT_QUERY . $BLAST_TABLE . $INSERT_QUERY_OPENING .
			$QUOTE . $contig . $QUOTE . $COMMA .
			$QUOTE . $blast_parse{'e_value'} . $QUOTE . $COMMA .
			$QUOTE . $blast_parse{'description'} . $QUOTE . $COMMA .
			$QUOTE . $blast_parse{'accession'} . $QUOTE .
			$QUERY_END;

		print "\n$ContigBlastInsertQuery";
	}
}
else { #parse locally blasted contigs
	parse_tc_est_mappings($TC_EST_MAPPING_FILE, \%tc_est_mapping); 
	parse_probe_est_mappings($PARAMS{"--probeest"}, \%probe_est_mapping); 

	foreach $contig (keys(%locallyBlastedContigs)) {
		# Empty the parsing result hash before calling parse_blast_output()
		%blast_parse = ();
		parse_blast_output($locallyBlastedContigs{$contig}, \%blast_parse) 
			|| (print_log_message($ERROR, "Failed to open blast output file: " . $outfile), next); 

		$accession = $NOT_AVAILABLE;
		$del_bin = $NOT_AVAILABLE;
		$chromosome = $NOT_AVAILABLE; 

		if( 0 == $blast_parse{'hit_found'} ) {
			$ContigBlastInsertQuery = $INSERT_QUERY . $BLASTN_GRAIN_GENES_TABLE . $INSERT_QUERY_OPENING .
				$QUOTE . $contig . $QUOTE . $COMMA .
				$QUOTE . $accession . $QUOTE . $COMMA .
				$QUOTE . $del_bin . $QUOTE . $COMMA .
				$QUOTE . $chromosome . $QUOTE .
				$QUERY_END;

			print "\n$ContigBlastInsertQuery";
		}
		else {
			my $est = "";
			if( exists $tc_est_mapping{$blast_parse{'description'}} ) {
				$est = $tc_est_mapping{$blast_parse{'description'}};
				print_log_message($DEBUG, "TC for $contig => $blast_parse{'description'}");
				print_log_message($DEBUG, "est for $contig => $est");
			}
			$accession = $est;
			if( exists $probe_est_mapping{$est} ) {
				foreach $ky (keys %{$probe_est_mapping{$est}}) {
					$del_bin = ${$probe_est_mapping{$est}{$ky}}[0];
					$chromosome = ${$probe_est_mapping{$est}{$ky}}[1];

					$ContigBlastInsertQuery = $INSERT_QUERY . $BLASTN_GRAIN_GENES_TABLE .
						$INSERT_QUERY_OPENING .
						$QUOTE . $contig . $QUOTE . $COMMA .
						$QUOTE . $accession . $QUOTE . $COMMA .
						$QUOTE . $del_bin . $QUOTE . $COMMA .
						$QUOTE . $chromosome . $QUOTE .
						$QUERY_END;

					print "\n$ContigBlastInsertQuery";
				}
			}
			else {
				$ContigBlastInsertQuery = $INSERT_QUERY . $BLASTN_GRAIN_GENES_TABLE . $INSERT_QUERY_OPENING .
					$QUOTE . $contig . $QUOTE . $COMMA .
					$QUOTE . $accession . $QUOTE . $COMMA .
					$QUOTE . $del_bin . $QUOTE . $COMMA .
					$QUOTE . $chromosome . $QUOTE .
					$QUERY_END;
				print "\n$ContigBlastInsertQuery";
			}
		}
	}
}

#####################################
# } Main Program Ends
#####################################

#####################################################
# 			Subroutines Definitions
#####################################################

sub parse_blast_output 
{
	my ($blastn_output_file, $attr_hash_ref) = @_;
    
	open(BLASTN_OUT_FILE,"<$blastn_output_file") || return 0;
	my $blastn_output = join("", <BLASTN_OUT_FILE>);
	close(BLASTN_OUT_FILE);

	$attr_hash_ref->{'hit_found'} = 1;
	if( $blastn_output =~ m/<Iteration_message>No hits found<\/Iteration_message>/ ) {
		$attr_hash_ref->{'hit_found'} = 0;
		$attr_hash_ref->{'description'} = $NOT_AVAILABLE;
		$attr_hash_ref->{'accession'} = $NOT_AVAILABLE;
		$attr_hash_ref->{'e_value'} = $NOT_AVAILABLE;
		return 1;
	}

	$attr_hash_ref->{'description'} = ( $blastn_output =~ m/<Hit_def>(.*)<\/Hit_def>/ ) ?  $1 : "Not Found in blast ouput";
	$attr_hash_ref->{'accession'} = ( $blastn_output =~ m/<Hit_accession>(.*)<\/Hit_accession>/) ?  $1 : "Not Found in blast ouput";
	$attr_hash_ref->{'e_value'} = ( $blastn_output =~ m/<Hsp_evalue>(.*)<\/Hsp_evalue>/) ?  $1 : "Not Found in blast ouput";

	return 1;
}

# returns -1 on error. 0 if it need not to fire job & 1 when it fires job.
sub blast_ncbi 
{
	my ($contig_name, $contig_seq, $input_dir, $out_dir, $blast, $blastdb, $outfile) = @_;
	my $infile = $input_dir . "/" . $contig_name . ".fasta";
	my $blast_executable = $blast;
	$$outfile = $out_dir . "/" . $contig_name . "_" . $blast . "_" . $blastdb . ".out";

  	if( -d $BLAST_EXE_DIR_PATH ) {
		$blast_executable = $BLAST_EXE_DIR_PATH . "/" . $blast ;
	}

	if( -s $infile ) {
		print_log_message($INFO, "Input file $infile already exists for the Contig $contig_name");
	}
	else {
		open(CONTIG_SEQ_FASTA,">$infile") || die "\nFailed to create file $infile"; 
		print CONTIG_SEQ_FASTA (">", $contig_name, "\n");
		print CONTIG_SEQ_FASTA ($contig_seq);
		close(CONTIG_SEQ_FASTA);
	}

    if( -s $$outfile ) {
		print_log_message($INFO, "$blast Output file $$outfile already exists for the Contig $contig_name");
		return 0;
	}

    my $blast_cmd = "$blast_executable -remote -db $blastdb -query $infile -outfmt 5 -max_target_seqs 1 -out $$outfile";

	print_log_message($INFO, "Executing Command: " . $blast_cmd);
	unless( fork() ) {
		exec $blast_cmd;
		#control reaches here only if exec fails.
		print_log_message($ERROR, "$blast failed for Contig $contig_name");
		return -1;
	}

	return 1;
}

# returns -1 on error. 0 if it need not to fire job & 1 when it fires job.
sub blast_locally
{
	my ($contig_name, $contig_seq, $input_dir, $out_dir, $blast, $blastdb, $outfile) = @_;
	my $infile = $input_dir . "/" . $contig_name . ".fasta";
	my $blast_executable = $blast;
	$$outfile = $out_dir . "/" . $contig_name . "_" . $blast . "_" . "local" . ".out";

  	if( -d $BLAST_EXE_DIR_PATH ) {
		$blast_executable = $BLAST_EXE_DIR_PATH . "/" . $blast ;
	}

	if( -s $infile ) {
		print_log_message($INFO, "Input file $infile already exists for the Contig $contig_name");
	}
	else {
		open(CONTIG_SEQ_FASTA,">$infile") || die "\nFailed to create file $infile"; 
		print CONTIG_SEQ_FASTA (">", $contig_name, "\n");
		print CONTIG_SEQ_FASTA ($contig_seq);
		close(CONTIG_SEQ_FASTA);
	}

    if( -s $$outfile ) {
		print_log_message($INFO, "$blast Output file $$outfile already exists for the Contig $contig_name");
		return 0;
	}

    my $blast_cmd = "$blast_executable -db $blastdb -query $infile -outfmt 5 -max_target_seqs 1 -out $$outfile";

	print_log_message($INFO, "Executing Command: " . $blast_cmd);
	unless( fork() ) {
		exec $blast_cmd;
		#control reaches here only if exec fails.
		print_log_message($ERROR, "$blast failed for Contig $contig_name");
		return -1;
	}

	return 1;
}

sub parse_tc_est_mappings
{
	my ($tc_est_file, $tc_est_hash_ref) = @_;
	my $line;
	my @tc_est;

	if( !-e $tc_est_file ) {
		print_log_message($FATAL, "TC EST Mapping File $tc_est_file doesn't exist");
	}

	open(TC_EST, "<$tc_est_file") || print_log_message($FATAL, "Failed to open $tc_est_file in read mode");
	while( $line = <TC_EST> )
	{
		#ignore the blank lines.
		next if( $line =~ /^\s*$/ );  
		next if( $line =~ /^\s*\n$/ );  

		chomp($line);
		@tc_est = split(/\t/, $line);
		$tc_est_hash_ref->{$tc_est[1]} = $tc_est[0];
	}

	close(TC_EST);
}

sub parse_probe_est_mappings
{
	my ($probe_est_file, $probe_est_hash_ref) = @_;
	my $line;
	my @probe_est;

	if( !-e $probe_est_file ) {
		print_log_message($FATAL, "ProbeESTMapping File $probe_est_file doesn't exist");
	}

	open(PROBE_EST, "<$probe_est_file") 
		|| print_log_message($FATAL, "Failed to open $probe_est_file in read mode");

	while( $line = <PROBE_EST> )
	{
		#ignore the blank lines.
		next if( $line =~ /^\s*$/ );  
		next if( $line =~ /^\s*\n$/ );  
		chomp($line);

		@probe_est = split(/\t/, $line);

		my $anon_array = [];
		push(@$anon_array, $probe_est[2]);
		push(@$anon_array, $probe_est[3]);
		push(@$anon_array, $probe_est[4]);
		my $ky = join(":",@$anon_array);

		if( exists $probe_est_hash_ref->{$probe_est[1]} ) {
			if( !exists $probe_est_hash_ref->{$probe_est[1]}{$ky} ) {
				$probe_est_hash_ref->{$probe_est[1]}{$ky} = $anon_array;
			}
		}
		else {
			$probe_est_hash_ref->{$probe_est[1]}{$ky} = $anon_array; 
		}
	}

	close(PROBE_EST);
}

###############################################################################
#
# @brief Subroutine that reads password for the given user from console.
# @param $USERNAME : [in] Name of the user whose password is to be taken as input from console.
#
# @return password entered on the console.
###############################################################################
sub ReadPasswordForUser
{
	(my $USERNAME) = @_;
	if( $USERNAME eq $DEFAULT_DB_USERNAME ) {
		#TODO - Later write code to read encrypted password from some file.
		return "Teheran43";
	}

	print STDOUT "Enter $USERNAME\'s Password: ";

	ReadMode 'noecho';
	$password = ReadLine 0;
	chomp $password;
	ReadMode 'normal';
	print STDOUT "\n";
	return $password;
}

sub print_log_message
{
	 my( $file, $line )= ( caller )[1,2];
	 my($loglevel, $logmsg) = @_;
	 print STDERR "\n$file:$line " . $LOG_LEVEL_STRINGS{$loglevel} . " " . $logmsg;

	 if( $FATAL == $loglevel ) 
	 {
		 die $logmsg;
	 }
}
