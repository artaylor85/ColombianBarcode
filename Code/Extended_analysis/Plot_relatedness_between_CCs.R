#############################################################################
#' Script to plot matrices and graphs of relatedness between "extended"
#' CCs/samples and "original" CCs (CCs of Taylor et al.).
#'
#' For publication grade heatmaps: change legend cex and mark NAs.
#'
#' For publication grade graphs: rename ccs so ccs based on FSVC only are not
#' confused with ccs based on all (as in Compare_components.R). Add
#' inter-relatedess & collection date of first sample per CC (as annotation).
#############################################################################
rm(list = ls())
library(RColorBrewer) # For colours
library(igraph)
eps <- 0.01 # threshold below which LCI is considered zero in Taylor et al. 2019
PDF <- T

# Load metadata
load(sprintf('../../RData/metadata_extended.RData'))
load(file = "../../RData/relatedness_to_CCs.RData")

load("../../RData/Clonal_components_extended_all_LCIthrehold_0.75.RData")
CC_all <- Clonal_components
load("../../RData/Clonal_components_extended_FSVC_LCIthrehold_0.75.RData")
CC_extended <- Clonal_components
load("../../RData/Clonal_components.RData")
CC_original <- Clonal_components

# CC counts and sizes
cc_original_no <- length(Clonal_components)

# Extract city data
cities <- unique(metadata$City)
cols_cities <-c(rev(brewer.pal(5, 'Spectral')),
                brewer.pal(length(cities)-5, 'Dark2'))
names(cols_cities) <- as.character(cities)


# Average relatedness between clusters and CCs
CCs_av_rhat <- sapply(cc_extended_to_cc_original, function(x) x["av_rhat", ])

# Re-order extended clonal components by relatedness 
# (otherwise ordered by date first detected)
CC_extended_names_ordered <- names(sort(colSums(CCs_av_rhat)))
cc_extended_to_cc_original <- cc_extended_to_cc_original[CC_extended_names_ordered]
CCs_av_rhat <- CCs_av_rhat[,names(sort(colSums(CCs_av_rhat)))]

# Order sids by cc followed by samples that were removed from clusters
FSVC_sid <- names(sid_extended_to_cc_original)
FSVC_sid_ordered <- c(unlist(CC_extended[CC_extended_names_ordered]), 
                      FSVC_sid[!FSVC_sid %in% unlist(CC_extended)])
names(FSVC_sid_ordered) <- FSVC_sid_ordered
sid_extended_to_cc_original <- sid_extended_to_cc_original[FSVC_sid_ordered]

if (PDF) pdf("../../Plots/Relatedness_to_CCs.pdf")

#================================================
# Heatplots between CCs
#================================================
for(x in c("av_rhat", "av_r2.5", "av_r97.5", "mn_r2.5", "mx_r97.5")){
  to_plot <- sapply(cc_extended_to_cc_original, function(y) y[x, ])
  fields::image.plot(to_plot, xaxt = "n", yaxt = "n", main = x,
                     breaks = sort(c(eps, seq(0,1,length.out = 9), 1-eps)),  
                     col = c("black",grey.colors(9)), border = "white", 
                     lab.breaks = sort(c(eps, seq(0,1,length.out = 9), 1-eps)))
  axis(side = 1, at = seq(0,1,length.out = nrow(to_plot)), 
       labels = rownames(to_plot), cex.axis = 0.5, las = 2)
  axis(side = 2, at = seq(0,1,length.out = ncol(to_plot)), 
       labels = colnames(to_plot), cex.axis = 0.5, las = 1)
}

#================================================
# Heatplots between sids and CCs
# Order clonal components and then
# FSVC_sids by clonal components and then add
# the samples that were removed due to high 
# connectedness but low data
#================================================
for(x in c("av_rhat", "av_r2.5", "av_r97.5", "mn_r2.5", "mx_r97.5")){
  to_plot <- sapply(sid_extended_to_cc_original, function(y) y[x, ])
  fields::image.plot(to_plot, xaxt = "n", yaxt = "n", main = x,
                     breaks = sort(c(eps, seq(0,1,length.out = 9), 1-eps)),  
                     col = c("black",grey.colors(9)), 
                     lab.breaks = sort(c(eps, seq(0,1,length.out = 9), 1-eps)))
  axis(side = 1, at = seq(0,1,length.out = nrow(to_plot)), 
       labels = rownames(to_plot), cex.axis = 0.5, las = 2)
  axis(side = 2, at = seq(0,1,length.out = ncol(to_plot)), 
       labels = colnames(to_plot), cex.axis = 0.1, las = 1)
}



#============================================
# Graphs
#' CCs original (left), plotted in order of first (bottom) to last (top)
#' detected. CCs extended (right), plotted in order of average relatedness to
#' CCs original from least related (bottom) to most related (top). sids extended
#' (right), plotted in order of relatedness-ordered CCs extended, with
#' additional samples added above. Note that the additional samples do not
#' include samples with one or more NA edges to CCs since, unlike
#' graph_from_adjacency_matrix, graph_from_incidence_matrix returns an error if
#' the incidence matrix contains NAs.
#============================================

