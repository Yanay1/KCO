import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:tasks/versions/4/plain-WDL/descriptor" as tasks
# import "../scCloud/scCloud_tasks.wdl" as tasks

workflow scCloud {
	# Input csv-formatted file containing information of each scRNA-Seq run
	File input_count_matrix_csv
	# Google bucket, subdirectory name and results name prefix
	String output_name
	# Reference genome name, can be None if you want scCloud to infer it from data for you
	String genome = ""

	# Number of cpus per scCloud job
	Int? num_cpu = 64
	# Memory size in GB
	Int? memory = 200
	# Total disk space
	Int? disk_space = 100
	# Number of preemptible tries 
	Int? preemptible = 2


	String out_name = basename(output_name)



	# for aggregate_matrices

	# Select channels that satisfy all restrictions. Each restriction takes the format of name:value,...,value. Multiple restrictions are separated by ';'
	String? restrictions
	# Specify a comma-separated list of outputted attributes. These attributes should be column names in the csv file
	String? attributes
	# If we have demultiplexed data, turning on this option will make scCloud only include barcodes that are predicted as singlets
	Boolean? select_only_singlets = false
	# Only keep barcodes with at least this number of expressed genes
	Int? minimum_number_of_genes = 100
	# If inputs are dropseq data
	Boolean is_dropseq = false

	# If inputs are dropseq data, this option needs to turn on and provides the reference genome name
	String dropseq_genome = if is_dropseq then genome else ""



	# for cluster

	# If input data are CITE-Seq data
	Boolean? cite_seq = false
	# If output cell and gene filtration results [default: true]
	Boolean? output_filtration_results = true
	# If output Seurat compatible h5ad file [default: false]
	Boolean? output_seurat_compatible
	# If output loom-formatted file [default: false]
	Boolean? output_loom
	# If correct batch effects [default: false]
	Boolean? correct_batch_effect
	# Batch correction assumes the differences in gene expression between channels are due to batch effects. However, in many cases, we know that channels can be partitioned into several groups and each group is biologically different from others. In this case, we will only perform batch correction for channels within each group. This option defines the groups. If <expression> is None, we assume all channels are from one group. Otherwise, groups are defined according to <expression>. <expression> takes the form of either ‘attr’, or ‘attr1+attr2+…+attrn’, or ‘attr=value11,…,value1n_1;value21,…,value2n_2;…;valuem1,…,valuemn_m’. In the first form, ‘attr’ should be an existing sample attribute, and groups are defined by ‘attr’. In the second form, ‘attr1’,…,’attrn’ are n existing sample attributes and groups are defined by the Cartesian product of these n attributes. In the last form, there will be m + 1 groups. A cell belongs to group i (i > 0) if and only if its sample attribute ‘attr’ has a value among valuei1,…,valuein_i. A cell belongs to group 0 if it does not belong to any other groups.
	String? batch_group_by
	# Only keep cells with at least <number> of genes. [default: 500]
	Int? min_genes
	# Only keep cells with less than <number> of genes. [default: 6000]
	Int? max_genes
	# Prefix for mitochondrial genes. [default: MT-]
	String? mito_prefix
	# Only keep cells with mitochondrial ratio less than <ratio>. [default: 0.1]
	Float? percent_mito
	# Only use genes that are expressed in at <ratio> * 100 percent of cells to select variable genes. [default: 0.0005]
	Float? gene_percent_cells
	# Total counts per cell after normalization. [default: 1e5]
	Float? counts_per_cell_after
	# Random number generator seed. [default: 0]
	Int? random_state
	# Number of PCs. [default: 50]
	Int? nPC
	# Number of diffusion components. [default: 50]
	Int? nDC
	# Power parameter for diffusion-based pseudotime. [default: 0.5]
	Float? diffmap_alpha
	# Number of neighbors used for constructing affinity matrix. [default: 100]
	Float? diffmap_K
	# Run louvain clustering algorithm.
	Boolean? run_louvain = true
	# Resolution parameter for the louvain clustering algorithm. [default: 1.3]
	Float? louvain_resolution
	# Run KMeans clustering algorithm on diffusion components.
	Boolean? run_kmeans
	# Target at <number> clusters for K means. [default: 20]
	Int? kmeans_n_clusters
	# Run hdbscan clustering algorithm on diffusion components.
	Boolean? run_hdbscan
	# Minimum cluster size for hdbscan. [default: 50]
	Int? hdbscan_min_cluster_size
	# Minimum number of samples for hdbscan. [default: 50]
	Int? hdbscan_min_samples
	# Run approximated louvain clustering algorithm.
	Boolean? run_approximated_louvain
	# Number of Kmeans tries. [default: 20]
	Int? approx_louvain_ninit
	# Number of clusters for Kmeans initialization. [default: 30]
	Int? approx_louvain_nclusters
	# Resolution parameter for louvain. [default: 1.3]
	Float? approx_louvain_resolution
	# Run multi-core tSNE for visualization.
	Boolean? run_tsne = true
	# tSNE’s perplexity parameter. [default: 30]
	Float? tsne_perplexity
	# Run FItSNE for visualization.
	Boolean? run_fitsne
	# Run umap for visualization.
	Boolean? run_umap
	# Run umap on diffusion components.
	Boolean? umap_on_diffmap
	# K neighbors for umap. [default: 15]
	Int? umap_K
	# Umap parameter. [default: 0.1]
	Float? umap_min_dist
	# Umap parameter. [default: 1.0]
	Float? umap_spread
	# Run force-directed layout embedding.
	Boolean? run_fle
	# K neighbors for building graph for FLE. [default: 50]
	Int? fle_K
	# Number of iterations for FLE. [default: 10000]
	Int? fle_n_steps


	# for de_analysis and annotate_cluster

	# If perform de analysis
	Boolean perform_de_analysis = true
	# Specify the cluster labels used for differential expression analysis. [default: louvain_labels]
	String? cluster_labels
	# Control false discovery rate at <alpha>. [default: 0.05]
	Float? alpha
	# Calculate Fisher’s exact test.
	Boolean? fisher = true
	# Calculate Mann-Whitney U test.
	Boolean? mwu
	# Calculate area under curve in ROC curve.
	Boolean? roc

	# If also annotate cell types for clusters based on DE results.
	Boolean? annotate_cluster
	# Organism, could either be "human_immune" or "mouse_immune" or "mouse_brain" [default: human_immune]
	String? organism
	# Minimum cell type score to report a potential cell type. [default: 0.5]
	Float? minimum_report_score


	# for plot

	# Takes the format of "label:attr,label:attr,...,label:attr". If non-empty, generate composition plot for each "label:attr" pair. "label" refers to cluster labels and "attr" refers to sample conditions.
	String? plot_composition
	# Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored tSNEs side by side. 
	String? plot_tsne
	# Takes the format of "attr,attr,...,attr". If non-empty, generate attr colored 3D interactive plot. The 3 coordinates are the first 3 PCs of all diffusion components.
	String? plot_diffmap
	# Plot cells based on t-SNE coordinates estimated from antibody expressions. Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored t-SNEs side by side.
	String? plot_citeseq_tsne


	# for scp_output

	# If generate outputs required by single cell portal
	Boolean generate_scp_outputs = false

	Boolean output_dense = false



	call tasks.run_scCloud_aggregate_matrices as aggregate_matrices {
		input:
			input_count_matrix_csv = input_count_matrix_csv,
			output_name = out_name,
			restrictions = restrictions,
			attributes = attributes,
			select_only_singlets = select_only_singlets,
			minimum_number_of_genes = minimum_number_of_genes,
			dropseq_genome = dropseq_genome,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	call tasks.run_scCloud_cluster as cluster {
		input:
			input_10x_file = aggregate_matrices.output_10x_h5,
			output_name = out_name,
			genome = genome,
			cite_seq = cite_seq,
			output_filtration_results = output_filtration_results,
			output_seurat_compatible = output_seurat_compatible,
			output_loom = output_loom,
			correct_batch_effect = correct_batch_effect,
			batch_group_by = batch_group_by,
			min_genes = min_genes,
			max_genes = max_genes,
			mito_prefix = mito_prefix,
			percent_mito = percent_mito,
			gene_percent_cells = gene_percent_cells,
			counts_per_cell_after = counts_per_cell_after,
			random_state = random_state,
			nPC = nPC,
			nDC = nDC,
			diffmap_alpha = diffmap_alpha,
			diffmap_K = diffmap_K,
			run_louvain = run_louvain,
			louvain_resolution = louvain_resolution,
			run_kmeans = run_kmeans,
			kmeans_n_clusters = kmeans_n_clusters,
			run_hdbscan = run_hdbscan,
			hdbscan_min_cluster_size = hdbscan_min_cluster_size,
			hdbscan_min_samples = hdbscan_min_samples,
			run_approximated_louvain = run_approximated_louvain,
			approx_louvain_ninit = approx_louvain_ninit,
			approx_louvain_nclusters = approx_louvain_nclusters,
			approx_louvain_resolution = approx_louvain_resolution,
			run_tsne = run_tsne,
			tsne_perplexity = tsne_perplexity,
			run_fitsne = run_fitsne,
			run_umap = run_umap,
			umap_on_diffmap = umap_on_diffmap,
			umap_K = umap_K,
			umap_min_dist = umap_min_dist,
			umap_spread = umap_spread,
			run_fle = run_fle,
			fle_K = fle_K,
			fle_n_steps = fle_n_steps,
			num_cpu = num_cpu,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	if (perform_de_analysis) {
		call tasks.run_scCloud_de_analysis as de_analysis {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				labels = cluster_labels,
				alpha = alpha,
				fisher = fisher,
				mwu = mwu,
				roc = roc,
				annotate_cluster = annotate_cluster,
				organism = organism,
				minimum_report_score = minimum_report_score,
				num_cpu = num_cpu,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible
		}
	}

	if (defined(plot_composition) || defined(plot_tsne) || defined(plot_diffmap)) {
		call tasks.run_scCloud_plot as plot {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				plot_composition = plot_composition,
				plot_tsne = plot_tsne,
				plot_diffmap = plot_diffmap,
				plot_citeseq_tsne = plot_citeseq_tsne,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible
		}
	}

	if (generate_scp_outputs) {
		call tasks.run_scCloud_scp_output as scp_output {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				output_dense = output_dense,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible				
		}
	}

	call tasks.organize_results {
		input:
			output_name = output_name,
			output_10x_h5 = aggregate_matrices.output_10x_h5,
			output_h5ad = cluster.output_h5ad,
			output_filt_xlsx = cluster.output_filt_xlsx,
			output_seurat_h5ad = cluster.output_seurat_h5ad,
			output_loom_file = cluster.output_loom_file,
			output_de_h5ad = de_analysis.output_de_h5ad,
			output_de_xlsx = de_analysis.output_de_xlsx,
			output_anno_file = de_analysis.output_anno_file,
			output_pngs = plot.output_pngs,
			output_htmls = plot.output_htmls,
			output_scp_files = scp_output.output_scp_files,
			disk_space = disk_space,
			preemptible = preemptible
	}
}
