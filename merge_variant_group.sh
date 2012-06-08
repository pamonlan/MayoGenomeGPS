#!/bin/sh

########################################################
###### 	Merges variants from vcf files by chromosome

######		Program:			merge_variant_group.sh
######		Date:				12/13/2011
######		Summary:			Using PICARD to sort and mark duplicates in bam 
######		Input files:		$1	=	/path/to/input directory
######					$2	=	group name
######					$3	=	/path/to/run_info.txt
########################################################

if [ $# != 4 ];
then
    echo "Usage: </path/to/input directory> <group name> </path/to/output directory> </path/to/run_info.txt>";
else
    set -x
    echo `date`
    input=$1
    group=$2
    out=$3
    run_info=$4
	
########################################################	
######		Reading run_info.txt and assigning to variables
    tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
    picard=$( cat $tool_info | grep -w '^PICARD' | cut -d '=' -f2 ) 
    java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2)
    chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2 | tr ":" " " )
    ref=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2)
    gatk=$( cat $tool_info | grep -w '^GATK' | cut -d '=' -f2)
    script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2)
    output=$( cat $run_info | grep -w '^BASE_OUTPUT_DIR' | cut -d '=' -f2)
    PI=$( cat $run_info | grep -w '^PI' | cut -d '=' -f2)
    tool=$( cat $run_info | grep -w '^TYPE' | cut -d '=' -f2 | tr "[A-Z]" "[a-z]" )
    run_num=$( cat $run_info | grep -w '^OUTPUT_FOLDER' | cut -d '=' -f2)
    filter_variants=$( cat $tool_info | grep -w '^VARIANT_FILTER' | cut -d '=' -f2 | tr "[a-z]" "[A-Z]")
    blat=$( cat $tool_info | grep -w '^BLAT' | cut -d '=' -f2 )
    blat_port=$( cat $tool_info | grep -w '^BLAT_PORT' | cut -d '=' -f2 )
    blat_ref=$( cat $tool_info | grep -w '^BLAT_REF' | cut -d '=' -f2 )
    blat_server=$( cat $tool_info | grep -w '^BLAT_SERVER' | cut -d '=' -f2 )
    window_blat=$( cat $tool_info | grep -w '^WINDOW_BLAT' | cut -d '=' -f2 )
	javahome=$( cat $tool_info | grep -w '^JAVA_HOME' | cut -d '=' -f2 )
	threads=$( cat $tool_info | grep -w '^THREADS' | cut -d '=' -f2 )
	samtools=$( cat $tool_info | grep -w '^SAMTOOLS' | cut -d '=' -f2 )
	perllib=$( cat $tool_info | grep -w '^PERLLIB' | cut -d '=' -f2)
	export PERL5LIB=$perllib:$PERL5LIB
	export PATH=$PERL5LIB:$PATH
	export JAVA_HOME=$javahome
	export PATH=$JAVA_HOME/bin:$PATH
	
    range=20000
    let blat_port+=$RANDOM%range
    status=`$blat/gfServer status localhost $blat_port | wc -l`;
    if [ "$status" -le 1 ]
    then
		$blat/gfServer start $blat_server $blat_port -log=$out/$group.somatic.variants.raw.vcf.blat.log $blat_ref  &
		sleep 3m
    fi
    status=`$blat/gfServer status $blat_server $blat_port | wc -l`;

    while [ "$status" -le 1 ]
    do
        blat_port=$( cat $tool_info | grep -w '^BLAT_PORT' | cut -d '=' -f2 )
        range=20000
        let blat_port+=$RANDOM%range
        status=`$blat/gfServer status $blat_server $blat_port | wc -l`;
        if [ "$status" -le 1 ]
        then
            rm $out/$group.somatic.variants.raw.vcf.blat.log
            $blat/gfServer start $blat_server $blat_port -log=$out/$group.somatic.variants.raw.vcf.blat.log $blat_ref  &
            sleep 3m
        fi
		 status=`$blat/gfServer status $blat_server $blat_port | wc -l`;
    done
    
        
