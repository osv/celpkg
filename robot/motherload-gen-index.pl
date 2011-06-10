#!/usr/bin/perl -w
use Getopt::Long;
use File::Path;
use File::Basename;
use Term::ANSIColor;

@banned_dir = ("__MACOSX");
@banned_files = (".DS_Store", "Thumbs.db", "~");

$ok = GetOptions("help", "stage1", "stage2", "stage3", "stage4",
		 "cleans1", "cleanok", "dupdownload", "done",
		 "printmenu", "menu=s", "distfiles=s", "workdir=s", "force",
		 "indexdir=s");

$FIND = "/usr/bin/find";
$MD5 = "md5 -q";

$default_workdir = "./work/";
if ($opt_workdir) {
    $default_workdir = $opt_workdir;
}

$indexdir = "$default_workdir/userindex";
if ($opt_indexdir) {
    $indexdir = $opt_indexdir;
}

$distfiles = "./$default_workdir/distfiles";

if (!$ok)
{
    print $ok;
    exit;
}

($scriptname, $scriptpath, $scriptsuffix ) = fileparse( $0, "\.[^.]*");
if ($opt_help) {
    print "
Usage: $0 [Options...]

 --stage1          Create .index.s1 from www.celestiamotherlode.net
                   You may need to run --cleans1 first
 --stage2          Search in .index.s1 files downloads and put into work/downloads.lst.
 --stage3          Download all from work/downloads.lst into DISTFILES dir
 --stage4          Use downloaded files and create .index.ok with \$unpack
                   \$distfile target. Please, review all files .index.ok and
                   check filelist of \$distfile (files *.dwn.lst) and rename
                   to .index if all ok (or run --stage5 to batch renaming).
                   Also Ignore if .index.ok file already exist with \":DONE:\" mark.
 --done            Search in all .index.ok \":DONE:\" mark. Move marked files as .index

 --cleans1         Remove .index.s1 files (created by --stage1).
 --cleanok         Remove .index.ok files (created by --stage4).
 --dupdownload     Find duplicate files for download.

 --workdir         Set temp working dir. (Default ./work).
 --indexdir        Set index dir. (Default \$workdir/userindex)
 --distfiles       Set distfiles dir. Use it with --stage3 --stage4
 --printmenu       Show available menu
 --menu            Set menu for loading. (Default all menu)

Run this  script with `--stage1' parameter.  It  will create .index.s1
files. You must review all  files and comment unneeded DOWNLOAD before
stage 2.

Stage 2 - create download list.

Stage 3  - download files into DISTFILES  dir (default work/distfiles)
you  can change  it by  `--distfiles'  param. You  can download  files
manually into $distfiles.

Stage  4 -  examine archives  for banned  files and  created \$install
targer in index.  After that you need final  review all .index.ok, put
:DONE: or :IGNORE: in any place of index.ok.

Final stage - run with `--done' to create .index files

* Note: To disable ansi colors set ANSI_COLORS_DISABLED environment.

Example:

$scriptname --cleans1 --indexdir ~/temp/celestia/pkg/userindex/celpkg-index/ --distfiles ~/temp/celestia/pkg/distfiles/
$scriptname --stage1 --indexdir ~/temp/celestia/pkg/userindex/celpkg-index/ --distfiles ~/temp/celestia/pkg/distfiles/
$scriptname --stage2 --indexdir ~/temp/celestia/pkg/userindex/celpkg-index/ --distfiles ~/temp/celestia/pkg/distfiles/
$scriptname --stage3 --indexdir ~/temp/celestia/pkg/userindex/celpkg-index/ --distfiles ~/temp/celestia/pkg/distfiles/
$scriptname --stage4 --indexdir ~/temp/celestia/pkg/userindex/celpkg-index/ --distfiles ~/temp/celestia/pkg/distfiles/
\n";


    exit;
}

# menu from mlmenu.js, it used for category name too
%menu = (
"3" => ["Solar System", "catalog/solarsystem.php"],
    "3_1" => ["Sol", "catalog/sol.php"],
    "3_2" => ["Mercury", "catalog/mercury.php"],
    "3_3" => ["Venus", "catalog/venus.php"],

 "3_4" => ["Earth", "catalog/earth.php"],
    "3_4_1" => ["Surface maps", "catalog/earth.php"],
    "3_4_2" => ["Bump, Normal, Spec maps", "catalog/earthbumpspec.php"],
    "3_4_3" => ["Cloud maps", "catalog/earthcloud.php"],
    "3_4_4" => ["Night maps", "catalog/earthnight.php"],
    "3_4_5" => ["Virtual Texture Close-ups", "catalog/earthcloseup.php"],
    "3_4_6" => ["Other", "catalog/earthother.php"],
    "3_4_7" => ["Moon", "catalog/moon.php"],

 "3_5" => ["Mars", "catalog/mars.php"],
    "3_5_1" => ["Surface maps", "catalog/mars.php"],
    "3_5_2" => ["Bump, Normal maps", "catalog/marsbump.php"],
    "3_5_3" => ["Cloud maps", "catalog/marscloud.php"],
    "3_5_4" => ["Moons", "catalog/marsmoons.php"],
    "3_6" => ["Jupiter", "catalog/jupiter.php"],
    "3_7" => ["Saturn", "catalog/saturn.php"],
    "3_8" => ["Uranus", "catalog/uranus.php"],
    "3_9" => ["Neptune", "catalog/neptune.php"],
    "3_10" => ["Kuiper Belt", "catalog/kuiperbelt.php"],
    "3_11" => ["Asteroids", "catalog/asteroids.php"],
    "3_12" => ["Comets", "catalog/comets.php"],

"4" => ["Spacecraft", "catalog/spacecraft.php"],
    "4_1" => ["Earth-orbit", "catalog/satellites.php"],
#    "4_2" => ["Other", "catalog/spacecraft.php"],
"5" => ["Extrasolar", "catalog/galaxies.php"],
    "5_1" => ["Galaxies", "catalog/galaxies.php"],
    "5_2" => ["Messier Nebulae", "catalog/messiernebulae.php"],
    "5_3" => ["Other Nebulae", "catalog/nonmessiernebulae.php"],
    "5_4" => ["Data Plots", "catalog/dataplots.php"],
    "5_5" => ["Stars", "catalog/extrasolar_stars.php"],
"6" => ["Fictional", "catalog/fictional.php"],
    "6_1" => ["2001", "catalog/fic_2001.php"],
    "6_2" => ["ArcBuilders", "catalog/fic_arcbuilder.php"],
    "6_3" => ["Babylon 5", "catalog/fic_babylon5.php"],
    "6_4" => ["Orion's Arm", "catalog/fic_orionsarm.php"],
    "6_5" => ["Star Trek", "catalog/fic_startrek.php"],
    "6_6" => ["Star Wars", "catalog/fic_starwars.php"],
#    "6_7" => ["Other", "catalog/fictional.php"],
#    "6_7_1" => ["Craft & Stations", "catalog/fictional.php#1700"],
#    "6_7_2" => ["Planets & Systems", "catalog/fictional.php#1800"],
    
# 7 => ["Resources", "catalog/resources.html"],
#     7_1 => ["Documentation", "catalog/documentation.html"],
#     7_2 => ["Scripts", "catalog/scripts.php"],
#     7_3 => ["Educational", "catalog/educational.php"],
#     7_4 => ["Utilities", "catalog/utilities.html"],
#     7_5 => ["Creator Links", "creators.html"],
    );

if ($opt_printmenu) {
    for my $key ( sort keys %menu ) {
        my $value = $menu{$key}[0];
        print "$key => $value\n";
    }
}

if ($opt_distfiles) {
    $distfiles = $opt_distfiles;
}

unless($opt_menu) {
    foreach $m (keys %menu) { 
	push (@parsemenus, $m);
    }
} else {
    push (@parsemenus, $opt_menu);
}

sub uniq {
    my %h;
    return grep { !$h{$_}++ } @_
}

# get uniq addon name
sub getUniqName {
    my $addname = $_[0];
    my $i = 2;
    my $workdir = "$indexdir/";
    my @sameadd = `$FIND \"$workdir\" -name \"$addname.index.s1\"`;
    if (scalar @sameadd) {
	print color "red";
	print "Warning not uniq addon name found: $addname\n";
	while (1) {
	    $newname = "$addname $i";
	    @sameadd = `$FIND \"$workdir\" -name \"$newname.index.s1\"`;
	    if (scalar @sameadd) {
		$i++;
	    } else {
		print color "bold";
		print "New name is\t$newname\n";
		print color "reset";

		return $newname;
	    }
	}
    }
    return "$addname";
}

