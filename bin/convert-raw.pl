use strict;
use Data::Dumper;
my %db;
my $f="src/pcklst-data.txt";
open IN,"<",$f or die "cannot open $f, stopping";
while(<IN>){
   my ($list,$category,$item)=split/,/;
   chop $item;
   next if(!$item);
   push @{$db{$item}{list}},$list;
   $db{$item}{category}=$category;
}
close IN;
#print Dumper(\%db);
print "<items>\n";
my $cnt=0;
for my $item(sort keys %db){
   my $id=sprintf("item%04d",$cnt++);
   print qq(\n   <item id="$id">\n);
   print qq(      <title>$item</title>\n);
   print qq(      <category>$db{$item}{category}</category>\n);
   print qq(      <lists>\n);
   for my $lid(@{$db{$item}{list}}){
   print qq(         <list>$lid</list>\n);
   }
   print qq(      </lists>\n);
   print qq(   </item>\n);
}
print "</items>\n";
