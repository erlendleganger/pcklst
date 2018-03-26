package pcklist;
use strict;
use warnings;
use Log::Log4perl;
use Data::Dumper;
use XML::Parser::Expat;
use XML::Simple;
#problems in SAX lib, fails on whitespace etc, so use another xml lib
$XML::Simple::PREFERRED_PARSER='XML::Parser';
use POSIX;
our $VERSION="0.1";
use base "Exporter";
our @EXPORT=qw(hello);
$Data::Dumper::Indent=1;

#-----------------------------------------------------------------------
my $xml_item;

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub parse_item(){
   my $xml=new XML::Simple;
   $xml_item=$xml->XMLin(
      qq(src/item.xml),
      keyattr=>[qw(id)],
      forcearray=>[qw(list)],
   );
   open TMP,">tmp/item.txt";print TMP Dumper($xml_item);close TMP;
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub gen_pcklist(){
   my $ref=\%{$xml_item->{item}};
   my %catdb;
   my %listids;
   my %listdb;

   #loop through all items 
   for my $id(keys %$ref){

      #pick up the category for this item, collect it in the cat db
      my $category=$xml_item->{item}{$id}{category};
      push @{$catdb{$category}},$id;

      #for this item, pick up all the lists this item belongs to
      my $aref=$xml_item->{item}{$id}{lists};
      for my $lid(@{$$aref{list}}){
         #save this list id, skip the special "all" list
         $listids{$lid}=1 if ($lid ne "all");
      }
   }
   #print Dumper(\%listids);
   #print Dumper(\%catdb);
   #print Dumper(\%listdb);

   #loop through all items again; now we know about all lists
   for my $id(keys %$ref){

      #get the category
      my $category=$xml_item->{item}{$id}{category};
      
      #for this item, loop through all the lists it belongs to
      my $aref=$xml_item->{item}{$id}{lists};
      for my $lid(@{$$aref{list}}){
         #check which list id we process now for this item
         if($lid eq "all"){
            #belongs to all lists, so add it to all lists
            for my $lid(keys %listids){
               push @{$listdb{$lid}{$category}},$id;
            }
         }
         else{
            #add the item to this list
            push @{$listdb{$lid}{$category}},$id;
         }
      }
   }
   #print Dumper(\%catdb);
   #print Dumper(\%listdb);
   for my $fmt(qw(txt md html)){
      write_pcklist($fmt,\%listdb);
   }
   return;

   #loop through all packing lists
   for my $lid(sort keys %listdb){

      #create the packing list file
      my $out="gen/pakkeliste-$lid.md";
      print "create $out\n";
      open OUT,">",$out or die("cannot create $out, stopping");
      print OUT "# Pakkeliste - $lid\n\n";

      #get all categories for this packing list
      for my $catid(sort keys %{$listdb{$lid}}){
         print OUT "## \u$catid\n\n";

         #get all items for this category on this list
         for my $id(sort{
            $xml_item->{item}{$a}{title} cmp
            $xml_item->{item}{$b}{title}
            }@{$listdb{$lid}{$catid}}){
            my $title=$xml_item->{item}{$id}{title};
            print OUT "- [ ] $title\n";
         }
      }

      close OUT
   }
   
}

sub write_pcklist(){
   my ($fmt,$ref)=@_;
   my $ext=$fmt; #can be expanded to %db{$fmt}{ext} later...
   for my $lid(sort keys %$ref){
      my $out="gen/pakkeliste-$lid.$ext";
      print "create $out\n";
      open my $fh,">",$out or die("cannot create $out, stopping");
      if($fmt eq "txt"){
         write_pcklist_txt($lid,$ref,$fh);
      }
      elsif($fmt eq "md"){
         write_pcklist_md($lid,$ref,$fh);
      }
      elsif($fmt eq "html"){
         write_pcklist_html($lid,$ref,$fh);
      }
      close $fh;
   }
}

sub write_pcklist_md(){
   my ($lid,$ref,$fh)=@_;
   print $fh "# Pakkeliste - $lid\n";
   #get all categories for this packing list
   for my $catid(sort keys %{$$ref{$lid}}){
      print $fh "\n## \u$catid\n";
      #get all items for this category on this list
      for my $id(sort{
         $xml_item->{item}{$a}{title} cmp
         $xml_item->{item}{$b}{title}
         }@{$$ref{$lid}{$catid}}){
         my $title=$xml_item->{item}{$id}{title};
         print $fh "- [ ] $title\n";
      }
   }
}

sub write_pcklist_txt(){
   my ($lid,$ref,$fh)=@_;
   print $fh "Pakkeliste - $lid\n";
   #get all categories for this packing list
   for my $catid(sort keys %{$$ref{$lid}}){
      print $fh "\n\u$catid\n";
      #get all items for this category on this list
      for my $id(sort{
         $xml_item->{item}{$a}{title} cmp
         $xml_item->{item}{$b}{title}
         }@{$$ref{$lid}{$catid}}){
         my $title=$xml_item->{item}{$id}{title};
         print $fh "[] $title\n";
      }
   }
}

sub write_pcklist_html(){
   my ($lid,$ref,$fh)=@_;
   print $fh "<html>\n<head>\n";
   my $colwidth="5.5cm";
   print $fh qq(
<style>
.checkboxgroup{
   margin-top: 2px;
   margin-left: -5px;
    width: $colwidth;
    overflow: auto;
}
.checkboxgroup p{
width: $colwidth;
text-align: left;
}
.checkboxgroup label{
width: $colwidth;
float: left;
}

body {
   font: 12pt Georgia, "Times New Roman", Times, serif;
   line-height: 1.3;
}

h1 {
font-size: 18pt;
}

h2 {
   font-size: 14pt;
   margin-top: 5px;
   margin-bottom: 0px;
}

div {
    column-count: 3;
}

</style>
);

   print $fh "</head>\n<body>\n";
   print $fh "<h1>Pakkeliste - $lid</h1>\n";
      print $fh qq(<div id="packinglist">\n);
   #get all categories for this packing list
   for my $catid(sort keys %{$$ref{$lid}}){
      #get all items for this category on this list
      #print $fh qq(<div id="checkboxes">\n<ul>\n);
      print $fh qq(<fieldset class="checkboxgroup">\n);
      print $fh "<h2>\u$catid</h2>\n";
      for my $id(sort{
         $xml_item->{item}{$a}{title} cmp
         $xml_item->{item}{$b}{title}
         }@{$$ref{$lid}{$catid}}){
         my $title=$xml_item->{item}{$id}{title};
         #print $fh "<li>$title</li>\n";
         print $fh qq(<label><input type="checkbox">$title</label>\n);
      }
      #print $fh "</ul>\n</div>\n";
      print $fh qq(</fieldset>\n);

   }
      print $fh qq(</div>\n);

   print $fh "</body>\n</html>\n";
}

1;

__DATA__

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub list_race(){
   my $ref=\%{$xml_race->{race}};
   for my $id(sort {$$ref{$a}{raceDate} cmp $$ref{$b}{raceDate}}keys %$ref){
      my $raceDate=$$ref{$id}{raceDate};
      my $raceRaceTime=$$ref{$id}{raceRaceTime};
      my $competitionId=$$ref{$id}{competitionId};
      my $competitionName=$xml_competition->{competition}{$competitionId}{competitionName};
      my $competitionType=$xml_competition->{competition}{$competitionId}{competitionType};
      my $locationId=$xml_competition->{competition}{$competitionId}{locationIdStart};
      my $locationName=$xml_location->{location}{$locationId}{locationName};
      my $subregionId=$xml_location->{location}{$locationId}{subregionId};
      my $subregionName=$xml_subregion->{subregion}{$subregionId}{subregionName};
      my $regionId=$xml_subregion->{subregion}{$subregionId}{regionId};
      my $regionName=$xml_region->{region}{$regionId}{regionName};
      my $nationId=$xml_region->{region}{$regionId}{nationId};
      my $nationName=$xml_nation->{nation}{$nationId}{nationName};
      my $continentId=$xml_nation->{nation}{$nationId}{continentId};
      my $continentName=$xml_continent->{continent}{$continentId}{continentName};
      print "$id,$competitionType,$raceDate,$raceRaceTime,$competitionName,$locationName,$subregionName,$regionName,$nationName,$continentName\n";
   }
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub gen_mapchart_json_50states(){
   my %db;
   my $year=2018;

   #-----------------------------------------------------------------------
   #scan for marathon in us states
   my $ref=\%{$xml_race->{race}};
   for my $id(keys %$ref){
      
      #-----------------------------------------------------------------------
      #look for year
      my $raceDate=$$ref{$id}{raceDate};
      next if (substr($raceDate,0,4) gt qq($year));
      
      #-----------------------------------------------------------------------
      #look for marathons
      my $competitionId=$$ref{$id}{competitionId};
      my $competitionType=$xml_competition->{competition}{$competitionId}{competitionType};
      next if (
         $competitionType ne "r-42k" and 
         $competitionType ne "r-50k" and 
         $competitionType ne "r-ultra" and 
      1 eq 1);
      
      #-----------------------------------------------------------------------
      #look for USA
      my $locationId=$xml_competition->{competition}{$competitionId}{locationIdStart};
      my $subregionId=$xml_location->{location}{$locationId}{subregionId};
      my $regionId=$xml_subregion->{subregion}{$subregionId}{regionId};
      my $nationId=$xml_region->{region}{$regionId}{nationId};
      my $nationName=$xml_nation->{nation}{$nationId}{nationName};
      next if ($nationName ne "USA");
      
      #-----------------------------------------------------------------------
      #pick up the state
      #my $regionAbbreviation=$xml_region->{region}{$regionId}{regionAbbreviation};
      my $regionName=$xml_region->{region}{$regionId}{regionName};
      my $regionAbbreviation=usa::get_state_code($regionName);
      die "No state abbreviation found for regionid=$regionId, stopping" if(!$regionAbbreviation);
      $db{$regionAbbreviation}=1;
   }
  
   #-----------------------------------------------------------------------
   #calculate result
   my $statelist=join ",",map {qq("$_")} sort keys %db;
   my $statecount=keys %db;
   
   #-----------------------------------------------------------------------
   #output result
   print <<EOT
{
  "groups": {
    "#0868ac": {
      "div": "#box0",
      "label": "Mine maratonstater ($statecount stk)",
      "paths": [ $statelist ]
    }
  },
  "title": "50 states - $year",
  "hidden": [ ],
  "borders": "#000000"
}
EOT
   ;
}

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
sub gen_race_list_50states(){
   my %db;

   #-----------------------------------------------------------------------
   #scan for marathon in us states
   my $ref=\%{$xml_race->{race}};
   for my $id(keys %$ref){
      
      #-----------------------------------------------------------------------
      #look for year
      #next if (substr($raceDate,0,4) gt qq($year));
      
      #-----------------------------------------------------------------------
      #look for marathon+ races
      my $competitionId=$$ref{$id}{competitionId};
      my $competitionType=$xml_competition->{competition}{$competitionId}{competitionType};
      next if (
         $competitionType ne "r-42k" and 
         $competitionType ne "r-50k" and 
         $competitionType ne "r-ultra" and 
      1 eq 1);
      
      #-----------------------------------------------------------------------
      #look for USA
      my $locationId=$xml_competition->{competition}{$competitionId}{locationIdStart};
      my $subregionId=$xml_location->{location}{$locationId}{subregionId};
      my $regionId=$xml_subregion->{subregion}{$subregionId}{regionId};
      my $nationId=$xml_region->{region}{$regionId}{nationId};
      my $nationName=$xml_nation->{nation}{$nationId}{nationName};
      next if ($nationName ne "USA");
      
      #-----------------------------------------------------------------------
      #pick up the state abbreviation
      my $regionName=$xml_region->{region}{$regionId}{regionName};
      my $regionAbbreviation=usa::get_state_code($regionName);
      die "No state abbreviation found for regionid=$regionId, stopping" if(!$regionAbbreviation);
      
      #-----------------------------------------------------------------------
      #record the race id if the state has not been seen before
      if(!$db{$regionAbbreviation}){
         $db{$regionAbbreviation}=$id;
      }
   }

   #--------------------------------------------------------------------------
   my $cnt=1;
   for my $id(sort{$$ref{$db{$a}}{raceDate} cmp $$ref{$db{$b}}{raceDate}} keys %db){
      my $raceId=$db{$id};
      my $raceTime=$$ref{$raceId}{raceRaceTime};
      my $raceDate=$$ref{$raceId}{raceDate};
      my $competitionId=$$ref{$raceId}{competitionId};
      my $competitionName=$xml_competition->{competition}{$competitionId}{competitionName};
      my $locationId=$xml_competition->{competition}{$competitionId}{locationIdStart};
      my $locationName=$xml_location->{location}{$locationId}{locationName};
      print $cnt++,",$raceDate,$raceTime,$competitionName,$locationName,$id,USA\n";
   }
}

1;