# pars data files
sub parseAddonHtml {
    my $url = $_[0];
    my $category = $_[1];
    print "==>  Addon www: $url\n";
    my $workdir = "$indexdir/";
    # download addon html body
    mkpath($default_workdir);
    my $htmlfile = "$default_workdir/index.html";
    `wget --no-directories -nv http://www.celestiamotherlode.net/catalog/$url -O \"$htmlfile\"`;
    my $data = `cat $htmlfile`;

    my $addonname;

    # decide category and name
    if ($data =~ /<h1><a href=.*>(.+)<\/a>:<br>(.*)<\/h1>/g)
    {
	$name = "$2";
	if ($name =~ m/(.*)\s*:\s*(.*)/)
	{
	    $category = "$category/$1";
	    $name = $2;
	    $category =~s/\s*:\s*/\//g;
	}
	$name =~s/&#38;/ /g;
	$name =~s/\s*\/\s*/ /g;

	$name =~s/^\s+//;
	$name =~s/\s+$//;
	$addonname = $name;

	$addonname =~ s/\&amp\;/\&/g;
	$addonname =~ s/%20/ /g;
	$addonname =~ s/%27/'/g;
	$addonname =~ s/%26/&/g;

	print "Decided name:";
	print color "green";
	print "\t\t$addonname\n";
	print color "reset";

	print "Decided category:";
	print color "green";
	print "\t$category\n";
	print color "reset";
	# check for empty addon name
	if ($addonname=~/^\s*$/) {
	    print color "white on_red";
    	    print "Warning: addon have no name: $url\n";
	    print color "reset";
	    return;
	}

	# check if same addon exist
	$addonname = getUniqName($addonname);
    } else {
	print "Error: can not parse addon info page. Addon name not found.\n";
	return;
    }

    mkpath "$workdir/$category";

    my $f = "$workdir/$category/$addonname.index.s1";
    if (skip_ok_file($f)) {
	return;
    }

    # create .index.s1 
    open FILE, ">", $f or {return print "$!, index src file not cteated"};

    print FILE "# -*-coding: utf-8; mode: tcl -*-\n";
    print FILE "# Created by robot $scriptname\n";
    print FILE "\$addon \"$addonname\"\n";
    print FILE "\$category {$category} {Experimental/Robot/$category}\n";
    sub printdescr {
	$text = $_[0];
	# $text =~s/<A\s+HREF="(.*)">.*<\/A>/$1/gi;
	print FILE "\$description $text\n";	    
    }

    # this sub  will check text  for catalog name, celestia  have many
    # addons for one stuff, need conflict search
    
    sub checkConflictName {
	my $text = $_[0];
	my @cfl = ();

	my @catalognames = ("M", "NGC", "IC", "MyCn",
			 "2MASS", "Abell", "AC", "BD", "C", 
			 "CCDM", "CD", "COROT", "CPD", "DDO", 
			 "FK4", "FK5", "GC", "GCVS", "Gl", "GJ", 
			 "GSC", "HD", "HIP", "HR", "IC", "IDS", 
			 "KIC", "MCG", "NGC", "NHICAT", "NSV", 
			 "OGLE", "PGC", "RCW", "RECONS", "RNGC", 
			 "ROSAT", "SAO", "CAO", "SDSS", "STF",
			 "TYC", "UGC", "WDSC", "UCAC2", "WASP", "PSR"
	    );

	foreach my $catalog (@catalognames) { 
	    while ($text =~ /(\s+|^)$catalog(\s|[-])*([0-9-+]+[0-9-+a-zA-Z]*)/gi)
	    {
		push @cfl, uc("$catalog$3");
	    }
	}

	return @cfl;
    }

    if ($data =~ /Version:<\/td><td style="vertical-align: top">(.*)<\/td><\/tr>/)
    {
	if ($1 ne "unknown") {
	    print FILE "\$version {$1}\n";
	} else {
	    print FILE "# default version!\n\$version 1.0\n";
	}
    }

    if ($data =~ /Added:<\/td><td style="vertical-align: top">(\d\d\d\d-\d\d-\d\d).*<\/td><\/tr>/)
    {
	print FILE "\$created $1\n"
    }

    if ($data =~ /Last modified:<\/td><td style="vertical-align: top">(\d\d\d\d-\d\d-\d\d).*<\/td><\/tr>/)
    {
	print FILE "\$modified $1\n"
    }

    my @conflicts = ();
    push (@conflicts, checkConflictName($addonname));

    if ($data =~ /Summary:<\/td><td style="vertical-align: top">(.+)<\/td>/)
    {
	printdescr($1);
	push (@conflicts, checkConflictName($1));
    }

    if (scalar @conflicts) {
	@conflicts = uniq(@conflicts);

	print "conflicts:\t";
	print color "red";
	print "'@conflicts'\n";
	print color "reset";
 	print FILE "\$conflicts";
	foreach $c (@conflicts) {
	    print FILE " $c";
	}
	print FILE "\n";
    }

    if ($data =~ /Description:<\/td><td style="vertical-align: top">(.+)<\/td><\/tr>/)
    {
	printdescr($1);
    }
    
    if ($data =~ /Addon Homepage:<\/td><td style="vertical-align: top"><a href="(.+)">.+<\/a><\/td><\/tr>/)
    {
	print FILE "\$www \"$1\"\n";
    }
    print FILE "\$www \"http://www.celestiamotherlode.net/catalog/$url\"\n";

    if ($data =~ /License:<\/td><td style="vertical-align: top">(.+)<\/td><\/tr>/)
    {
	print FILE "\$license \"$1\"\n";
    }
    
    if ($data =~ /Creator:<\/td><td style="vertical-align: top"><a href=".*">(.*)<\/a><br>(.*)<\/td><\/tr>/)
    {
	$other = $2;
	print FILE "\$author {$1} $2\n";
	if ($other) {
	    print FILE "\$author {$other\}\n";
	}
    }
    
    if ($data =~ /Download:(.*)<\/table>/s)
    {
	$dwn = $1;
	while($dwn =~ m/objlink" href="(.+)">.*<\/a>/g) {
	    print FILE "DOWNLOAD $1\n";
	}
    }
    
    # screenshots
    while($dwn =~ m/<a href="\/catalog\/images\/screenshots\/(.+)" ONCLICK="/g) {
	print FILE "\$screenshot {
    http://www.celestiamotherlode.net/catalog/images/screenshots/$1
    http://www.celestiamotherlode.net/catalog/images/thumbs/$1 }\n";
    }

    close (FILE);
}

