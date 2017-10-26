#Program name - Calculate Cluster Purity
#Calculate the purity of each district by looking at whether similar block groups are in the same district
#Date - October 21, 2017
#Author - Nick Chen

#packages
library(plyr)
library(dplyr)

#Working directory and load data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data/All_CA")
getwd()

list.files()

load("SD_blockgroup_pop_voting_w_clusters.RData")

SD_blockgroup_pop_and_voting_data_2 <- SD_blockgroup_pop_and_voting_data

#purity calculation function

cluster_purity_calc <- function(df, cluster_var, district_var){
  
  #get count of each cluster in each district.
  cluster_counts <- ddply(df, c(district_var, cluster_var), summarise,
                          num_block_groups = length(GEOID))
  
  #reshape to wide
  cluster_counts_wide <- reshape(cluster_counts, idvar = district_var, timevar = cluster_var, direction = "wide")
  
  #replace NA counts with zero
  cluster_counts_wide[is.na(cluster_counts_wide)] <- 0
  
  #Get total number of block groups in each district
  cluster_counts_wide$total_blockgroups <- cluster_counts_wide$num_block_groups.1 + cluster_counts_wide$num_block_groups.2 +
    cluster_counts_wide$num_block_groups.3 + cluster_counts_wide$num_block_groups.4 +
    cluster_counts_wide$num_block_groups.5
  
  #Get share of each district acounted for by block groups in each cluster
  cluster_counts_wide$cluster_1_share <- cluster_counts_wide$num_block_groups.1 / cluster_counts_wide$total_blockgroups
  cluster_counts_wide$cluster_2_share <- cluster_counts_wide$num_block_groups.2 / cluster_counts_wide$total_blockgroups
  cluster_counts_wide$cluster_3_share <- cluster_counts_wide$num_block_groups.3 / cluster_counts_wide$total_blockgroups
  cluster_counts_wide$cluster_4_share <- cluster_counts_wide$num_block_groups.4 / cluster_counts_wide$total_blockgroups
  cluster_counts_wide$cluster_5_share <- cluster_counts_wide$num_block_groups.5 / cluster_counts_wide$total_blockgroups
  
  #get the max purity for each district
  cluster_counts_wide$max_purity <- do.call(pmax, cluster_counts_wide[8:12])
  
  #Take the mean of the max purities?
  #what is the best measure?
  return(mean(cluster_counts_wide$max_purity))

}

cluster_purity_calc(SD_blockgroup_pop_and_voting_data, "all_cluster", "existing_district")