for(relatedness_between in c("clusters", "sids")){
  
  if (relatedness_between == "clusters") {
    
    # Concatenate all components/clusters
    CC_original_extended <- c(CC_original, CC_extended)
    CC_sizes <- sapply(CC_original_extended, length)
    
  } else {
    
    CCs_av_rhat <- sapply(sid_extended_to_cc_original, function(x) x["av_rhat", ])
    to_keep_ind <- colSums(is.na(CCs_av_rhat)) == 0
    CCs_av_rhat <- CCs_av_rhat[, to_keep_ind]
    
    CCs_av_rhat <- sapply(sid_extended_to_cc_original, function(x) x["av_rhat", ])
    to_keep_ind <- colSums(is.na(CCs_av_rhat)) == 0
    CCs_av_rhat <- CCs_av_rhat[, to_keep_ind]
    
    # Concatenate all components/clusters
    sid_list <- as.list(colnames(CCs_av_rhat))
    names(sid_list) <- colnames(CCs_av_rhat)
    CC_original_extended <- c(CC_original, sid_list)
    CC_sizes <- sapply(CC_original_extended, length)
  }
  
  sample_count_per_city_per_CC <- lapply(CC_original_extended, function(cc){
    # Initialise empty vector of city counts
    city_count_per_CC_inc_zeros = array(0, dim = length(cities), dimnames = list(cities))
    # Extract number of samples per CC per city
    city_count_per_CC_exc_zeros <-  table(metadata[cc,"City"])
    # Populate initial empty vector of city counts
    city_count_per_CC_inc_zeros[names(city_count_per_CC_exc_zeros)] <- city_count_per_CC_exc_zeros
    return(city_count_per_CC_inc_zeros)
  })
  
  BiG <- graph_from_incidence_matrix(CCs_av_rhat, weighted = TRUE)
  vertex_sizes =  CC_sizes[attr(V(BiG), "names")]
  
  # Space vertices according to size
  vertex_spacing_original <- rep(1,cc_original_no)
  for(i in 2:cc_original_no){
    vertex_spacing_original[i] <- vertex_spacing_original[i-1] + 
      (vertex_sizes[rownames(CCs_av_rhat)][i-1])/2  + (vertex_sizes[rownames(CCs_av_rhat)][i])/2 
  }
  
  vertex_spacing_extended <- rep(1,ncol(CCs_av_rhat))
  for(i in 2:ncol(CCs_av_rhat)){
    vertex_spacing_extended[i] <- vertex_spacing_extended[i-1] + 
      (vertex_sizes[colnames(CCs_av_rhat)][i-1])/2  + (vertex_sizes[colnames(CCs_av_rhat)][i])/2 
  }
  
  # Name
  names(vertex_spacing_original) <- rownames(CCs_av_rhat)
  names(vertex_spacing_extended) <- colnames(CCs_av_rhat)
  
  # Transform to -1,1 igraph range; see locator(2)
  # ( (old_value - old_min) / (old_max - old_min) ) * (new_max - new_min) + new_min
  vertex_spacing_original <- ((vertex_spacing_original-min(vertex_spacing_original))/diff(range(vertex_spacing_original)))*2-1
  vertex_spacing_extended <- ((vertex_spacing_extended-min(vertex_spacing_extended))/diff(range(vertex_spacing_extended)))*2-1
  
  # By default the rows are drawn first in a bipartite graph
  vertex_spacing <- c(vertex_spacing_original, vertex_spacing_extended)
  range(vertex_spacing) 
  
  my_bi_partite_layout <- cbind(rep(0:1, c(nrow(CCs_av_rhat), 
                                           ncol(CCs_av_rhat))),
                                vertex_spacing[V(BiG)$name])
  
  writeLines(sprintf("Average relatedness estimates range from %s and to %s", 
                     round(min(edge_attr(BiG, "weight")), 3),
                     round(max(edge_attr(BiG, "weight")), 3)))
  
  # Plot
  par(mar = c(1,1,1,1))
  plot(BiG,
       layout = my_bi_partite_layout, 
       vertex.shape = "pie", 
       vertex.pie = sample_count_per_city_per_CC[V(BiG)$name], 
       vertex.pie.color = list(cols_cities[cities]), 
       vertex.pie.lwd = 0.25, 
       vertex.frame.color = NA, #NB, colours pi outline 
       vertex.size = vertex_sizes, 
       # vertex.pie.lty = "dashed", 
       # vertex.pie.border = list("hotpink"), # Doesn't work: always black
       # vertex.label.cex = 0.35, 
       # vertex.label.color = 'black', 
       vertex.label = NA,
       edge.width = edge_attr(BiG, "weight"),
       edge.color = sapply(edge_attr(BiG, "weight"), 
                           function(x)adjustcolor('black', alpha.f = x)))
  
  # # Add CC outline
  # plot(BiG, add = T,
  #      layout = my_bi_partite_layout,
  #      vertex.size = vertex_sizes,
  #      vertex.frame.color = "white", #NB, coulours pi outline
  #      vertex.frame.lwd = 0.5,
  #      vertex.color = NA,
  #      vertex.label = NA,
  #      edge.color = NA)
  
  axis(side = 2, at = vertex_spacing_original, 
       labels = names(vertex_spacing_original), line = -2, 
       las = 1, cex.axis = 0.25, tick = F)
  
  axis(side = 4, at = vertex_spacing_extended, 
       labels = names(vertex_spacing_extended),  
       las = 1, tick = F, cex.axis = 0.1,
       line = ifelse(relatedness_between == "sids", -4, -2))
  
  if(relatedness_between == "sids") {
    inds <- cumsum(sapply(CC_extended, length)[CC_extended_names_ordered])
    axis(side = 4, at =  vertex_spacing_extended[inds], 
         labels = CC_extended_names_ordered, line = -2, 
         las = 1, tick = T, cex.axis = 0.1, tcl = -0.25)
  }
  
  # Legend
  city_counts <- sapply(sample_count_per_city_per_CC[V(BiG)$name], function(x){x})
  cities_ <- names(which(rowSums(city_counts) > 0))
  legend('bottom', pch = 16, bty = 'n', cex = 0.5, pt.cex = 1, 
         col = cols_cities[cities_], legend = cities_)
  
}


