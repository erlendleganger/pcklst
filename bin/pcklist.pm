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
   my $infile=qq(src/pcklst-data.xml);
   #my $infile=qq(src/item.xml);
   print "parse $infile\n";
   $xml_item=$xml->XMLin(
      $infile,
      keyattr=>[qw(id)],
      forcearray=>[qw(list)],
   );
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
}

sub write_pcklist(){
   my ($fmt,$ref)=@_;
   my $ext=$fmt; #can be expanded to %db{$fmt}{ext} later...
   for my $lid(sort keys %$ref){
      my $out="gen/pakkeliste-$lid.$ext";
      print "create $out\n";
      open my $fh,'>:encoding(UTF-8)',$out or die("cannot create $out, stopping");
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
   print $fh "# Pakkeliste - $lid\n[TOC]\n";
   #get all categories for this packing list
   for my $catid(sort keys %{$$ref{$lid}}){
      print $fh "## \u$catid\n";
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
