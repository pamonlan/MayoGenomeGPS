#!/bin/sh

if [ $# != 3 ]
then	
	echo "Usage: <sample name> <base dir> <path to run_info file> ";
	exit 1
else
	set -x
	echo `date`
	sample=$1
	basedir=$2
	run_info=$3

	chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" "\n" )
	tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2 | tr ":" "\n" )
	output=$( cat $run_info | grep -w '^BASE_OUTPUT_DIR' | cut -d '=' -f2)
	PI=$( cat $run_info | grep -w '^PI' | cut -d '=' -f2)
	java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2)
	gatk=$( cat $tool_info | grep -w '^GATK' | cut -d '=' -f2)
	tool=$( cat $run_info | grep -w '^TYPE' | cut -d '=' -f2 | tr "[A-Z]" "[a-z]" )
	run_num=$( cat $run_info | grep -w '^OUTPUT_FOLDER' | cut -d '=' -f2)
	ref=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2 )
	script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2 )

	mkdir -p $basedir/Reports_per_Sample
	output=$basedir/Reports_per_Sample
	mkdir $output/SV

	#Summaryzing CNVs

	inputargs=""
	inputargs_filter=""
	input=""
	for chr in $chrs
	do
		inputfile=$basedir/cnv/$sample/$sample.$chr.del.vcf
		input=$basedir/cnv/$sample/$sample.$chr.del.bed
		if [ ! -f $inputfile ]
		then
			echo "ERROR :summaryze_struct. CNV: File $inputfile does not exist "
			exit 1
		fi
		inputargs="-V $inputfile "$inputargs  
		cat $input >> $basedir/cnv/$sample/$sample.cnv.bed
		rm $input
		inputfile=$basedir/cnv/$sample/$sample.$chr.dup.vcf 
		input=$basedir/cnv/$sample/$sample.$chr.dup.bed
		if [ ! -f $inputfile ]
		then	
			echo "ERROR :summaryze_struct. CNV: File $inputfile does not exist "
			exit 1
		fi
	
		inputargs="-V $inputfile "$inputargs  
		cat $input >> $basedir/cnv/$sample/$sample.cnv.bed
		rm $input
		inputfile=$basedir/cnv/$sample/$sample.$chr.filter.del.vcf
		input=$basedir/cnv/$sample/$sample.$chr.filter.del.bed
		if [ ! -f $inputfile ]
		then	
			echo "ERROR :summaryze_struct. CNV: File $inputfile does not exist "
			exit 1
		fi
		cat $input >> $basedir/cnv/$sample/$sample.cnv.filter.bed
		rm $input
		inputargs_filter="-V $inputfile "$inputargs_filter  
		inputfile=$basedir/cnv/$sample/$sample.$chr.filter.dup.vcf
		input=$basedir/cnv/$sample/$sample.$chr.filter.dup.bed
		if [ ! -f $inputfile ]
		then
			echo "ERROR :summaryze_struct. CNV: File $inputfile does not exist "
			exit 1
		fi
		cat $input >> $basedir/cnv/$sample/$sample.cnv.filter.bed
		rm $input
		inputargs_filter="-V $inputfile "$inputargs_filter 
	done

	$java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
	-R $ref \
	-et NO_ET \
	-T CombineVariants \
	$inputargs \
	-o $output/SV/$sample.cnv.vcf

	$java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
	-R $ref \
	-et NO_ET \
	-T CombineVariants \
	$inputargs_filter \
	-o $output/SV/$sample.cnv.filter.vcf

	if [ -s $output/SV/$sample.cnv.vcf ]
	then
		file=`echo $inputargs | sed -e '/-V/s///g'`
		rm $file
	fi

	if [ -s $output/SV/$sample.cnv.filter.vcf ]
	then
		file=`echo $inputargs_filter | sed -e '/-V/s///g'`
		rm $file
	fi    

	rm $basedir/cnv/$sample/*.idx
	
    #Summaryzing Breakdancer
	inputargs=""
	input=""
	for chr in $chrs
	do
		inputfile=$basedir/struct/break/$sample/$sample.$chr.break.vcf 
		input=$basedir/struct/break/$sample/$sample.$chr.break
		if [ ! -s $inputfile ]
		then      
			echo "ERROR : summaryze_struct_single.sh SV file for sample $sample, chromosome $i: $inputfile does not exist "
			exit 1
		else
			#inputargs="-V $inputfile "$inputargs
			cat $inputfile | awk '$0 ~/^#/' > $basedir/struct/break/$sample/$sample.header.break
			cat $inputfile | awk '$0 !~ /^#/' >> $output/SV/$sample.break.vcf
			cat $input | awk '$0 !~ /^#/' >> $basedir/struct/break/$sample/$sample.break
			rm $input
			rm $inputfile
		fi
	done
    cat $basedir/struct/break/$sample/$sample.inter.break | awk '$0 !~ /^#/' >> $basedir/struct/break/$sample/$sample.break
    cat $basedir/struct/break/$sample/$sample.inter.break.vcf |  awk '$0 !~ /^#/' >> $output/SV/$sample.break.vcf
	rm 	$basedir/struct/break/$sample/$sample.inter.break.vcf
	rm $basedir/struct/break/$sample/$sample.inter.break 
    cat $basedir/struct/break/$sample/$sample.header.break $output/SV/$sample.break.vcf > $output/SV/$sample.break.vcf.temp
	mv $output/SV/$sample.break.vcf.temp $output/SV/$sample.break.vcf
	rm $basedir/struct/break/$sample/$sample.header.break
	
    # $java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
    # -R $ref \
    # -et NO_ET \
    # -T CombineVariants \
    # $inputargs \
    # -V $basedir/struct/break/$sample/$sample.inter.break.vcf \
    # -o $output/SV/$sample.break.vcf


	if [ ! -s $output/SV/$sample.break.vcf ]
	then
		echo "ERROR : summaryze_struct_single.sh  file $output/$sample.break.vcf not created"
	else
		file=`echo $inputargs | sed -e '/-V/s///g'`
		#rm $file
	fi    
	#Summaryzing Crest

    inputargs=""
    inputargs_filter=""
    input=""
    input_filter=""
    for chr in $chrs
    do
        inputfile=$basedir/struct/crest/$sample/$sample.$chr.raw.vcf
        inputfile_filter=$basedir/struct/crest/$sample/$sample.$chr.filter.vcf
        input=$basedir/struct/crest/$sample/$sample.$chr.predSV.txt
        input_filter=$basedir/struct/crest/$sample/$sample.$chr.filter.predSV.txt
        if [ ! -s $inputfile ]
        then      
            echo "ERROR : summaryze_struct_single.sh SV file for sample $sample, chromosome $i: $inputfile does not exist "
            exit 1
        else
			#inputargs="-V $inputfile "$inputargs
			#inputargs_filter="-V $inputfile_filter "$inputargs_filter
            cat $inputfile | awk '$0 ~/^#/' > $basedir/struct/crest/$sample/vcf.header.$sample.crest
            cat $inputfile | awk '$0 !~ /^#/' >> $output/SV/$sample.raw.crest.vcf
            cat $inputfile_filter | awk '$0 !~ /^#/' >> $output/SV/$sample.filter.crest.vcf
            cat $input >> $basedir/struct/crest/$sample/$sample.raw.crest
            cat $input_filter >> $basedir/struct/crest/$sample/$sample.filter.crest
            rm $input
            rm $input_filter    
            rm $inputfile_filter
            rm $inputfile
        fi
    done
    cat $basedir/struct/crest/$sample/vcf.header.$sample.crest $output/SV/$sample.raw.crest.vcf > $output/SV/$sample.raw.crest.vcf.temp
    mv $output/SV/$sample.raw.crest.vcf.temp $output/SV/$sample.raw.crest.vcf
    
    cat $basedir/struct/crest/$sample/vcf.header.$sample.crest $output/SV/$sample.filter.crest.vcf > $output/SV/$sample.filter.crest.vcf.temp
    mv $output/SV/$sample.filter.crest.vcf.temp $output/SV/$sample.filter.crest.vcf
	rm $basedir/struct/crest/$sample/vcf.header.$sample.crest


#   $java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
#    -R $ref \
#    -et NO_ET \
#    -T CombineVariants \
#    $inputargs \
#    -o $output/SV/$sample.raw.crest.vcf
#
#    $java/java -Xmx2g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
#    -R $ref \
#    -et NO_ET \
#    -T CombineVariants \
#    $inputargs_filter \
#    -o $output/SV/$sample.filter.crest.vcf
#

    if [ ! -s $output/SV/$sample.raw.crest.vcf ]
    then
        echo "ERROR : summaryze_struct_single.sh  file $output/SV/$sample.raw.crest.vcf not created"
    else
        file=`echo $inputargs | sed -e '/-V/s///g'`
#rm $file
        file=`echo $inputargs_filter | sed -e '/-V/s///g'`
#        rm $file
    fi    
	echo `date`
fi    



