#!/bin/sh

if [ $# != 4 ];
then
	echo -e "Usage: script to merge the per chr report \n<output_dir> <TempReports> <run_info> ";
else
	set -x
	echo `date`
	output_dir=$1
	TempReports=$2
	sample=$3
	run_info=$4
	tool_info=$( cat $run_info | grep -w '^TOOL_INFO' | cut -d '=' -f2)
	script_path=$( cat $tool_info | grep -w '^WHOLEGENOME_PATH' | cut -d '=' -f2 )
	chrs=$( cat $run_info | grep -w '^CHRINDEX' | cut -d '=' -f2)
	chrIndexes=$( echo $chrs | tr ":" "\n" )
	variant_type=$( cat $run_info | grep -w '^VARIANT_TYPE' | cut -d '=' -f2| tr "[a-z]" "[A-Z]")
	i=1
	for chr in $chrIndexes
	do
		chrArray[$i]=$chr
		let i=i+1
	done
	
	
	if [ $variant_type == "BOTH" -o $variant_type == "SNV" ]
	then
		cat $TempReports/$sample.chr${chrArray[1]}.SNV.xls > $output_dir/Reports_per_Sample/$sample.SNV.xls
		cat $TempReports/$sample.chr${chrArray[1]}.filtered.SNV.xls > $output_dir/Reports_per_Sample/$sample.SNV.filtered.xls
		if [ ${#chrArray[@]} -gt 1 ]
		then
			for j in $(seq 2 ${#chrArray[@]})
			do
				cat $TempReports/$sample.chr${chrArray[$j]}.SNV.xls | awk 'NR>2' >> $output_dir/Reports_per_Sample/$sample.SNV.xls
				cat $TempReports/$sample.chr${chrArray[$j]}.filtered.SNV.xls | awk 'NR>2' >> $output_dir/Reports_per_Sample/$sample.SNV.filtered.xls
			done
		fi
	fi	
	
	if [ $variant_type == "BOTH" -o $variant_type == "INDEL" ]
	then
		cat $TempReports/$sample.chr${chrArray[1]}.INDEL.xls > $output_dir/Reports_per_Sample/$sample.INDEL.xls
		cat $TempReports/$sample.chr${chrArray[1]}.filtered.INDEL.xls > $output_dir/Reports_per_Sample/$sample.INDEL.filtered.xls

		if [ ${#chrArray[@]} -gt 1 ]
		then
			for j in $(seq 2 ${#chrArray[@]})
			do
				cat $TempReports/$sample.chr${chrArray[$j]}.INDEL.xls | awk 'NR>2' >> $output_dir/Reports_per_Sample/$sample.INDEL.xls
				cat $TempReports/$sample.chr${chrArray[$j]}.filtered.INDEL.xls | awk 'NR>2' >> $output_dir/Reports_per_Sample/$sample.INDEL.filtered.xls
			done
		fi
	fi
	
	### update the dash board
	$script_path/dashboard.sh $sample $run_info Annotation complete
	echo `date`
fi	

