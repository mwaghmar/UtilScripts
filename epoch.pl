#!/usr/bin/perl

$datestring = join(' ', @ARGV);
@datecmd = ("date", "+\%s", "--date=$datestring");
system(@datecmd);
