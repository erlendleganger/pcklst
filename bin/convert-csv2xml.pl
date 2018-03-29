use strict;
use Data::Dumper;
use Digest::CRC qw(crc64);

sub cksum{
   my $string=shift;
   #return unpack("%64A*",$string)%65535 . length($string);
   #33107 is a prime number
   return unpack("%64A*",$string) * 33107 . length($string);
}

#------
my %db;
my $f="src/pcklst-data.csv";
open IN,"<",$f or die "cannot open $f, stopping";
while(<IN>){
   chop;
   my ($category,$item,@list)=split/;/;
   next if(!$item);
   if(defined $db{$category}{$item}){
      print "FATAL: duplicate definition: $category, $item\n";
      exit 1;
   }
   push @{$db{$category}{$item}{list}},@list;
   #$db{$item}{category}=$category;
}
close IN;

#------
my $out="src/pcklst-data.xml";
print "create $out\n";
open OUT,'>:encoding(UTF-8)',$out or die("cannot create $out, stopping");
print OUT "<items>\n";
my $cnt=0;
for my $category(sort keys %db){
for my $item(sort keys %{$db{$category}}){
   #my $category=$db{$item}{category};
   #my $id=sprintf("item%04d",$cnt++);
   #my $id=cksum($item);
   #use cat+item, item can be duplicated
   my $id=crc64($category.$item);
   print OUT qq(\n   <item id="$id">\n);
   print OUT qq(      <title>$item</title>\n);
   print OUT qq(      <category>$category</category>\n);
   print OUT qq(      <lists>\n);
   for my $lid(@{$db{$category}{$item}{list}}){
      print OUT qq(         <list>$lid</list>\n) if($lid);
   }
   print OUT qq(      </lists>\n);
   print OUT qq(   </item>\n);
}
}
print OUT "</items>\n";
close OUT;
