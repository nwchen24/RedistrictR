#Program name - Add Clusters to Data
#Add clusters to the data
#Date - October 21, 2017
#Author - Nick Chen

#import packages
#General packages
library(data.table)
library(stargazer)
library(gmodels)
library(sandwich)
library(lmtest)
library(multiwayvcov)
library(AER)
library(plyr)
library(xlsx)
library(foreign)
library(leaflet)
library(rgdal)
library(sp)
library(maptools)


#Working directory and load data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data/All_CA")
getwd()

load("SD_blockgroup_pop_voting_and_shapes.RData")

#**************************************************************************
SD_blockgroup_pop_and_voting_data_3 <- SD_blockgroup_pop_and_voting_data_2

#Create share of democratic and republican votes
SD_blockgroup_pop_and_voting_data_3$Dem_votes_Pres_08_share <- SD_blockgroup_pop_and_voting_data_3$Dem_votes_Pres_08 /
  (SD_blockgroup_pop_and_voting_data_3$Dem_votes_Pres_08 + SD_blockgroup_pop_and_voting_data_3$Rep_votes_Pres_08)

SD_blockgroup_pop_and_voting_data_3$Rep_votes_Pres_08_share <- SD_blockgroup_pop_and_voting_data_3$Rep_votes_Pres_08 /
  (SD_blockgroup_pop_and_voting_data_3$Dem_votes_Pres_08 + SD_blockgroup_pop_and_voting_data_3$Rep_votes_Pres_08)

#Create share of population for each race
SD_blockgroup_pop_and_voting_data_3$pop_white_share <- SD_blockgroup_pop_and_voting_data_3$block_pop_white_est / SD_blockgroup_pop_and_voting_data_3$block_pop_total
SD_blockgroup_pop_and_voting_data_3$pop_black_share <- SD_blockgroup_pop_and_voting_data_3$block_pop_black_est / SD_blockgroup_pop_and_voting_data_3$block_pop_total
SD_blockgroup_pop_and_voting_data_3$pop_asian_share <- SD_blockgroup_pop_and_voting_data_3$block_pop_asian_est / SD_blockgroup_pop_and_voting_data_3$block_pop_total
SD_blockgroup_pop_and_voting_data_3$pop_hisp_share <- SD_blockgroup_pop_and_voting_data_3$block_pop_hisp_est / SD_blockgroup_pop_and_voting_data_3$block_pop_total
SD_blockgroup_pop_and_voting_data_3$pop_other_share <- SD_blockgroup_pop_and_voting_data_3$block_pop_other_est / SD_blockgroup_pop_and_voting_data_3$block_pop_total


#Keep only the columns we're interested in
SD_blockgroup_pop_and_voting_data_cluster <- SD_blockgroup_pop_and_voting_data_3[,c("GEOID", "block_pop_total",
                                                                                  "pop_white_share", "pop_black_share",
                                                                                  "pop_asian_share", "pop_hisp_share",
                                                                                  "pop_other_share", "Dem_votes_Pres_08_share",
                                                                                  "Rep_votes_Pres_08_share",
                                                                                  "overall_median_age", "overall_median_income")]


#normalize data
SD_blockgroup_pop_and_voting_data_cluster[,c(2:11)] <- scale(SD_blockgroup_pop_and_voting_data_cluster[,c(2:11)])


#**************************************************************************************
#clustering
#K means clustering across all variables
SD_cluster_results <- kmeans(SD_blockgroup_pop_and_voting_data_cluster[,2:11], centers = 5, nstart = 20)

#Merge the cluster results with the original data
SD_blockgroup_pop_and_voting_data_cluster$all_cluster <- SD_cluster_results$cluster
#K means clustering on only demographic variables
SD_cluster_results <- kmeans(SD_blockgroup_pop_and_voting_data_cluster[,2:7], centers = 5, nstart = 20)
#merge with the original data
SD_blockgroup_pop_and_voting_data_cluster$racial_demographic_cluster <- SD_cluster_results$cluster

#merge clusters back with original data

#add datafrmae column descriptions.
SD_blockgroup_pop_and_voting_data <- merge(SD_blockgroup_pop_and_voting_data_2,
                                           SD_blockgroup_pop_and_voting_data_cluster[,c("GEOID", "all_cluster", "racial_demographic_cluster")])

#add documentation to the dataframe
attr(SD_blockgroup_pop_and_voting_data, "doc") <- "This file summarizes population and election results from the 2008 presidential election (to be used as a proxy for the political characteristics of a census block) at the *CENSUS BLOCK GROUP LEVEL*. San Diego county. I've also included corresponding block group shape files in the RData file.

A few things to note.
1. I was able to find election data that had been disaggregated to the census block level by the folks at UC Berkeley who maintain California election results data. If you want to read more about the disaggregation methodology, you can look at the paper here: http://statewidedatabase.org/d10/Creating%20CA%20Official%20Redistricting%20Database.pdf
2. There were a relatively large proportion of census blocks that were not in the election dataset. However, these census blocks overall had very low populations as of the 2010 census. For the time being, I assumed a neutral political split (50/50) between republicans and democrats.
3. The cluster variables were created using kmeans clustering.
    a. Voting data and racial breakdown data were converted to shares of the total and then scaled to mean of zero and SD of 1.
    b. Total population, median age, and median income were scaled to mean of zero and SD of 1.
    c. The 'all_cluster' variable took into account all of these variables in the kmeans algorithm. K = 5.
    d. The 'racial_demographic_cluster' variable took into account ONLY the racial breakdown variables.
3. The other variables should be in the dataset should be relatively self explanatory.
4. The median age and income variables are from the 2010 5 year ACS survey. NA values in these variables have been filled in with the average for populated block groups within the county."

save(SD_blockgroup_pop_and_voting_data, CA_block_group_shapes, file = "SD_blockgroup_pop_voting_w_clusters.RData")












