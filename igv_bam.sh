#!/bin/sh
##	INFO
#	to cat all the realigned BAM for IGV visualization

######################################
#		$1		=	input folder (realignment sample folder)
#		$3		=	sample
#		$4		=	output folder
#		$5		=	run info file
#########################################

if [ $# != 5 ];
then
    echo -e "Usage: SCRIPT to create IGV BAM \n</path/to/realign dir> </path/to/output folder> <sample> </path/to/alignment folder><run ifno>";
else	
    set -x
    echo `date`
    input=$1
    output=$2
	sample=$3
	alignment=$4
    run_info=$5
    
	tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
	sample_info=$( cat $run_info | grep -w '^SAMPLE_INFO' | cut -d '=' -f2)
    chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2)
    chrIndexes=$( echo $chrs | tr ":" "\n" )
    samtools=$( cat $tool_info | grep -w '^SAMTOOLS' | cut -d '=' -f2 )
    delivery_folder=$( cat $run_info | grep -w '^DELIVERY_FOLDER' | cut -d '=' -f2)
    multi=$( cat $run_info | grep -w '^MULTISAMPLE' | cut -d '=' -f2| tr "[a-z]" "[A-Z]")

    i=1
    for chr in $chrIndexes
    do
        chrArray[$i]=$chr
        let i=i+1
    done

    if [ $multi == "YES" ]
    then
        cd $input/$sample
        pair=$( cat $sample_info | grep -w "$sample" | cut -d '=' -f2)
        for i in *.cleaned.bam
        do
            $samtools/samtools view -H $i > $output/$sample.header.sam
        done

        for i in $pair
        do
            sam=`echo $pair | tr " " "\n" | grep -v $i | tr "\n" " "`
            gr=""
            for s in $sam
            do
                a="ID:$s|";
                gr="$gr $a"
            done
            gr=`echo $gr |  sed "s/|$//"`
            cat $output/$sample.header.sam |grep -E -v '$gr' > $output/$sample.$i.header.sam
            
            if [ ${#chrArray[@]} -gt 1 ]
            then
                input_bam=""
                for j in $(seq 1 ${#chrArray[@]})
                do
                    chr=${chrArray[$j]}
                    if [ -f $output/$sample.$i.chr$chr.bam ]
					then
						input_bam="$input_bam $output/$sample.$i.chr$chr.bam"
					fi
				done
                $samtools/samtools merge -h $output/$sample.$i.header.sam $output/$i.igv-sorted.bam $input_bam
            else
                mv $output/$i.igv-sorted.re.bam $output/$i.igv-sorted.bam
            fi
            if [ -s $output/$i.igv-sorted.bam ]
            then
                $samtools/samtools index $output/$i.igv-sorted.bam
                rm $output/$sample.$i.header.sam
				rm $alignment/$i/$i.sorted.bam $alignment/$i/$i.sorted.bam.bai
            else
                echo "ERROR: $output/$i.igv-sorted.bam not exist Merging fails for $i to create IGV BAM"
                exit 1;
            fi
        done
		rm $output/$sample.header.sam
    else
        cd $input/$sample/
        for i in *.cleaned.bam
        do
            $samtools/samtools view -H $i > $output/$sample.header.sam
        done
        # only merge if there is more than 1 chr
        ### hard coding to find extension *.cleaned.bam
        if [ ${#chrArray[@]} -gt 1 ]
        then
            input_bam=""
            index=""
            for i in $(seq 1 ${#chrArray[@]})
            do
                if [ -f $input/$sample/chr${chrArray[$i]}.cleaned.bam ]
				then
					input_bam="$input_bam $input/$sample//chr${chrArray[$i]}.cleaned.bam"
					index="$index $input/$sample/chr${chrArray[$i]}.cleaned.bam.bai"
				fi
			done
            $samtools/samtools merge -h $output/$sample.header.sam $output/$sample.igv-sorted.bam $input_bam
        else
            cp  $input/$sample/chr${chrArray[1]}.cleaned.bam $output/$sample.igv-sorted.bam
        fi
        
        if [ -s $output/$sample.igv-sorted.bam ]
        then
            $samtools/samtools index $output/$sample.igv-sorted.bam
            rm $output/$sample.header.sam
			rm $alignment/$sample/$sample.sorted.bam $alignment/$sample/$sample.sorted.bam.bai
        else
            echo "ERROR: Merging fails for $sample to create IGV BAM"
            exit 1;
        fi
    fi     
    out=$delivery_folder/IGV_BAM
    if [ $delivery_folder != "NA" ]
    then
        if [ -d $delivery_folder ]
        then
            if [ ! -d $out ]
            then
                mkdir $out
            fi
            if [ $multi == "YES" ]
            then
                pair=$( cat $sample_info | grep -w "$sample" | cut -d '=' -f2)
                for i in $pair
                do
                    mv $output/$i.igv-sorted.bam $out/
                    ln -s $out/$i.igv-sorted.bam $output/$i.igv-sorted.bam
                    mv $output/$i.igv-sorted.bam.bai $out/
                    ln -s $out/$i.igv-sorted.bam.bai $output/$i.igv-sorted.bam.bai
                done
            else
                mv $output/$sample.igv-sorted.bam $out/
                ln -s $out/$sample.igv-sorted.bam $output/$sample.igv-sorted.bam
                mv $output/$sample.igv-sorted.bam.bai $out/
                ln -s $out/$sample.igv-sorted.bam.bai $output/$sample.igv-sorted.bam.bai
            fi
        else
            echo "ERROR: $delivery_folder doesn't exist"
            exit 1
        fi
    fi    
    echo `date`
fi