sub solveCategoryName {
    my $menuindex = $_[0];
    my $category;
    my $mi;
    foreach my $i (split(/_/, $menuindex)) {
	if ($mi) {
	    $mi = "${mi}_$i";
	    $category = "$category/$menu{$mi}[0]";
    	} else {
	    $mi = "$i";
	    $category = "$menu{$i}[0]";
	}
    }
    return $category;
}

sub parseIndex {
    my $m = $_[0]; # menu index
    my $workdir = "$indexdir/";
    mkpath "$workdir";
    mkpath($default_workdir);
    my $htmlfile = "$default_workdir/index.html";
    # download 
    `wget --no-directories http://www.celestiamotherlode.net/$menu{$m}[1] -O \"$htmlfile\"`;
    my $data = `cat $htmlfile`;
    my $category = solveCategoryName($m);
    print "Category: $category\n";

    while($data =~ m/<a href="(show_addon_details\.php\?addon_id=.*)"><img src="\/siteimages\/layout\/looking_glas.gif"/g) {
	parseAddonHtml($1, $category);
    }
}

sub skip_ok_file {
    my $f = $_[0];
    if (-e $f ) {
	open(DAT, $f) || die("Could not open file!"); 
	my @dat=<DAT>;
	close DAT;
	my $skip = 0;
	foreach my $d (@dat){
	    if ($d =~m/:DONE:/) {
		$skip = 1;
		print color "bold green";
		print "File finished, skip.\n";
		print color "reset";
		last; 
	    } elsif ($d =~m/:IGNORE:/) {
		$skip = 1;
		print color "bold yellow";
		print "File marked for ingore, skip.\n";
		print color "reset";
		last; 
	    }
	}
	if ($skip) {
	    return 1;
	}
    }
    return 0;
}

