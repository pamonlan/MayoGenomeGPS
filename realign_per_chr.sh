#!/bin/bash
## this scripts work per chr and accepts an array job parameter to extract the chr information
## this scripts checks for sorted and rad group information for a abam and do as per found
## GATK version using GenomeAnalysisTK-1.2-4-gd9ea764
## here we consider if chopped is 1 means all the sample BAM are chopped and same with 0 
 
if [ $# -le 8 ]
then
    echo -e "script to realign the BAM file using parameters from tool info file\
		\nUsage:\nIf user wants to do realignment fist \n<input dir ':' sep><input bam ':' sep><outputdir>\
		<tool_info><memory_info><1 or 0 if bam is per chr><1 for realign first><sample ':' sep>\
		\nelse\n<input dir><input bam><output dir><tool_info><memory_info> <1 or 0 if bam is per chr> \
		< 0 for realign second><sample(add a dummy sample name as we dont care about the sample name (example:multi))>  ";
	exit 1;
fi
    set -x
    echo `date`
    input=$1    
    bam=$2
    output=$3
    tool_info=$4
    memory_info=$5
    chopped=$6
    realign=$7
    samples=$8
    tool=$9
    if [ $SGE_TASK_ID ]
    then
    	chr=$SGE_TASK_ID
    else
    	chr=$10
    fi
    
    ### creating the local variables
    samtools=$( cat $tool_info | grep -w '^SAMTOOLS' | cut -d '=' -f2)	
    ref=$( cat $tool_info | grep -w '^REF_GENOME' | cut -d '=' -f2)
    gatk=$( cat $tool_info | grep -w '^GATK' | cut -d '=' -f2)
    dbSNP=$( cat $tool_info | grep -w '^dbSNP_REF' | cut -d '=' -f2)
    Kgenome=$( cat $tool_info | grep -w '^KGENOME_REF' | cut -d '=' -f2)
    java=$( cat $tool_info | grep -w '^JAVA' | cut -d '=' -f2)
    script_path=$( cat $tool_info | grep -w '^WORKFLOW_PATH' | cut -d '=' -f2 )
    Indelrealign_param=$( cat $tool_info | grep -w '^IndelRealigner_params' | cut -d '=' -f2 )
	RealignerTargetCreator_params=$( cat $tool_info | grep -w '^RealignerTargetCreator_params' | cut -d '=' -f2 )
    tool=$( cat $run_info | grep -w '^TYPE' | cut -d '=' -f2|tr "[A-Z]" "[a-z]")
    TargetKit=$( cat $tool_info | grep -w '^ONTARGET' | cut -d '=' -f2 )
    
	### to make sure if these files are not available then also user can run the tool
	if [[ ${#dbSNP} -ne 0  && $dbSNP != "NA" ]]
    then
        param="--known $dbSNP" 
	fi	
    
	if [[ ${#Kgenome} -ne 0 && $Kgenome != "NA" ]]
    then
        param=$param" --known $Kgenome" 
    fi
    
    
    if [ $realign == 1 ]
    then
        inputDirs=$( echo $input | tr ":" "\n" )
        bamNames=$( echo $bam | tr ":" "\n" )
        sampleNames=$( echo $samples | tr ":" "\n" )
        i=1
        for inp in $inputDirs
        do
            inputArray[$i]=$inp
            let i=i+1
        done
        i=1
        for ba in $bamNames
        do
            bamArray[$i]=$ba
            let i=i+1
        done
        i=1
        for sa in $sampleNames
        do
            sampleArray[$i]=$sa
            let i=i+1
        done
        if [ ${#inputArray[@]} != ${#bamArray[@]} -o ${#inputArray[@]} != ${#sampleArray[@]} ]
        then
            echo "ERROR : realign_per_chr ':' sep parameters are not matching" 
            exit 1;
        else    
            for i in $(seq 1 ${#sampleArray[@]})
            do
                sample=${sampleArray[$i]}
                input=${inputArray[$i]}
                bam=${bamArray[$i]}
                ##extracting and checking the BAM for specific chromosome
                if [ ! -s $input/$bam ]
                then
					$script_path/errorlog.sh $input/$bam realign_per_chr.sh ERROR "does not exist"
                    exit 1;
                fi
                $script_path/samplecheckBAM.sh $input $bam $output $run_info $sample $chopped $chr
            done
        fi
        input_bam=""
        for i in $(seq 1 ${#sampleArray[@]})
        do
            input_bam="${input_bam} -I $output/${sampleArray[$i]}.chr${chr}-sorted.bam"
        done
    else
        if [ ! -s $input/$bam ]
        then
            $script_path/errorlog.sh $input/$bam realign_per_chr.sh ERROR "does not exist"
            exit 1;
        fi
        $script_path/samplecheckBAM.sh $input $bam $output $run_info $samples $chopped $chr
        input_bam="-I $output/$samples.chr${chr}-sorted.bam"
    fi	
    
	if [ ! -d $output/temp/ ]
	then
		mkdir -p $output/temp/
		sleep 10s
	fi
	
    if [ $tool == "whole_genome" ]
    then
    	region="-L chr${chr}"
    else
    	cat $TargetKit | grep -w chr$chr > $output/chr$chr.bed
		if [ `cat $output/chr$chr.bed | wc -l` -gt 0 ]
		then
			region="-L $output/chr$chr.bed"
		else
			region="-L chr${chr}"
		fi	
	fi		
	## GATK Target Creator
    gatk_params="-R $ref -et NO_ET -K $gatk/Hossain.Asif_mayo.edu.key "
	mem=$( cat $memory_info | grep -w '^RealignerTargetCreator_JVM' | cut -d '=' -f2)
	$java/java $mem -Djava.io.tmpdir=$output/temp/  \
	-jar $gatk/GenomeAnalysisTK.jar \
    -T RealignerTargetCreator \
    -o $output/chr${chr}.forRealigner.intervals $input_bam $param $region $RealignerTargetCreator_params $gatk_params
    
    if [ ! -s $output/chr${chr}.forRealigner.intervals ]
    then
        echo "WARNING : realign_per_chr. File $output/chr${chr}.forRealigner.intervals not created"
        bams=`echo $input_bam | sed -e '/-I/s///g'`
        num_bams=`echo $bams | tr " " "\n" | wc -l`
        if [ $num_bams -eq 1 ]
        then
            cp $bams $output/chr${chr}.realigned.bam
            cp $bams.bai $output/chr${chr}.realigned.bam.bai
        else
            $script_path/sortbam.sh "$bams" $output/chr${chr}.realigned.bam $output coordinate true $tool_info $memory_info yes yes
		fi
    else
        ## Realignment
        mem=$( cat $memory_info | grep -w '^IndelRealigner_JVM' | cut -d '=' -f2)

		$java/java $mem -Djava.io.tmpdir=$output/temp/ \
		-jar $gatk/GenomeAnalysisTK.jar \
        -T IndelRealigner \
    	-L chr${chr} \
    	--out $output/chr${chr}.realigned.bam  \
        -targetIntervals $output/chr${chr}.forRealigner.intervals $Indelrealign_param $param $gatk_params $input_bam
        mv $output/chr${chr}.realigned.bai $output/chr${chr}.realigned.bam.bai
    fi
	
    if [ -s $output/chr${chr}.realigned.bam ]
    then
        if [ $realign == 0 ]
		then
            cp $output/chr${chr}.realigned.bam	$output/chr${chr}.cleaned.bam
            cp $output/chr${chr}.realigned.bam.bai $output/chr${chr}.cleaned.bam.bai
            $script_path/flagstat.sh $output/chr${chr}.cleaned.bam $output/chr${chr}.flagstat $tool_info samtools
		fi	
    else
        $script_path/errorlog.sh $output/chr${chr}.realigned.bam realign_per_chr.sh ERROR "does not exist"
        exit 1;
    fi

    ## deleting the intermediate files
    if [ $realign == 1 ]
    then
        for i in $(seq 1 ${#sampleArray[@]})
        do
            rm $output/${bamArray[$i]}.$chr.bam
            rm $output/${bamArray[$i]}.$chr.bam.bai
            rm $output/${sampleArray[$i]}.chr${chr}.bam
            rm $output/${sampleArray[$i]}.chr${chr}.bam.bai
            rm $output/${sampleArray[$i]}.chr${chr}-sorted.bam
            rm $output/${sampleArray[$i]}.chr${chr}-sorted.bam.bai
        done
    else
        rm $output/$bam.$chr.bam
        rm $output/$bam.$chr.bam.bai
        rm $output/$samples.chr${chr}.bam
        rm $output/$samples.chr${chr}.bam.bai
        rm $output/$samples.chr${chr}-sorted.bam
        rm $output/$samples.chr${chr}-sorted.bam.bai
    fi		
    rm $output/chr${chr}.forRealigner.intervals
	if [ -f $output/chr$chr.bed	]
	then
		rm $output/chr$chr.bed	
    fi
    echo  `date`	
