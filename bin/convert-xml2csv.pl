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
   my $sep=";";
   my $out="src/pcklst-data.csv";
   print "create $out\n";
   open OUT,">",$out or die("cannot create $out, stopping");
   for my $category(sort keys %catdb){
      #for my $id(@{$catdb{$category}}){
         for my $id(sort{
            $xml_item->{item}{$a}{title} cmp
            $xml_item->{item}{$b}{title}
            }@{$catdb{$category}}){
            #}@{$listdb{$lid}{$catid}}){
            my $item=$xml_item->{item}{$id}{title};
         print OUT "$category$sep$item$sep";
         my $aref=$xml_item->{item}{$id}{lists};
         for my $lid(@{$$aref{list}}){
            print OUT "$lid$sep";
         }
         print OUT "\n";
      }
   }
   close OUT;
}

#-----------------------------------------------------------------------
#main code
parse_item();
gen_pcklist();
