% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/spatial_interaction.R
\name{combineCellProximityGenes}
\alias{combineCellProximityGenes}
\title{combineCellProximityGenes}
\usage{
combineCellProximityGenes(...)
}
\arguments{
\item{...}{
  Arguments passed on to \code{\link[=combineInteractionChangedGenes]{combineInteractionChangedGenes}}
  \describe{
    \item{\code{cpgObject}}{ICG (interaction changed gene) score object}
    \item{\code{selected_ints}}{subset of selected cell-cell interactions (optional)}
    \item{\code{selected_genes}}{subset of selected genes (optional)}
    \item{\code{specific_genes_1}}{specific geneset combo (need to position match specific_genes_2)}
    \item{\code{specific_genes_2}}{specific geneset combo (need to position match specific_genes_1)}
    \item{\code{min_cells}}{minimum number of target cell type}
    \item{\code{min_int_cells}}{minimum number of interacting cell type}
    \item{\code{min_fdr}}{minimum adjusted p-value}
    \item{\code{min_spat_diff}}{minimum absolute spatial expression difference}
    \item{\code{min_log2_fc}}{minimum absolute log2 fold-change}
    \item{\code{do_parallel}}{run calculations in parallel with mclapply}
    \item{\code{cores}}{number of cores to use if do_parallel = TRUE}
    \item{\code{verbose}}{verbose}
  }}
}
\description{
Combine ICG scores in a pairwise manner.
}
\seealso{
\code{\link{combineInteractionChangedGenes}}
}
