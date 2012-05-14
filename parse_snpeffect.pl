use strict;
use warnings;

my $info = shift @ARGV;
my $type = shift @ARGV;
open FH, "$info" or die " can not open $info : $!\n";
#CHROM   POS     REF     ALT     SNPEFF_AMINO_ACID_CHANGE        SNPEFF_EFFECT   SNPEFF_EXON_ID  
#SNPEFF_FUNCTIONAL_CLASS SNPEFF_GENE_BIOTYPE   SNPEFF_GENE_NAME        SNPEFF_IMPACT   SNPEFF_TRANSCRIPT_ID
#chr1    877831  T       C       W343R   NON_SYNONYMOUS_CODING   NM_152486.ex.10 MISSENSE        mRNA    SAMD11  MODERATE        NM_152486

if ($type eq 'SNV')	{
	print "chromosome\tposition\treference\tChange\tHomozygous\tBio_type\taccession\tExon_ID\tExon_Rank\tfunctionGVS\tFunctionalClass\tFunctionalImpact\taminoAcids\tproteinPosition\tCodon_Degeneracy\tgeneList\n";
}
else	{
	print "chromosome\tposition\treference\tChange\tHomozygous\tBio_type\taccession\tExon_ID\tExon_Rank\tfunctionGVS\tFunctionalClass\tFunctionalImpact\tCodon_Degeneracy\tgeneList\n";
}
while(my $l = <FH>)	{
	chomp $l;
	next if ($. == 1);
	my @a=split(/\t/,$l);
	my ($aachange,$aapos);
	if ($type eq 'SNV')	{
		my $aa=$a[4];	
		if ($aa ne '?')	{
			$aa =~ m/(\w)(\d+)(\w*)/;
			if (length($3) eq 1 )	{
				$aachange=$1 ."/" . $3;
			}
			else	{
				$aachange=$1 ."/" . $1;
			}
			$aapos=$2;
		}
		else	{
			$aachange='-';
			$aapos='-';
		}
	}
	for (my $i=0 ; $i <=$#a ; $i++)	{
		if ($i != 4)	{
			if ($a[$i] eq '?')	{
				$a[$i] = '-';
			}
		}	
	}		
	if ($type eq 'SNV')	{
		print "$a[0]\t$a[1]\t$a[2]\t$a[3]\t-\t$a[8]\t$a[11]\t$a[6]\t-\t$a[5]\t$a[7]\t$a[10]\t$aachange\t$aapos\t-\t$a[9]\n";
	}
	else	{
		print "$a[0]\t$a[1]\t$a[2]\t$a[3]\t-\t$a[7]\t$a[10]\t$a[5]\t-\t$a[4]\t$a[6]\t$a[9]\t-\t$a[8]\n";
	}
}
close FH;

	
	