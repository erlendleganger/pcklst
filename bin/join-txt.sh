#-----------------------------------------------------------------------
#join several passed files into one two-column file

#-----------------------------------------------------------------------
#-----------------------------------------------------------------------
usage(){
   cat<<EOT
usage:
   $LIB_ME -l "f1.txt f2.txt f3.txt ..."

where:
   -f f1 f2 are the files to combine into one two-column file
   -h : show this help text

EOT
}

#-----------------------------------------------------------------------
#get parameters
while getopts "l:" param; do
   case $param in
      l) filelist="$OPTARG";; #list of files
      h) usage; exit 0;;
   esac
done

#-----------------------------------------------------------------------
if test -z "$filelist"; then
   echo "FATAL: mandatory parameter -l "f1 f2 f3" missing"
   usage; exit 1
fi

#-----------------------------------------------------------------------
#temporary files
concat=$(mktemp)
half="half."

#-----------------------------------------------------------------------
#check if files are present
for f in $filelist; do
   if test -f $f; then
      cat $f>>$concat
      echo>>$concat
   else
      echo "FATAL: cannot find $f";
      rm $concat
      exit 1
   fi
done

#-----------------------------------------------------------------------
#get the size of the concat file, and use csplit to create the halves
size=$(wc -l $concat|awk '{print $1}')
csplit -sf $half $concat $(($size/2+1))

#-----------------------------------------------------------------------
#present the result
paste "${half}00" "${half}01"|column -s $'\t' -t 

#-----------------------------------------------------------------------
#clean up
rm $concat ${half}*
