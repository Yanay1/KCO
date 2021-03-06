workflow cellranger_count {
	# Sample ID
	String sample_id
	# A comma-separated list of input FASTQs directories (gs urls)
	String input_fastqs_directories
	# CellRanger output directory, gs url
	String output_directory

	# GRCh38, hg19, mm10, GRCh38_and_mm10, GRCh38_premrna, mm10_premrna, GRCh38_premrna_and_mm10_premrna or a URL to a tar.gz file
	String genome


	File acronym_file = "gs://regev-lab/resources/cellranger/index.tsv"
	# File acronym_file = "index.tsv"
	Map[String, String] acronym2gsurl = read_map(acronym_file)
	# If reference is a url
	Boolean is_url = sub(genome, "^.+\\.(tgz|gz)$", "URL") == "URL"

	File genome_file = (if is_url then genome else acronym2gsurl[genome])

	# chemistry of the channel
	String? chemistry = "auto"
	# Perform secondary analysis of the gene-barcode matrix (dimensionality reduction, clustering and visualization). Default: false
	Boolean? secondary = false
	# If force cells, default: false
	Boolean? do_force_cells = false
	# Force pipeline to use this number of cells, bypassing the cell detection algorithm, mutually exclusive with expect_cells. Default: 6,000 cells
	Int? force_cells = 6000
	# Expected number of recovered cells. Default: 3,000 cells. Mutually exclusive with force_cells
	Int? expect_cells = 3000

	# 2.2.0 or 2.1.1
	String? cellranger_version = "2.2.0"

	# Number of cpus per cellranger job
	Int? num_cpu = 64
	# Memory in GB
	Int? memory = 128
	# Disk space in GB
	Int? disk_space = 500
	# Number of preemptible tries 
	Int? preemptible = 2

	call run_cellranger_count {
		input:
			sample_id = sample_id,
			input_fastqs_directories = input_fastqs_directories,
			output_directory = sub(output_directory, "/+$", ""),
			genome_file = genome_file,
			chemistry = chemistry,
			secondary = secondary,
			do_force_cells = do_force_cells,
			force_cells = force_cells,
			expect_cells = expect_cells,
			cellranger_version = cellranger_version,
			num_cpu = num_cpu,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	output {
		String output_count_directory = run_cellranger_count.output_count_directory
		String output_metrics_summary = run_cellranger_count.output_metrics_summary
		String output_web_summary = run_cellranger_count.output_web_summary
		File monitoringLog = run_cellranger_count.monitoringLog
	}
}

task run_cellranger_count {
	String sample_id
	String input_fastqs_directories
	String output_directory
	File genome_file
	String chemistry
	Boolean secondary
	Boolean do_force_cells
	Int force_cells
	Int expect_cells
	String cellranger_version
	Int num_cpu
	Int memory
	Int disk_space
	Int preemptible

	command {
		set -e
		export TMPDIR=/tmp
		monitor_script.sh > monitoring.log &
		mkdir -p genome_dir
		tar xf ${genome_file} -C genome_dir --strip-components 1

		python <<CODE
		import re
		from subprocess import check_call

		fastqs = []
		for i, directory in enumerate('${input_fastqs_directories}'.split(',')):
			directory = re.sub('/+$', '', directory) # remove trailing slashes 
			call_args = ['gsutil', '-q', '-m', 'cp', '-r', directory + '/${sample_id}', '.']
			# call_args = ['cp', '-r', directory + '/${sample_id}', '.']
			print(' '.join(call_args))
			check_call(call_args)
			call_args = ['mv', '${sample_id}', '${sample_id}_' + str(i)]
			print(' '.join(call_args))
			check_call(call_args)
			fastqs.append('${sample_id}_' + str(i))
	
		call_args = ['cellranger', 'count', '--id=results', '--transcriptome=genome_dir', '--fastqs=' + ','.join(fastqs), '--sample=${sample_id}', '--chemistry=${chemistry}', '--jobmode=local']
		call_args.append('--force-cells=${force_cells}' if ('${do_force_cells}' is 'true') else '--expect-cells=${expect_cells}')
		if '${secondary}' is not 'true':
			call_args.append('--nosecondary')
		print(' '.join(call_args))
		check_call(call_args)
		CODE

		gsutil -q -m rsync -d -r results/outs ${output_directory}/${sample_id}
		# cp -r results/outs ${output_directory}/${sample_id}
	}

	output {
		String output_count_directory = "${output_directory}/${sample_id}"
		String output_metrics_summary = "${output_directory}/${sample_id}/metrics_summary.csv"
		String output_web_summary = "${output_directory}/${sample_id}/web_summary.html"
		File monitoringLog = "monitoring.log"
	}

	runtime {
		docker: "regevlab/cellranger-${cellranger_version}"
		memory: "${memory} GB"
		bootDiskSizeGb: 12
		disks: "local-disk ${disk_space} HDD"
		cpu: "${num_cpu}"
		preemptible: "${preemptible}"
	}
}
