#Program name - Vote Efficiency Function
#Calculate the vote efficiency gap of a given district assignment
#Date - October 29, 2017
#Author - Nick Chen

#packages
library(plyr)
library(dplyr)

#Working directory and load data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data/All_CA")
getwd()

list.files()

load("SD_blockgroup_pop_voting_w_clusters.RData")


#Vote efficiency gap calculation function
vote_efficiency_gap_calc <- function(df, district_var){
  
  #get total republican and democratic votes in each district
  voting_summ <- ddply(df, c("existing_district"), summarize,
                               dem_votes = sum(Dem_votes_Pres_08), rep_votes = sum(Rep_votes_Pres_08))
  
  #get the winner
  voting_summ$winner <- ifelse(voting_summ$dem_votes > voting_summ$rep_votes,
                                       "Dem", "Rep")
  
  #get wasted democratic and replublican votes (i.e. votes above the winning threshold)
  voting_summ$dem_wasted <- ifelse(voting_summ$winner == "Dem",
                                   voting_summ$dem_votes - voting_summ$rep_votes, 0)
  
  voting_summ$rep_wasted <- ifelse(voting_summ$winner == "Rep",
                                   voting_summ$rep_votes - voting_summ$dem_votes, 0)
  
  #get the total wasted votes for each party
  dem_wasted_votes <- sum(voting_summ$dem_wasted)
  rep_wasted_votes <- sum(voting_summ$rep_wasted)
  
  #Calculate efficiency gap and efficiency gap percentage
  efficiency_gap <- abs(dem_wasted_votes - rep_wasted_votes)
  efficiency_gap_pct <- efficiency_gap / sum(voting_summ$dem_votes, voting_summ$rep_votes)
  
  return(efficiency_gap_pct)

}

vote_efficiency_gap_calc(SD_blockgroup_pop_and_voting_data, "existing_district")










