args <- commandArgs(trailingOnly = TRUE)
rna_file <- args[1]
adt_file <- args[2]
cytof_file <- args[3]
annotation_to_project <- args[4]
cca.dims <- as.integer(args[5])
outfile <- args[6]

# load necessary libraries
suppressPackageStartupMessages({
	library(SingleCellExperiment)
	library(Seurat)
	library(dplyr)
	library(tidyr)
})

# load initial objects
rna <- readRDS(rna_file)
cytof <- readRDS(cytof_file)
adt <- readRDS(adt_file)

# set B cell markers and common features
DefaultAssay(rna) <- "RNA"
common_features <- intersect(row.names(rna), row.names(cytof))
common_features_adt <- intersect(row.names(cytof), row.names(adt))

# filtering cells without expression in common genes
indx <- colSums(rna[common_features,])>5
rna <- rna[,indx]
adt <- adt[,colnames(rna)]

# find anchors
transfer.anchors_cyt <- FindTransferAnchors(reference = cytof, query = rna, 
                                                  features = common_features,
                                                  reference.assay = "Cytof", 
                                                  query.assay = "RNA", 
                                                  reduction = "cca",
                                                  dims=1:cca.dims)

# transfer labels and protein intensities         
imputation_cyt <- TransferData(anchorset = transfer.anchors_cyt, 
                                 refdata = GetAssayData(cytof, assay = "Cytof", slot = "data")[union(common_features, common_features_adt), ],
                                 weight.reduction = rna[["pca"]],
                                 dims=1:cca.dims)
rna[["Cytof"]] <- imputation_cyt

celltype.predictions_cyt <- TransferData(anchorset = transfer.anchors_cyt, 
                                               refdata = cytof@meta.data[,annotation_to_project],
                                               weight.reduction =rna[["pca"]],
                                               dims=1:cca.dims)
rna <- AddMetaData(rna, metadata = celltype.predictions_cyt[,c("predicted.id","prediction.score.max")])

saveRDS(rna, file = outfile)
sessionInfo()
