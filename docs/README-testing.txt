		STORMON TESTSCRIPTS EXPLAINATION
-------------------------------------------------------------------------------------

*IMPORTANT! LIMITATIONS of Stormon Test Scripts*
- Cannot test binaries/c programs.
- If the output changes, all tests will need to be rebuilt.
- If a new OS command is used or the output of an existing one changes, the tests
	must be recreated.
-------------------------------------------------------------------------------------

FILES
The testing environment consists of 4 files:
	maketest - shell script; sets up environment and builds the test

	runtest - shell script; runs stormon scripts in a chroot'ed environment
		with the test files created by maketest
	
	repdir - perl script; creates a file listing all the files and directories in a
		given directory.  This is used to recreate the /dev and /devices
		directories when testing.
	
	blddir - perl script; builds a directory structure from the file created by blddir.
		All files are zero bytes in size, but character devices are recreated
		using mknod to preserve the character type.

	pretender - perl script; captures the output of an OS command and returns the output
		to standard out.  By using UNIX file system links, it 'pretends' to be
		the OS command that is linked to it.

A test is composed of the following directories:
	input/ - the output and return values of all OS commands that are called by
		the stormon script.  Also holds the files created

	gold/ - the output of each stormon metric (disks, files, swraid, volumes) with
		any references to inodes removed.

	24gold/ - the output of each stormon metric exactly as it was produced on
		the target system
	
	run/ - the output of each stormon metric from the last test
	etc/ - any necessary files from /etc (Ex: path_to_inst)
	proc/ - any necessary files from /proc (Ex: partitions)

OPERATION OVERVIEW

	-Maketest-

	The Stormon test works by changing the path of the Stormon script and using the
	pretender script to intercept OS command calls.  Maketest sets a variable 'MODE'
	to 'MAKE.'  If Utilities.pm sees this variable set, it sets the $ENV{PATH} variable
	to $HOME/oemtest/storage.  In this directory, maketest creates links of every OS command
	used by Stormon to the pretender script.  The links would look like this:
		df -> pretender
		sysdef -> pretender
		scsiinq -> pretender
		showmount -> pretender		
		...
	
	Now, when Stormon makes a call to an OS command, because of the new path,  it will 
	actually call the link with the same name in $HOME/oemtest/storage.  Because the link 
	really points to pretender, pretender gets the OS command name using the $0 variable.
	This is an example of a call to 'df -a':	
	
		Command called by Stormon:	df -a
		Script actually executing:	pretender
		$0 in pretender:		df
		@ARGV in pretender:		-a	

	Pretender will call the real OS command and save its output to the input/ directory
	in the test directory.  It will then send the output to standard out so that Stormon
	can continue executing.
	In other words, pretender calls the OS command on behalf of Stormon, saves
	the output and also sends it back to Stormon.

	The output of the Stormon scripts (disks, files, etc) is stored under 24kgold in 
	the test directory.  However, because the inode numbers cannot be replicated in the chroot
	environment, they should be ignored when running a test.  Using the unix 'cut' command,
	maketest removes all the inode fields from the output files in 24kgold and saves the
	results in gold/.  This way, when a test is run, the output can be diff'ed with the files
	in gold/ to verify the test.


	Repdir is called to create a file list of /dev and /devices (if needed).


	-Runtest-
	
	Like maketest, runtest creates links of the needed OS commands to pretender.  Instead of
	$HOME/oemtest/storage, the links are created in $CHROOT/usr/local/git/oem/storage.  
	Since the path in Utilities.pm alread includes /usr/local/git/oem/storage, no path 
	changes are needed.
	
	Instead of running the actual OS command, pretender reads the output file created by 
 	pretender in maketest.

	The output of each Stormon Metric is stored under run/ in the test directory 
	($CHROOT/usr/local/git/oem/bin).  This output is stripped of all inode fields and then
	a diff is run against the output files in gold/.

	Finally, runtest prints a report of the diffs - 'YES' means there were no differences, 
	'NO' indicates one or more differences.




		USING THE STORMON TEST SCRIPTS

RUNNING A TEST

Setup
1. Mount miata:/data/oemtest as /usr/local/git/oem/test
2. Choose a directory to use for your chroot.  In this example, /export/home 
is assumed.
3. Copy and extract <os>-smontest.tar on your filesystem.  For example, on 
solaris you would copy solaris-smontest.tar to /export/home and 
run `tar xf solaris-smontest.tar` This will create a directory 
/export/home/smontest which will be the chroot root.
4. In your stormon Makefile, insert your chroot directory at the beginning of 
GITBASE.  For example, if GITBASE=/usr/local/git, change it to 
GITBASE=/export/home/smontest/usr/local/git.
5. Run 'make.'

Running the test
As root, go to the stormon/test9i directory and run "./runtest."  Or, if you want
to run all available tests, run "./runtest -a."