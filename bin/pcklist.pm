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

   #loop through all items to pack
   for my $id(keys %$ref){

      #pick up the category for this item, collect in db
      my $category=$xml_item->{item}{$id}{category};
      push @{$catdb{$category}},$id;

      #pick up all the lists this item belongs to
      my $aref=$xml_item->{item}{$id}{lists};
      for my $lid(@{$$aref{list}}){
         #make a note of this list id, skip the special "all" list
         $listids{$lid}=1 if ($lid ne "all");
      }
   }
   print Dumper(\%listids);
   #print Dumper(\%catdb);
   #print Dumper(\%listdb);

   #loop through all items to pack
   for my $id(keys %$ref){

      #pick up the category for this item, collect in db
      my $category=$xml_item->{item}{$id}{category};
      push @{$catdb{$category}},$id;

      #pick up all the lists this item belongs to
      my $aref=$xml_item->{item}{$id}{lists};
      for my $lid(@{$$aref{list}}){
         if($lid eq "all"){
            #belongs to all lists, so add it to all list ids
            for my $lid(keys %listids){
               push @{$listdb{$lid}{$category}},$id;
            }
         }
         else{
            #add the item to this list id
            push @{$listdb{$lid}{$category}},$id;
         }
      }
   }
   #print Dumper(\%catdb);
   #print Dumper(\%listdb);

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
