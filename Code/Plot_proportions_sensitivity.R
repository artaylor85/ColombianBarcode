#############################################
# This script plots proportions of 
# highly related parasite sample comparisons
# using various 
# partitions (cities, states, times)
# thresholds for high relatedness (e.g. 0.01, 0.25, 0.5, 0.99)
# filters (unfiltered, filter by vertex, filter by edge)
#############################################
rm(list = ls())
require(RColorBrewer)
load('../RData/proportions_sensitivities.RData')
Thresholds = dimnames(proportions_cities)[[3]]
C_Threshold = Thresholds[4] # Clonal threshold
Thresholds = Thresholds[1:3] # Remove the clonal threshold (plot separately)
Filter_status = dimnames(proportions_cities)[[4]]
PDF = F

# Cities (intra ordered by expectation based on transmission and isolation)
load('../RData/geo_dist_info_cities.RData')
inter_c = geo_dist_info$geo_order  
intra_c = c('Guapi_Guapi', 
            'Tado_Tado', 
            'Tumaco_Tumaco', 
            'Buenaventura_Buenaventura', 
            'Quibdo_Quibdo')
intra_inter_c = c(intra_c, inter_c)

# States (intra ordered by expectation based on transmission and isolation)
load('../RData/geo_dist_info_states.RData')
inter_s = geo_dist_info$geo_order  
intra_s = c('Cauca_Cauca', 'Narino_Narino', 'Valle_Valle', 'Choco_Choco')
intra_inter_s = c(intra_s, inter_s)

# Colours for different thresholds
cols = brewer.pal(length(Thresholds)+1, "GnBu")
names(cols) = c('unrelated',Thresholds)

# Function to add labels and CIs
Add_text_CIs = function(){
  text(x = Midpoints, y = -max(X)/20, srt = 40, xpd = TRUE, # rotate 60 degrees
       adj= 1, labels = gsub('_', ' & ',colnames(X)), cex = 0.5)
  segments(x0 = Midpoints[,1], x1 = Midpoints[,1],
           y0 = X['2.5%',], y1 = X['97.5%',], lty = 1)
}


if(PDF){pdf('../Plots/Proportions_sensitivity.pdf', height = 10, width = 10)}

#=============================================
# Plot results for clonal threshold 
# i.e. pairwise relatedness estimates 
# statistically indistinguishable from clones
# (remove filter by edge since all results are
# zero when all clonal edges are removed)
# Note that non-zero within state proportions when 
# filter by vetex are due to comparisons across Quidbo 
# and Tado
#=============================================
par(mfcol = c(3,2), family = 'serif')
for(fs in c("Unfiltered",  "Filter by vertex")){
  #---------------------------------------
  # Extract clonal proportions cities
  #---------------------------------------
  X = proportions_cities[,intra_inter_c,C_Threshold,fs]
  
  # Barplot
  Midpoints = barplot(X['mean',], names.arg = '', 
                      las = 2, ylim = c(0,max(X)),
                      col = cols[length(Thresholds)+1], 
                      density = rep(c(100,25), c(5, 10)), 
                      main = sprintf('%s', fs), 
                      ylab = bquote('Proportion with UCI of'~hat(italic(r))>.(C_Threshold)))
  Add_text_CIs()
  
  #---------------------------------------
  # Extract clonal proportions states
  #---------------------------------------
  X = proportions_states[,intra_inter_s,C_Threshold, fs]
  
  # Barplot
  Midpoints = barplot(X['mean',], names.arg = '', 
                      las = 2, ylim = c(0,max(X)), 
                      col = cols[length(Thresholds)+1], 
                      density = rep(c(100,25), c(4, 6)), 
                      main = sprintf('%s', fs), 
                      ylab = bquote('Proportion with UCI of'~hat(italic(r))>.(C_Threshold)))
  Add_text_CIs()
  
  #---------------------------------------
  # Extract clonal proportions time
  #---------------------------------------
  X = proportions_times[,,C_Threshold, fs]
  times_sorted = as.character(sort(as.numeric(colnames(X))))
  
  # Barplot
  Midpoints = barplot(X['mean',times_sorted], names.arg = '', 
                      las = 1, ylim = c(0,max(X)), 
                      col = cols[length(Thresholds)+1], 
                      main = sprintf('%s', fs), 
                      ylab = bquote('Proportion with UCI of'~hat(italic(r))>.(C_Threshold)))
  
  segments(x0 = Midpoints[,1], x1 = Midpoints[,1], 
           y0 = X['2.5%', times_sorted], y1 = X['97.5%', times_sorted], lty = 1)
  text(x = Midpoints, y = -max(X)/20, srt = 40, adj= 1, xpd = TRUE, 
       labels = gsub('_', ' & ',colnames(X)), cex = 0.5)
  title(xlab = expression(Delta~'Time (weeks)'), line = 2)
  
}









#=============================================
# Plot results for thresholds on the lower CI
# i.e. pairwise relatedness estimates 
# statistically distinguishable from threshold
#=============================================
par(mfrow = c(3,3), family = 'serif')
for(fs in Filter_status){
  for(threshold in Thresholds){
    
    X = proportions_cities[,intra_inter_c,threshold, fs]
    
    # Barplot
    Midpoints = barplot(X['mean',], names.arg = '', 
                        las = 2, ylim = c(0,max(X)),
                        col = cols[threshold], 
                        density = rep(c(100,25), c(5, 10)), 
                        main = sprintf('%s', fs), 
                        ylab = bquote('Proportion with LCI of'~hat(italic(r))>.(threshold)))
    Add_text_CIs()
  }
}


par(mfrow = c(3,3), family = 'serif')
for(fs in Filter_status){
  for(threshold in Thresholds){
    
    X = proportions_states[,intra_inter_s,threshold, fs]
    
    # Barplot
    Midpoints = barplot(X['mean',], names.arg = '', 
                        las = 2, ylim = c(0,max(X)), 
                        col = cols[threshold], 
                        density = rep(c(100,25), c(4, 6)), 
                        main = sprintf('%s', fs), 
                        ylab = bquote('Proportion with LCI of'~hat(italic(r))>.(threshold)))
    Add_text_CIs()
  }
}


# Times
par(mfrow = c(3,3), family = 'serif')
for(fs in Filter_status){
  for(threshold in Thresholds){
    
    # Extract result
    X = proportions_times[,,threshold, fs]
    times_sorted = as.character(sort(as.numeric(colnames(X))))
    
    # Barplot
    Midpoints = barplot(X['mean',times_sorted], names.arg = '', 
                        las = 1, ylim = c(0,max(X)), 
                        col = cols[threshold], 
                        main = sprintf('%s', fs), 
                        ylab = bquote('Proportion with LCI of'~hat(italic(r))>.(threshold)))
    
    
    segments(x0 = Midpoints[,1], x1 = Midpoints[,1], 
             y0 = X['2.5%', times_sorted], y1 = X['97.5%', times_sorted], lty = 1)
    text(x = Midpoints, y = -max(X)/20, srt = 40, adj= 1, xpd = TRUE, 
         labels = gsub('_', ' & ',colnames(X)), cex = 0.5)
    title(xlab = expression(Delta~'Time (weeks)'), line = 2)
  }
}





if(PDF){dev.off()}