if ($opt_cleans1) {
    `$FIND $indexdir -name "*.index.s1" -type f -print0 |xargs -0 rm`;
    exit;
}

if ($opt_cleanok) {
    my @files = `$FIND $indexdir -name "*.index.ok"`;
    foreach $f (@files) {
	chomp($f);
	if (!skip_ok_file($f)) {
	    unlink($f);
	}
    }
    exit;
}

# stage 3
if ($opt_dupdownload) {
    my @dists = `cat $default_workdir/downloads.lst`;
    my %duplicates;
    print "Duplicate downloads:\n";
    foreach my $d (@dists) {
	my ($flname, $url, $flsuffix ) = fileparse( $d, "\.[^.]*");
	if (defined $duplicates{"$flname$flsuffix"} ){
	    print "$flname$flsuffix";
	}
	$duplicates{"$flname$flsuffix"}++; 
    }

    print " * Check $distfiles if duplicate files\n";
}


# stage 1
if ($opt_stage1) {
    print "===>  Create *.index.s1 files from www\n";
    foreach my $m (@parsemenus) {
	print "$m\n";
	if ($menu{$m}) {
	    print "===>  Parse menu: $m [$menu{$m}[0]]\n" ;
	    parseIndex $m;
	}
    }
    print "* Now check all .index.s1 files for downloads before using --stage2\n";
    exit;
}