# Relatedness between cc_all 
for(singletons in c("inc", "exc")){
  
  if(singletons == "inc"){
    CCs_av_rhat <- sapply(within_cc_extended_inc_singletons, function(x) x["av_rhat", ])
  } else {
    CCs_av_rhat <- sapply(within_cc_extended_exc_singletons, function(x) x["av_rhat", ])  
  }
  colnames(CCs_av_rhat) <- rownames(CCs_av_rhat)
  
  # Sample counts per city for pie charts
  sample_count_per_city_per_CC <- lapply(CC_all, function(cc){
    # Initialise empty vector of city counts
    city_count_per_CC_inc_zeros = array(0, dim = length(cities), dimnames = list(cities))
    # Extract number of samples per CC per city
    city_count_per_CC_exc_zeros <-  table(metadata[cc,"City"])
    # Populate initial empty vector of city counts
    city_count_per_CC_inc_zeros[names(city_count_per_CC_exc_zeros)] <- city_count_per_CC_exc_zeros
    return(city_count_per_CC_inc_zeros)
  })
  
  Graph <- graph_from_adjacency_matrix(CCs_av_rhat, weighted = TRUE, diag = FALSE, mode = "undirected")
  writeLines(sprintf("Average relatedness estimates range from %s and to %s", 
                     round(min(edge_attr(Graph, "weight")), 3),
                     round(max(edge_attr(Graph, "weight")), 3)))
  
  
  layout_fr <- layout_with_fr(Graph)
  
  # Plot
  par(mar = c(1,1,1,1))
  plot(Graph,
       layout = layout_fr, 
       vertex.shape = "pie", 
       vertex.pie = sample_count_per_city_per_CC[V(Graph)$name], 
       vertex.pie.color = list(cols_cities[cities]), 
       vertex.pie.lwd = 0.25, 
       vertex.frame.color = NA, # colours segment outline as well as circumference
       vertex.size = sapply(CC_all, length)[attr(V(Graph), "names")], 
       vertex.label = NA,
       edge.width = edge_attr(Graph, "weight"),
       edge.color = sapply(edge_attr(Graph, "weight"), function(x)adjustcolor('black', alpha.f = x)))
  
  # Legend
  city_counts <- sapply(sample_count_per_city_per_CC[V(Graph)$name], function(x){x})
  cities_ <- names(which(rowSums(city_counts) > 0))
  legend('bottom', pch = 16, bty = 'n', cex = 0.5, pt.cex = 1, ncol = 2, 
         col = cols_cities[cities_], legend = cities_)
  
  # Plot
  par(mar = c(1,1,1,1))
  plot(Graph,
       layout = layout_fr, 
       vertex.shape = "pie", 
       vertex.pie = sample_count_per_city_per_CC[V(Graph)$name], 
       vertex.pie.color = list(cols_cities[cities]), 
       vertex.pie.lwd = 0.25, 
       vertex.label.size = 0.5,
       vertex.frame.color = NA, # colours segment outline as well as circumference
       vertex.size = sapply(CC_all, length)[attr(V(Graph), "names")],
       edge.width = edge_attr(Graph, "weight"),
       edge.color = sapply(edge_attr(Graph, "weight"), function(x)adjustcolor('black', alpha.f = x)))
  
  # Legend
  city_counts <- sapply(sample_count_per_city_per_CC[V(Graph)$name], function(x){x})
  cities_ <- names(which(rowSums(city_counts) > 0))
  legend('bottom', pch = 16, bty = 'n', cex = 0.5, pt.cex = 1, ncol = 2, 
         col = cols_cities[cities_], legend = cities_)
  
  
}




if (PDF) dev.off()