use strict;
use Data::Dumper;

sub cksum{
   my $string=shift;
   #return unpack("%64A*",$string)%65535 . length($string);
   #33107 is a prime number
   return unpack("%64A*",$string) * 33107 . length($string);
}


my %db;
my $f="src/pcklst-data.csv";
open IN,"<",$f or die "cannot open $f, stopping";
while(<IN>){
   chop;
   my ($category,$item,@list)=split/;/;
   next if(!$item);
   push @{$db{$item}{list}},@list;
   $db{$item}{category}=$category;
}
close IN;
my $out="src/pcklst-data.xml";
print "create $out\n";
open OUT,'>:encoding(UTF-8)',$out or die("cannot create $out, stopping");
print OUT "<items>\n";
my $cnt=0;
for my $item(sort keys %db){
   #my $id=sprintf("item%04d",$cnt++);
   my $id=cksum($item);
   print OUT qq(\n   <item id="$id">\n);
   print OUT qq(      <title>$item</title>\n);
   print OUT qq(      <category>$db{$item}{category}</category>\n);
   print OUT qq(      <lists>\n);
   for my $lid(@{$db{$item}{list}}){
      print OUT qq(         <list>$lid</list>\n) if($lid);
   }
   print OUT qq(      </lists>\n);
   print OUT qq(   </item>\n);
}
print OUT "</items>\n";
close OUT;
