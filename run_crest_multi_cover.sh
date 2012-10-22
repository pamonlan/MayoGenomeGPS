#!/bin/bash

########################################################
###### 	SV CALLER FOR TUMOR/NORMAL PAIR WHOLE GENOME ANALYSIS PIPELINE

######		Program:			run_crest_multi.sh
######		Date:				09/26/2011
######		Summary:			Calls Crest
######		Input 
######		$1	=	group name
######		$2	=	bam list (first is normal) : separated
######		$3	=	names of the samples : separated
######		$4	=	/path/to/output directory
######		$5	=	/path/to/run_info.txt
########################################################

if [ $# -le 4 ]
then
    echo -e "Script to run crest on a paired sample\nUsage: ./run_crest_multi_cover.sh <sample name> <group name> </path/to/input directory> </path/to/output directory> </path/to/run_info.txt>"
else
    set -x
    echo `date`
    sample=$1
    group=$2
    input=$3
    output_dir=$4
    run_info=$5
	if [ $6 ]
	then
		SGE_TASK_ID=$6
	fi	
	########################################################	
    ######		Reading run_info.txt and assigning to variables
    #SGE_TASK_ID=1
    tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
    sample_info=$( cat $run_info | grep -w '^SAMPLE_INFO' | cut -d '=' -f2)
    script_path=$( cat $tool_info | grep -w '^WORKFLOW_PATH' | cut -d '=' -f2 )
    samtools=$( cat $tool_info | grep -w '^SAMTOOLS' | cut -d '=' -f2 )
    crest=$( cat $tool_info | grep -w '^CREST' | cut -d '=' -f2 )
    perllib=$( cat $tool_info | grep -w '^PERLLIB' | cut -d '=' -f2 )
    chr=$(cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" "\n" | head -n $SGE_TASK_ID | tail -n 1)
    ref_genome=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2 )
	analysis=$( cat $run_info | grep -w '^ANALYSIS' | cut -d '=' -f2 | tr "[A-Z]" "[a-z]" )
	if [ $analysis == "variant" ]
	then
		input_bam=$input/$group.$sample.chr$chr.bam
		previous="split_sample_pair.sh"
	else
		input_bam=$input/$sample.sorted.bam
		previous="processBAM.sh"
	fi	
    export PERL5LIB=$perllib:$crest
    PATH=$PATH:$blat:$crest:$perllib
	mkdir -p $output_dir/$group/log
	$samtools/samtools view -H $input_bam 1>$input_bam.crest.$sample.$chr.header 2>$input_bam.crest.$sample.$chr.fix.log
	if [ `cat $input_bam.crest.$sample.$chr.fix.log | wc -l` -gt 0 ]
	then
		$script_path/email.sh $input_bam "bam is truncated or corrupt" $previous $run_info
		$script_path/wait.sh $input_bam.crest.$sample.$chr.fix.log
	else
		rm $input_bam.crest.$sample.$chr.fix.log
	fi
	rm $input_bam.crest.$sample.$chr.header
	if [ ! -s ${input_bam}.bai ]
	then
		$samtools/samtools index $input_bam 
	fi	
	$samtools/samtools view -b $input_bam chr$chr >  $output_dir/$group/$sample.chr$chr.bam
	$samtools/samtools index $output_dir/$group/$sample.chr$chr.bam
    file=$output_dir/$group/$sample.chr$chr.bam
    SORT_FLAG=`$script_path/checkBAMsorted.pl -i $file -s $samtools`
    if [ $SORT_FLAG == 0 ]
    then
        $script_path/errorlog.sh $file run_crest_multi_cover.sh ERROR "is not sorted"
		exit 1;
    fi
    # check if BAM has an index
    if [ ! -s $file.bai ]
    then
        $samtools/samtools index $file
    fi
	$crest/extractSClip.pl -i $file -r chr$chr --ref_genome $ref_genome -o $output_dir/$group -p $sample
    echo `date`
fi