# file if list of downloads
# stage 2
$download_list = "$default_workdir/downloads.lst";
if ($opt_stage2) {
    print "===>  Create distfiles ($download_list)\n";
    unlink($download_list);
    system("$FIND \"$indexdir\" -name \"*.index.s1\" -type f -print0 | xargs -0 grep -e DOWNLOAD | sed -e 's/\\&amp\\;/\\&/g' | sed -e 's/.*DOWNLOAD //'  > $download_list");
    print "Done\n";
}

# stage 3
if ($opt_stage3) {
    print "===>  Download dist files\n";
    mkpath($distfiles);
    `wget -c -P \"$distfiles\" -i \"$download_list\"`;
    print "Done\n";
}

if ($opt_stage4) {
    print "===>  Create .index.ok with \$distfiles \$unpack\n";
    my @files = `$FIND $indexdir -name "*.index.s1"`;
    foreach my $f (@files) {
	chomp($f);
	my $addonname = basename($f, ".index.s1");
	if (!open FILESRC, "<", $f)
	{
	    print "$f $!, index src file not found\n";
	    next;
	}

	my @lines = `cat "$f"`;


	$f =~ s/index\.s1/index\.ok/;
	print "==> $f\n";

	# check if file is finished
	if (skip_ok_file($f)) {
	    next;
	}

	if (!open FILEOK, ">", $f) {
	    print "$f $!\n";
	    close (FILESRC);
	    next;
	}

	my $dirname = dirname($f);
	# file list in archives
	my $arhcfilelist = "$dirname/$addonname.filelist";
	unlink($arhcfilelist);

	foreach my $line (@lines) {
	    chomp($line);

	    if ($line =~/^\s*DOWNLOAD\s+(.*)/) {
		my $disturl = $1;
		# replace &amp; to &, sad, but wget dont like this
		$disturl =~ s/\&amp\;/\&/g;
		$disturl =~/.*\/(.*)/;
		# get potential downloaded file name
		my $distname = $1;
		$distname =~ s/%20/ /g;
		$distname =~ s/%27/'/g;
		$distname =~ s/%26/&/g;

		print "distname: ";
		print color "red";
		print "$distname\n";
		print color "reset";

		$distname =~/\.([^.]*)/;
		my $sufix = $1;

		my $filesz = -s "$distfiles/$distname";
		my $md5 = `$MD5 "$distfiles/$distname"`;
		chomp($md5);

		print FILEOK "\$distfile {
    -name \"$distname\" -size $filesz -md5 $md5
    -url $disturl }
";
		if ($sufix =~ /^zip$/i) {
		    print FILEOK "\$unpack {\n";
		    print FILEOK "    -file \"$distname\" -type zip\n";
		    `unzip -l "$distfiles/$distname" >> "$arhcfilelist"`;
		    $extras = `unzip -l "$distfiles/$distname"| grep "extras/" | wc -l | awk '{print \$1}'`;
		    chomp $extras;
		    $extras =~s/\s//g;
		    
		    if (!$extras) {
			print FILEOK "    -dir \"extras/$addonname\" }\n";
			print " unpack to:\t\"extras/$addonname\"\n";
		    } else {
			print FILEOK "}\n";
		    }
		}
	    } else {
		$line =~s/&#38;/&/g;
		$line =~s/&amp;/&/g;
		$line =~s/<[\/]*[B]>/"/gi;
		$line =~s/<[\/]*[I]>//gi;
		print FILEOK "$line\n";
	    }
	}

	# check for banned files
	if (-e "$arhcfilelist") {
	    my %install = ();
	    $res = `cat "$arhcfilelist"`;
	    foreach $d (@banned_dir) {
		if ($res=~m/$d/) {
		    if (!exists($install{$d})) {
			$install{$d}="    {\"$d*\" -deny}";
		    }
		    print color "blue bold";
		    print  " banned dir:\t$d\n";
		    print color "reset";
		}
	    }
	    foreach $f (@banned_files) {
		if ($res=~m/$f/) {
		    if (!exists($install{$f})) {
			$install{$f}="    {\"$f\" -skip}";
		    }
		    print color "blue bold";
		    print " banned dir:\t$f\n";
		    print color "reset";
		}
	    }

	    if (keys %install) {
		print FILEOK "\$install\n";
		foreach my $key (keys (%install)) {
		    print FILEOK "$install{$key}\n";
		}
		print FILEOK "    {}\n";
	    }
	}
	print FILEOK "\$end\n"; # mark end

	close (FILEOK);
    }
    print "Done\n";
}

if ($opt_done) {
    print "===>  Search for :DONE: in .index.ok and copy to as .index\n";
    my @files = `$FIND $indexdir -name "*.index.ok"`;
    my $num = 0;
    my $all = 0;
    foreach my $f (@files) {
	chomp($f);
	my $addonname = basename($f, ".index.s1");
	# check if file is 
	if (-e $f ) {
	    open(DAT, $f) || die("Could not open file!"); 
	    my @dat=<DAT>;
	    close DAT;
	    my $done = 0;
	    foreach my $d (@dat){
		if ($d =~m/:DONE:/) {
		    $done = true;
		    last; 
		}
	    }
	    # create index file withou :DONE:
	    if ($done) {
		$f =~ s/index\.ok/index/;
		print color "bold green";
		print "==> $f\n";
		print color "reset";

		if (!open FILE, ">", $f) {
		    print "$f $!\n";
		}

		# ignore tags
		foreach my $d (@dat) {
		    $d =~s/:DONE://g;
		    $d =~s/:IGNORE://g;
		    print FILE $d;
		}
		close FILE;
		$num++;
	    }
	}
	$all++
    }
    print "Total: $num of $all\n";
}
