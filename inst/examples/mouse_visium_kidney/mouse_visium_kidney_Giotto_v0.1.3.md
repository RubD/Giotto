
<!-- mouse_cortex_1_simple.md is generated from mouse_cortex_1_simple.Rmd Please edit that file -->

### Giotto global instructions

``` r
# this example works with Giotto v.0.1.3
library(Giotto)

## create instructions
## instructions allow us to automatically save all plots into a chosen results folder
my_python_path = "/Users/rubendries/Bin/anaconda3/envs/py36/bin/pythonw"
results_folder = '/Path/to/Results/visium_kidney_results/'
instrs = createGiottoInstructions(python_path = my_python_path,
                                  show_plot = F, return_plot = T, save_plot = T,
                                  save_dir = results_folder,
                                  plot_format = 'png',
                                  dpi = 300, height = 9, width = 9)
```

### Data input

[10X genomics](https://www.10xgenomics.com/spatial-transcriptomics/)
recently launched a new platform to obtain spatial expression data using
a Visium Spatial Gene Expression slide.

![](./visium_technology.png)

``` r
## expression and cell location
## expression data
data_path = '/path/to/Visium_data/Kidney_data/raw_feature_bc_matrix/'
raw_matrix = get10Xmatrix(path_to_data = data_path)
library("biomaRt") # convert ensembl to gene names
raw_matrix = convertEnsemblToGeneSymbol(matrix = raw_matrix, species = 'mouse')

## spatial results
spatial_results = fread('/path/to/Visium_data/Kidney_data/spatial/tissue_positions_list.csv')
spatial_results = spatial_results[match(colnames(raw_matrix), V1)]
colnames(spatial_results) = c('barcode', 'in_tissue', 'array_row', 'array_col', 'col_pxl', 'row_pxl') # name columns
```

-----

### 1\. Create Giotto object & process data

<details>

<summary>Expand</summary>  

``` r
## create
## we need to reverse the column pixel column (col_pxl) to get the same .jpg image as provided by 10X
visium_kidney <- createGiottoObject(raw_exprs = raw_matrix,
                                    spatial_locs = spatial_results[,.(row_pxl,-col_pxl)],
                                    instructions = instrs,
                                    cell_metadata = spatial_results[,.(in_tissue, array_row, array_col)])

## check metadata
pDataDT(visium_kidney)

## compare 'in tissue' with provided .jpg
## 'in tissue' = 1 means that this spot was covered by the kidney tissue
spatPlot2D(gobject = visium_kidney, cell_color = 'in_tissue', point_size = 2,
           cell_color_code = c('0' = 'lightgrey', '1' = 'blue'),
           save_param = list(save_folder = '2_Gobject', save_name = 'in_tissue'))

## subset on spots that were covered by tissue
metadata = pDataDT(visium_kidney)
in_tissue_barcodes = metadata[in_tissue == 1]$cell_ID
visium_kidney = subsetGiotto(visium_kidney, cell_ids = in_tissue_barcodes)

## filter
visium_kidney <- filterGiotto(gobject = visium_kidney,
                        expression_threshold = 1,
                        gene_det_in_min_cells = 50,
                        min_det_genes_per_cell = 1000,
                        expression_values = c('raw'),
                        verbose = T)

## normalize
visium_kidney <- normalizeGiotto(gobject = visium_kidney, scalefactor = 6000, verbose = T)

## add gene & cell statistics
visium_kidney <- addStatistics(gobject = visium_kidney)

## visualize
## show plain visual locations of each spot
spatPlot2D(gobject = visium_kidney, 
           save_param = list(save_folder = '2_Gobject', save_name = 'spatial_locations'))

## overlay the number of detected genes per spot
spatPlot2D(gobject = visium_kidney, cell_color = 'nr_genes', color_as_factor = F,
           save_param = list(save_folder = '2_Gobject', save_name = 'nr_genes'))
```

High resolution png from original tissue.  
![](./mouse_kidney_highres.png)

Spots labeled according to whether they were covered by tissue or not:  
![](./figures/1_in_tissue.png)

Spots after subsetting and filtering:  
![](./figures/1_spatial_locations.png)

Overlay with number of genes detected per spot:  
![](./figures/1_nr_genes.png)

</details>

### 2\. dimension reduction

<details>

<summary>Expand</summary>  

``` r
## highly variable genes (HVG)
visium_kidney <- calculateHVG(gobject = visium_kidney,
                        save_param = list(save_folder = '3_DimRed', save_name = 'HVGplot'))

## select genes based on HVG and gene statistics, both found in gene metadata
gene_metadata = fDataDT(visium_kidney)
featgenes = gene_metadata[hvg == 'yes' & perc_cells > 4 & mean_expr_det > 0.5]$gene_ID

## run PCA on expression values (default)
visium_kidney <- runPCA(gobject = visium_kidney, genes_to_use = featgenes, scale_unit = F)
signPCA(visium_kidney, genes_to_use = featgenes, scale_unit = F,
        save_param = list(save_folder = '3_DimRed', save_name = 'screeplot'))

plotPCA(gobject = visium_kidney,
        save_param = list(save_folder = '3_DimRed', save_name = 'PCA_reduction'))

## run UMAP and tSNE on PCA space (default)
visium_kidney <- runUMAP(visium_kidney, dimensions_to_use = 1:10)
plotUMAP(gobject = visium_kidney,
         save_param = list(save_folder = '3_DimRed', save_name = 'UMAP_reduction'))

visium_kidney <- runtSNE(visium_kidney, dimensions_to_use = 1:10)
plotTSNE(gobject = visium_kidney,
         save_param = list(save_folder = '3_DimRed', save_name = 'tSNE_reduction'))
```

highly variable genes:  
![](./figures/2_HVGplot.png)

screeplot to determine number of Principal Components to keep:  
![](./figures/2_screeplot.png)

PCA:  
![](./figures/2_PCA_reduction.png)

UMAP:  
![](./figures/2_UMAP_reduction.png)

tSNE:  
![](./figures/2_tSNE_reduction.png) \*\*\*

</details>

### 3\. cluster

<details>

<summary>Expand</summary>  

``` r
## sNN network (default)
visium_kidney <- createNearestNetwork(gobject = visium_kidney, dimensions_to_use = 1:10, k = 15)

## Leiden clustering
visium_kidney <- doLeidenCluster(gobject = visium_kidney, resolution = 0.4, n_iterations = 1000)
plotUMAP(gobject = visium_kidney,
         cell_color = 'leiden_clus', show_NN_network = T, point_size = 2.5,
         save_param = list(save_folder = '4_Cluster', save_name = 'UMAP_leiden'))
```

Leiden clustering:  
![](./figures/3_UMAP_leiden.png)

-----

</details>

### 4\. co-visualize

<details>

<summary>Expand</summary>  

``` r
# expression and spatial
spatDimPlot(gobject = visium_kidney, cell_color = 'leiden_clus',
            dim_point_size = 2, spat_point_size = 2.5,
            save_param = list(save_name = 'covis_leiden', save_folder = '5_Covisuals'))

spatDimPlot(gobject = visium_kidney, cell_color = 'nr_genes', color_as_factor = F,
            dim_point_size = 2, spat_point_size = 2.5,
            save_param = list(save_name = 'nr_genes', save_folder = '5_Covisuals'))
```

Co-visualzation: ![](./figures/4_covis_leiden.png)

Co-visualzation overlaid with number of genes detected:  
![](./figures/4_nr_genes.png)

-----

</details>

### 5\. differential expression

<details>

<summary>Expand</summary>  

``` r
## gini ##
## ---- ##
gini_markers_subclusters = findMarkers_one_vs_all(gobject = visium_kidney,
                                                  method = 'gini',
                                                  expression_values = 'normalized',
                                                  cluster_column = 'leiden_clus',
                                                  min_genes = 20,
                                                  min_expr_gini_score = 0.5,
                                                  min_det_gini_score = 0.5)
topgenes_gini = gini_markers_subclusters[, head(.SD, 2), by = 'cluster']$genes

# violinplot
violinPlot(visium_kidney, genes = unique(topgenes_gini), cluster_column = 'leiden_clus',
           strip_text = 8, strip_position = 'right',
           save_param = c(save_name = 'violinplot_gini', save_folder = '6_DEG', base_width = 5, base_height = 10))

# cluster heatmap
my_cluster_order = c(2, 4, 5, 3, 6, 7, 8, 9, 10, 1)
plotMetaDataHeatmap(visium_kidney, selected_genes = topgenes_gini, custom_cluster_order = my_cluster_order,
                    metadata_cols = c('leiden_clus'), x_text_size = 10, y_text_size = 10,
                    save_param = c(save_name = 'metaheatmap_gini', save_folder = '6_DEG'))

# umap plots
dimGenePlot2D(visium_kidney, expression_values = 'scaled',
                genes = gini_markers_subclusters[, head(.SD, 1), by = 'cluster']$genes,
                cow_n_col = 3, point_size = 1,
                genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
                save_param = c(save_folder = '6_DEG', save_name = 'gini_umap', base_width = 8, base_height = 5))




## scran ##
## ----- ##
scran_markers_subclusters = findMarkers_one_vs_all(gobject = visium_kidney,
                                                   method = 'scran',
                                                   expression_values = 'normalized',
                                                   cluster_column = 'leiden_clus')
topgenes_scran = scran_markers_subclusters[, head(.SD, 2), by = 'cluster']$genes

# violinplot
violinPlot(visium_kidney, genes = unique(topgenes_scran), cluster_column = 'leiden_clus',
           strip_text = 10, strip_position = 'top',
           save_param = c(save_name = 'violinplot_scran', save_folder = '6_DEG', base_width = 5))

# cluster heatmap
plotMetaDataHeatmap(visium_kidney, selected_genes = topgenes_scran, custom_cluster_order = my_cluster_order,
                    metadata_cols = c('leiden_clus'),
                    save_param = c(save_name = 'metaheatmap_scran', save_folder = '6_DEG'))

# umap plots
dimGenePlot2D(visium_kidney, expression_values = 'scaled',
              genes = scran_markers_subclusters[, head(.SD, 1), by = 'cluster']$genes,
              cow_n_col = 3, point_size = 1,
              genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
              save_param = c(save_folder = '6_DEG', save_name = 'scran_umap', base_width = 8, base_height = 5))
```

Gini: - violinplot: ![](./figures/5_violinplot_gini.png)

  - Heatmap clusters: ![](./figures/5_metaheatmap_gini.png)

  - UMAPs: ![](./figures/5_gini_umap.png)

Scran: - violinplot: ![](./figures/5_violinplot_scran.png)

  - Heatmap clusters: ![](./figures/5_metaheatmap_scran.png)

  - UMAPs: ![](./figures/5_scran_umap.png)

-----

</details>

### 6\. cell-type annotation

<details>

<summary>Expand</summary>  

Visium spatial transcriptomics does not provide single-cell resolution,
making cell type annotation a harder problem. Giotto provides 3 ways to
calculate enrichment of specific cell-type signature gene list:  
\- PAGE  
\- rank  
\- hypergeometric test

To generate the cell-type specific gene lists for the kidney data we
used cell-type specific gene sets as identified in [Ransick, A. et
al. Single-Cell Profiling Reveals Sex, Lineage, and Regional Diversity
in the Mouse
Kidney.](https://www.cell.com/developmental-cell/pdfExtended/S1534-5807\(19\)30814-7)

![](./clusters_Ransick_et_al.png)

``` r

# known markers for different kidney cell types
# Ransick, A. et al. Single-Cell Profiling Reveals Sex, Lineage, and Regional Diversity in the Mouse Kidney.
# Developmental Cell 51, 399-413.e7 (2019).

spatDimGenePlot(visium_kidney, expression_values = 'scaled',
                genes = c('Cldn1', 'Lrp2', 'Sptssb', 'Slc12a3'),
                plot_alignment = 'vertical', cow_n_col = 4, point_size = 1,
                genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
                save_param = c(save_folder = '7_annotation', save_name = 'kidney_specific_genes1', base_width = 12, base_height = 5))

spatDimGenePlot(visium_kidney, expression_values = 'scaled',
                genes = c('Aqp2', 'Kdr', 'Thy1', 'Dcn'),
                plot_alignment = 'vertical', cow_n_col = 4, point_size = 1,
                genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
                save_param = c(save_folder = '7_annotation', save_name = 'kidney_specific_genes2', base_width = 12, base_height = 5))



## cell type signatures ##
## for PAGE ##

## example to make signature matrix from list of signature genesets
kidney_sc_markers = as.data.table(readxl::read_excel(sheet = 'Seurat_markers.top50', '/path/to/Visium_data/Kidney_data/scRNAseq_kidney/1-s2.0-S1534580719308147-mmc2.xlsx'))
 
sign_list = list()
for(clus in unique(kidney_sc_markers$cluster)) {
  genes = kidney_sc_markers[cluster == clus]$gene
  sign_list[[clus+1]] = genes
}
sig_matrix = convertSignListToMatrix(sign_names = paste0('clus_', unique(kidney_sc_markers$cluster)),
                                            sign_list = sign_list)

## enrichment tests 
visium_kidney = createSpatialEnrich(visium_kidney, sign_matrix = sig_matrix, enrich_method = 'PAGE') #default = 'PAGE'
visium_kidney = createSpatialEnrich(visium_kidney, sign_matrix = sig_matrix, output_enrichment = 'zscore', name = 'PAGEz') #default = 'PAGE'

## heatmap
value_columns = paste0('clus_', 0:30)
meta_columns = c('leiden_clus')

plotMetaDataCellsHeatmap(gobject = visium_kidney,
                         metadata_cols = 'leiden_clus',
                         value_cols = value_columns,
                         spat_enr_names = 'PAGE',
                         save_param = c(save_folder = '7_annotation', save_name = 'heatmap_PAGE',
                                        base_width = 8, base_height = 6, units = 'cm'))



## multiple value columns with spatPlot ##
value_columns = paste0('clus_', 0:8)
spatCellPlot(gobject = visium_kidney, spat_enr_names = 'PAGE',
             cell_annotation_values = value_columns,
             cow_n_col = 3,coord_fix_ratio = NULL, point_size = 1,
             save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatplot_0_8',
                            base_width = 10, base_height = 6))

value_columns = paste0('clus_', 9:17)
spatCellPlot(gobject = visium_kidney, spat_enr_names = 'PAGE',
             cell_annotation_values = value_columns,
             cow_n_col = 3,coord_fix_ratio = NULL, point_size = 1,
             save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatplot_9_17',
                            base_width = 10, base_height = 6))

value_columns = paste0('clus_', 18:26)
spatCellPlot(gobject = visium_kidney, spat_enr_names = 'PAGE',
             cell_annotation_values = value_columns,
             cow_n_col = 3,coord_fix_ratio = NULL, point_size = 1,
             save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatplot_18_26',
                            base_width = 10, base_height = 6))

value_columns = paste0('clus_', 27:30)
spatCellPlot(gobject = visium_kidney, spat_enr_names = 'PAGE',
             cell_annotation_values = value_columns,
             cow_n_col = 2,coord_fix_ratio = NULL, point_size = 1.5,
             save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatplot_27_30',
                            base_width = 10, base_height = 6))



## multiple value columns with dimPlot2D ##
spatDimCellPlot(gobject = visium_kidney, spat_enr_names = 'PAGE',
                cell_annotation_values = c('clus_4', 'clus_6', 'clus_10', 'clus_20', 'clus_25'),
                cow_n_col = 1, spat_point_size = 1.5, plot_alignment = 'horizontal',
                save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatdimplot',
                               base_width = 6, base_height = 12))



## visualize individual enrichments
spatDimPlot(gobject = visium_kidney,
            spat_enr_names = 'PAGE',
            cell_color = 'clus_25', color_as_factor = F,
            spat_show_legend = T, dim_show_legend = T,
            gradient_midpoint = 3, 
            dim_point_size = 2, spat_point_size = 2,
            save_param = c(save_folder = '7_annotation', save_name = 'PAGE_spatdimplot_clus25',
                                                                    base_width = 7, base_height = 7))
```

Markers for kidney genes: ![](./figures/6_kidney_specific_genes1.png)

![](./figures/6_kidney_specific_genes2.png)

Heatmap:

![](./figures/6_heatmap_PAGE.png)

Spatial enrichment plots for all cell types/clusters:

![](./figures/6_PAGE_spatplot_0_8.png)

![](./figures/6_PAGE_spatplot_9_17.png)

![](./figures/6_PAGE_spatplot_18_26.png)

![](./figures/6_PAGE_spatplot_27_30.png)

Co-visualization for selected subset:

![](./figures/6_PAGE_spatdimplot.png)

-----

</details>

### 7\. spatial grid

<details>

<summary>Expand</summary>  

``` r
visium_kidney <- createSpatialGrid(gobject = visium_kidney,
                             sdimx_stepsize = 400,
                             sdimy_stepsize = 400,
                             minimum_padding = 0)
spatPlot(visium_kidney, cell_color = 'leiden_clus', show_grid = T,
         grid_color = 'red', spatial_grid_name = 'spatial_grid', 
         save_param = c(save_folder = '8_grid', save_name = 'grid'))


### spatial patterns ###
pattern_osm = detectSpatialPatterns(gobject = visium_kidney, 
                                    spatial_grid_name = 'spatial_grid',
                                    min_cells_per_grid = 3, 
                                    scale_unit = T, 
                                    PC_zscore = 1, 
                                    show_plot = T)

# dimension 1
PC_dim = 1
showPattern2D(visium_kidney, pattern_osm, dimension = PC_dim, point_size = 4,
              save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_PCA')))
showPatternGenes(visium_kidney, pattern_osm, dimension = PC_dim,
                 save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_genes')))

# dimension 2
PC_dim = 2
showPattern2D(visium_kidney, pattern_osm, dimension = PC_dim, point_size = 4,
              save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_PCA')))
showPatternGenes(visium_kidney, pattern_osm, dimension = PC_dim,
                 save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_genes')))

# dimension 3
PC_dim = 3
showPattern2D(visium_kidney, pattern_osm, dimension = PC_dim, point_size = 4,
              save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_PCA')))
showPatternGenes(visium_kidney, pattern_osm, dimension = PC_dim,
                 save_param = c(save_folder = '8_grid', save_name = paste0('pattern',PC_dim,'_genes')))

view_pattern_genes = selectPatternGenes(pattern_osm, return_top_selection = TRUE)
```

![](./figures/7_grid.png)

Dimension 1: ![](./figures/7_pattern1_PCA.png)
![](./figures/7_pattern1_genes.png)

Dimension 2: ![](./figures/7_pattern2_PCA.png)

![](./figures/7_pattern2_genes.png)

Dimension 2: ![](./figures/7_pattern3_PCA.png)

![](./figures/7_pattern3_genes.png)

-----

</details>

### 8\. spatial network

<details>

<summary>Expand</summary>  

``` r
visium_kidney <- createSpatialNetwork(gobject = visium_kidney, k = 5, maximum_distance = 400)
spatPlot(gobject = visium_kidney, show_network = T,
         network_color = 'blue', spatial_network_name = 'spatial_network',
         save_param = c(save_name = 'spatial_network_k5', save_folder = '9_spatial_network'))
```

![](./figures/8_spatial_network_k5.png)

-----

</details>

### 9\. spatial genes

<details>

<summary>Expand</summary>  

``` r
## kmeans binarization
kmtest = binGetSpatialGenes(visium_kidney, bin_method = 'kmeans',
                            do_fisher_test = T, community_expectation = 5,
                            spatial_network_name = 'spatial_network', verbose = T)
spatGenePlot(visium_kidney, expression_values = 'scaled',
             genes = kmtest$genes[1:6], cow_n_col = 2, point_size = 1.5,
             genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
             save_param = c(save_name = 'spatial_genes_km', save_folder = '10_spatial_genes'))

## rank binarization
ranktest = binGetSpatialGenes(visium_kidney, bin_method = 'rank',
                              do_fisher_test = T, community_expectation = 5,
                              spatial_network_name = 'spatial_network', verbose = T)
spatGenePlot(visium_kidney, expression_values = 'scaled',
             genes = ranktest$genes[1:6], cow_n_col = 2, point_size = 1.5,
             genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
             save_param = c(save_name = 'spatial_genes_rank', save_folder = '10_spatial_genes'))

## distance
spatial_genes = calculate_spatial_genes_python(gobject = visium_kidney,
                                               expression_values = 'scaled',
                                               rbp_p=0.99, examine_top=0.1)
spatGenePlot(visium_kidney, expression_values = 'scaled',
             genes = spatial_genes$genes[1:6], cow_n_col = 2, point_size = 1.5,
             genes_high_color = 'red', genes_mid_color = 'white', genes_low_color = 'darkblue', midpoint = 0,
             save_param = c(save_name = 'spatial_genes', save_folder = '10_spatial_genes'))
```

Spatial genes: - kmeans ![](./figures/9_spatial_genes_km.png)

  - rank ![](./figures/9_spatial_genes_rank.png)

  - distance  
    ![](./figures/9_spatial_genes.png)

-----

</details>

### 10\. HMRF domains

<details>

<summary>Expand</summary>  

``` r
# spatial genes
my_spatial_genes <- spatial_genes[1:100]$genes

# do HMRF with different betas
hmrf_folder = paste0(results_folder,'/','11_HMRF/')
if(!file.exists(hmrf_folder)) dir.create(hmrf_folder, recursive = T)

HMRF_spatial_genes = doHMRF(gobject = visium_kidney, expression_values = 'scaled',
                            spatial_genes = my_spatial_genes,
                            k = 5,
                            betas = c(0, 1, 6), 
                            output_folder = paste0(hmrf_folder, '/', 'Spatial_genes/SG_topgenes_k5_scaled'))

## view results of HMRF
for(i in seq(0, 5, by = 1)) {
  viewHMRFresults2D(gobject = visium_kidney,
                    HMRFoutput = HMRF_spatial_genes,
                    k = 5, betas_to_view = i,
                    point_size = 2)
}


## alternative way to view HMRF results
#results = writeHMRFresults(gobject = ST_test,
#                           HMRFoutput = HMRF_spatial_genes,
#                           k = 5, betas_to_view = seq(0, 25, by = 5))
#ST_test = addCellMetadata(ST_test, new_metadata = results, by_column = T, column_cell_ID = 'cell_ID')


## add HMRF of interest to giotto object
visium_kidney = addHMRF(gobject = visium_kidney,
                  HMRFoutput = HMRF_spatial_genes,
                  k = 5, betas_to_add = c(0, 5),
                  hmrf_name = 'HMRF')

## visualize
spatPlot(gobject = visium_kidney, cell_color = 'HMRF_k5_b.0', point_size = 5,
         save_param = c(save_name = 'HMRF_k5_b.0', save_folder = '11_HMRF'))

spatPlot(gobject = visium_kidney, cell_color = 'HMRF_k5_b.5', point_size = 5,
         save_param = c(save_name = 'HMRF_k5_b.20', save_folder = '11_HMRF'))
```

HMRF:  
b = 0  
![](./figures/10_HMRF_k5_b.0.png)

b = 5  
![](./figures/10_HMRF_k5_b.20.png)

-----

</details>

### 11\. Cell-cell preferential proximity

<details>

<summary>Expand</summary>  

![cell-cell](./cell_cell_neighbors.png)

``` r
## calculate frequently seen proximities
cell_proximities = cellProximityEnrichment(gobject = visium_kidney,
                                           cluster_column = 'leiden_clus',
                                           spatial_network_name = 'spatial_network',
                                           number_of_simulations = 1000)

## barplot
cellProximityBarplot(gobject = visium_kidney, CPscore = cell_proximities, min_orig_ints = 5, min_sim_ints = 5, 
                     save_param = c(save_name = 'barplot_cell_cell_enrichment', save_folder = '12_cell_proxim'))
## heatmap
cellProximityHeatmap(gobject = visium_kidney, CPscore = cell_proximities, order_cell_types = T, scale = T,
                     color_breaks = c(-1.5, 0, 1.5), color_names = c('blue', 'white', 'red'),
                     save_param = c(save_name = 'heatmap_cell_cell_enrichment', save_folder = '12_cell_proxim', unit = 'in'))
## network
cellProximityNetwork(gobject = visium_kidney, CPscore = cell_proximities, remove_self_edges = T, only_show_enrichment_edges = F,
                     save_param = c(save_name = 'network_cell_cell_enrichment', save_folder = '12_cell_proxim'))

## visualization
spec_interaction = "1--10"
cellProximitySpatPlot2D(gobject = visium_kidney,
                        interaction_name = spec_interaction,
                        cluster_column = 'leiden_clus', show_network = T,
                        cell_color = 'leiden_clus', coord_fix_ratio = 0.5,
                        point_size_select = 2.5, point_size_other = 1.5,
                        save_param = c(save_name = 'selected_enrichment', save_folder = '12_cell_proxim'))
```

barplot:  
![](./figures/11_barplot_cell_cell_enrichment.png)

heatmap:  
![](./figures/11_heatmap_cell_cell_enrichment.png)

network:  
![](./figures/11_network_cell_cell_enrichment.png)

selected enrichment:  
![](./figures/11_selected_enrichment.png)

-----

</details>