########################################################	

    inputargs=""
	inputargs_multi=""
    for i in $chrs
    do
        inputfile=$input/$group/MergeAllSamples.chr$i.raw.vcf 
		multi=$input/$group/MergeAllSamples.chr$i.raw.multi.vcf 
        if [ ! -s $inputfile ]
        then		
            $script_path/errorlog.sh $inputfile merge_variant_greoup.sh ERROR "does not exist"
            exit 1
        else
            inputargs=$inputargs"$inputfile "
			inputargs_multi=$inputargs_multi"$multi "
        fi
    done
    
	$script_path/concatvcf.sh "$inputargs" $out/$group.somatic.variants.raw.vcf $run_info no
	$script_path/concatvcf.sh "$inputargs_multi" $out/$group.somatic.variants.raw.multi.vcf $run_info yes
    
	
	if [ $filter_variants == "YES" ]
    then
        $script_path/filter_variant_vqsr.sh $out/$group.somatic.variants.raw.vcf $out/$group.somatic.variants.filter.vcf BOTH $run_info somatic
    else
        cp $out/$group.somatic.variants.raw.vcf $out/$group.somatic.variants.filter.vcf
    fi
    
    ## blat column 
	$script_path/vcf_blat_verify.pl -i $out/$group.somatic.variants.filter.vcf -o $out/$group.somatic.variants.filter.vcf.tmp -w $window_blat -b $blat -r $ref -br $blat_ref -bs $blat_server -bp $blat_port -sam $samtools -th $threads
    mv $out/$group.somatic.variants.filter.vcf.tmp $out/$group.somatic.variants.filter.vcf
	
	$script_path/vcf_blat_verify.pl -i $out/$group.somatic.variants.raw.multi.vcf -o $out/$group.somatic.variants.raw.multi.vcf.tmp -w $window_blat -b $blat -r $ref -br $blat_ref -bs $blat_server -bp $blat_port -sam $samtools -th $threads
    mv $out/$group.somatic.variants.raw.multi.vcf.tmp $out/$group.somatic.variants.raw.multi.vcf
	
	if [ ! -s $out/$group.somatic.variants.filter.vcf ]
    then
		$script_path/errorlog.sh $out/$group.somatic.variants.filter.vcf merge_variant_greoup.sh ERROR "does not exist"
        exit 1;
    else
	for chr in $chrs
	do
	    cat $out/$group.somatic.variants.filter.vcf | awk -v num=chr${chr} '$0 ~ /^#/ || $1 == num' > $input/$group/$group.somatic.variants.chr$chr.filter.vcf 
	done
    fi

	### multi sample calling	
    inputargs=""
	inputargs_multi=""
    for i in $chrs
    do
        inputfile=$input/$group/variants.chr$i.raw.vcf 
		multi=$input/$group/variants.chr$i.raw.vcf.multi.vcf 
        if [ ! -s $inputfile ]
        then		
            $script_path/errorlog.sh $inputfile merge_variant_greoup.sh ERROR "does not exist"
            exit 1
        else
            inputargs=$inputargs"$inputfile "
			inputargs_multi=$inputargs_multi"$multi "
        fi
    done

	$script_path/concatvcf.sh "$inputargs" $out/$group.variants.raw.vcf $run_info no
	$script_path/concatvcf.sh "$inputargs_multi" $out/$group.variants.raw.multi.vcf $run_info yes
	
    if [ $filter_variants == "YES" ]
    then
        $script_path/filter_variant_vqsr.sh $out/$group.variants.raw.vcf $out/$group.variants.filter.vcf BOTH $run_info
    else
        cp $out/$group.variants.raw.vcf $out/$group.variants.filter.vcf
    fi    
	
	## blat column 
	$script_path/vcf_blat_verify.pl -i $out/$group.variants.filter.vcf -o $out/$group.variants.filter.vcf.tmp -w $window_blat -b $blat -r $ref -br $blat_ref -bs $blat_server -bp $blat_port -sam $samtools -th $threads
    mv $out/$group.variants.filter.vcf.tmp $out/$group.variants.filter.vcf
	
	$script_path/vcf_blat_verify.pl -i $out/$group.variants.raw.multi.vcf -o $out/$group.variants.raw.multi.vcf.tmp -w $window_blat -b $blat -r $ref -br $blat_ref -bs $blat_server -bp $blat_port -sam $samtools -th $threads
    mv $out/$group.variants.raw.multi.vcf.tmp $out/$group.variants.raw.multi.vcf
	
	### Filter the variants using total depth 
	### use GATK variant filter to filter using DP
	if [ $tool == "exome" ]
	then
		$java/java -Xmx1g -Xms512m -jar $gatk/GenomeAnalysisTK.jar \
		-R $ref \
		-et NO_ET \
		-K $gatk/Hossain.Asif_mayo.edu.key \
		-l INFO \
		-T VariantFiltration \
		-V $out/$group.variants.filter.vcf \
		-o $out/$group.variants.filter.vcf.tmp \
		--filterExpression "DP < $depth" --filterName DPFilter 
		mv $out/$group.variants.filter.vcf.tmp $out/$group.variants.filter.vcf
		mv $out/$group.variants.filter.vcf.tmp.idx $out/$group.variants.filter.vcf.idx
	fi
	
    if [ ! -s $out/$group.variants.filter.vcf ]
    then
        $script_path/errorlog.sh $out/$group.variants.filter.vcf merge_variant_greoup.sh ERROR "does not exist"
        exit 1
    else
		for chr in $chrs
		do
			cat $out/$group.variants.filter.vcf | awk -v num=chr${chr} '$0 ~ /^#/ || $1 == num' > $input/$group/$group.variants.chr$chr.filter.vcf 
		done
    fi
    rm $out/$group.somatic.variants.raw.vcf.blat.log
	echo `date`
fi