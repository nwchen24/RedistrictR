#Program name - Gerrymandering - Census Data Prep
#Date - September 25, 2017
#Author - Nick Chen
#Reference - http://zevross.com/blog/2015/10/14/manipulating-and-mapping-us-census-data-in-r-using-the-acs-tigris-and-leaflet-packages-3/#census-data-the-easyer-way

#********************************************************************************
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

#Census specific packages
library(tigris)
library(acs)
library(stringr) # to pad fips codes

api.key.install(key="655243102b54da1e940feca4a32bcefa453c93fc")

#**********************************************************************************
# Get the data for a single county for testing
# note that you can use county names in the tigris package but 
# not in the acs.fetch function from the acs package so I'm using
# fips numbers here.

# grab the spatial data (tigris)
# get census tracts
CA_tract_shapes <- tracts(state = 'CA', cb=TRUE)

# get voting district shapes
CA_voting_district_shapes <- voting_districts(state = 'CA')

# get block group shapes
CA_block_group_shapes <- block_groups(state = 'CA')

# This site has a table showing the level of data and arguments required
# https://rdrr.io/cran/acs/man/geo.make.html

# Chapter 5 of this data report contains a list of tables.
# https://www.census.gov/prod/cen2010/doc/sf1.pdf


#********************************
# Import statewide data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data/All_CA")
getwd()

# import block level populations
# https://www.census.gov/geo/maps-data/data/tiger-data.html
#Use mapshaper.org to load the data and export to csv
CA_block_level_pop <- read.csv("CA_block_level_population_input.csv")


# import block to VTD crosswalk
# https://www.census.gov/geo/maps-data/data/baf.html
CA_block_to_VTD_crosswalk <- read.csv("BlockAssign_ST06_CA_VTD.txt")

#Add block group to census block level dataset
#Block group corresponds to the first number of the block. Blocks are grouped within tracts.
CA_block_level_pop$blockgroup <- substring(as.character(CA_block_level_pop$BLOCKCE), 1, 1)

#Import LA County voting data available here:
#http://statewidedatabase.org/d10/index_election.html
CA_block_level_voting_data <- read.dbf("statewide_PRS.dbf")



#*************************************************************************************
#County data pull function
#Takes a California county name as argument and returns DF with population and voting data at the block group level
#*************************************************************************************

county.data.pull <- function(county_name) {
  
  #County level data through census API
  # this defines the area over which you would like to gather data
  county_geo=geo.make(state="CA", county=county_name, tract = "*", block.group="*", check = T)
  
  # span = 0 for decennial census
  # table.number = "P3" is a table summarizing race. See above for a link to a file containing table numbers
  # table.number = "P5" is a table containing race broken out by Hispanic / latino
  # use of col.names = "pretty" above gives the full column definitions
  # if you want Census variable IDs use col.names="auto".
  race<-acs.fetch(endyear = 2010, span = 0, dataset = "sf1", geography = county_geo,
                  table.number = "P5", col.names = "pretty", case.sensitive = F)
  
  
  
  # Convert the downloaded data to dataframe
  blocks.race <- as.data.frame(race@estimate)
  
  # add variables for state, county, tract, and block group
  blocks.race$state <- race@geography$state
  blocks.race$county <- race@geography$county
  blocks.race$tract <- race@geography$tract
  blocks.race$blockgroup <- race@geography$blockgroup
  
  # Rename variables"P5. HISPANIC OR LATINO ORIGIN BY RACE: Total population"                                                          
  names(blocks.race) <- c("total_population",
                             "not_hisp_latin_total",
                             "not_hisp_latin_white",
                             "not_hisp_latin_black",
                             "not_hisp_latin_amerindian_alaskan",
                             "not_hisp_latin_asian",
                             "not_hisp_latin_hawaiian_pacislander",
                             "not_hisp_latin_other_race",
                             "not_hisp_latin_two_or_more_races",
                             "hisp_latin_total",
                             "hisp_latin_white",
                             "hisp_latin_black",
                             "hisp_latin_amerindian_alaskan",
                             "hisp_latin_asian",
                             "hisp_latin_hawaiian_pacislander",
                             "hisp_latin_other_race",
                             "hisp_latin_two_or_more_races",
                             "STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup")
  

  #*******************************
  #Download economic data
  #Look at tables here: https://www.census.gov/programs-surveys/acs/technical-documentation/table-shells.2010.html
  #Table B19049 has median income by 
  #acs.lookup(endyear=2011, span=5,dataset="acs", keyword= c("median","income","household","total"), case.sensitive=F)
  
  income <- acs.fetch(endyear = 2011, span = 5, dataset = "acs", geography = county_geo,
                      table.number = "B19049", col.names = "pretty", case.sensitive = F)
  
  #put estimates in dataframe
  blocks.income <- as.data.frame(income@estimate)
  
  # add variables for state, county, tract, and block group
  blocks.income$STATEFP <- income@geography$state
  blocks.income$COUNTYFP <- income@geography$county
  blocks.income$TRACTCE <- income@geography$tract
  blocks.income$BLKGRPCE <- income@geography$blockgroup
  
  rownames(blocks.income) <- seq(length=nrow(blocks.income))
  
  #Rename columns
  names(blocks.income)[1] <- c("overall_median_income")
  
  #drop columns we don't need
  blocks.income <- blocks.income[,c("overall_median_income", "STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE")]
  
  
  #*******************************
  #Download age data
  #Look at tables here: https://www.census.gov/programs-surveys/acs/technical-documentation/table-shells.2010.html
  #Table B01002 has median age
  #acs.lookup(endyear=2011, span=5,dataset="acs", keyword= c("median","age","total"), case.sensitive=F)
  
  age <- acs.fetch(endyear = 2011, span = 5, dataset = "acs", geography = county_geo,
                   table.number = "B01002", col.names = "pretty", case.sensitive = F)
  
  #put estimates in dataframe
  blocks.age <- as.data.frame(age@estimate)
  
  # add variables for state, county, tract, and block group
  blocks.age$STATEFP <- age@geography$state
  blocks.age$COUNTYFP <- age@geography$county
  blocks.age$TRACTCE <- age@geography$tract
  blocks.age$BLKGRPCE <- age@geography$blockgroup
  
  rownames(blocks.age) <- seq(length=nrow(blocks.age))
  
  #Rename columns
  names(blocks.age)[1] <- c("overall_median_age")
  
  #drop columns we don't need
  blocks.age <- blocks.age[,c("overall_median_age", "STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE")]
  
  
  #********************************************
  #Get estimated counts of each demographic in each block by proportional assignment
  #Merge block group total population with block level populations
  block_level_pop_2 <- merge(x = CA_block_level_pop, y = blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population",
                                                                              "not_hisp_latin_total",  "hisp_latin_total",
                                                                              "not_hisp_latin_white", "hisp_latin_white",
                                                                              "not_hisp_latin_black", "hisp_latin_black",
                                                                              "not_hisp_latin_asian", "hisp_latin_asian"
  )])
  
  #rename block group population
  names(block_level_pop_2)[10] <- "blockgroup_pop_total"
  
  #combine some columns
  block_level_pop_2$blockgroup_pop_white <- block_level_pop_2$not_hisp_latin_white + block_level_pop_2$hisp_latin_white
  block_level_pop_2$blockgroup_pop_black <- block_level_pop_2$not_hisp_latin_black + block_level_pop_2$hisp_latin_black
  block_level_pop_2$blockgroup_pop_asian <- block_level_pop_2$not_hisp_latin_asian + block_level_pop_2$hisp_latin_asian
  block_level_pop_2$blockgroup_pop_hisp <- block_level_pop_2$hisp_latin_total
  
  #Other includes american indian / native alaskan and hawiian and pacific islanders
  block_level_pop_2$blockgroup_pop_other <- block_level_pop_2$blockgroup_pop_total -
    block_level_pop_2$blockgroup_pop_white -
    block_level_pop_2$blockgroup_pop_black -
    block_level_pop_2$blockgroup_pop_asian
  
  #remove variables we don't want
  drops <- c("not_hisp_latin_total","hisp_latin_total", "not_hisp_latin_white", "hisp_latin_white",
             "not_hisp_latin_black", "hisp_latin_black", "not_hisp_latin_asian", "hisp_latin_asian",
             "HOUSING10", "PARTFLG")
  block_level_pop_2 <- block_level_pop_2[ , !(names(block_level_pop_2) %in% drops)]
  
  #get proportion of each block to be assigned to each demographic
  block_level_pop_2$prop_hisp <- block_level_pop_2$blockgroup_pop_hisp / block_level_pop_2$blockgroup_pop_total
  block_level_pop_2$prop_white <- block_level_pop_2$blockgroup_pop_white / block_level_pop_2$blockgroup_pop_total
  block_level_pop_2$prop_black <- block_level_pop_2$blockgroup_pop_black / block_level_pop_2$blockgroup_pop_total
  block_level_pop_2$prop_asian <- block_level_pop_2$blockgroup_pop_asian / block_level_pop_2$blockgroup_pop_total
  block_level_pop_2$prop_other <- block_level_pop_2$blockgroup_pop_other / block_level_pop_2$blockgroup_pop_total
  
  #remove variables we don't want
  drops <- c("blockgroup_pop_hisp","blockgroup_pop_white", "blockgroup_pop_black", "blockgroup_pop_asian",
             "blockgroup_pop_other", "blockgroup_pop_total")
  
  block_level_pop_2 <- block_level_pop_2[ , !(names(block_level_pop_2) %in% drops)]
  
  #get estimated number of individuals in each block in each demographic group
  #Note, this makes the assumption that different demographic populations are uniformly distributed throughout the block groups
  block_level_pop_2$block_pop_white_est <- block_level_pop_2$POP10 * block_level_pop_2$prop_white
  block_level_pop_2$block_pop_hisp_est <- block_level_pop_2$POP10 * block_level_pop_2$prop_hisp
  block_level_pop_2$block_pop_black_est <- block_level_pop_2$POP10 * block_level_pop_2$prop_black
  block_level_pop_2$block_pop_asian_est <- block_level_pop_2$POP10 * block_level_pop_2$prop_asian
  block_level_pop_2$block_pop_other_est <- block_level_pop_2$POP10 * block_level_pop_2$prop_other
  
  #remove variables we don't want
  drops <- c("prop_white","prop_hisp", "prop_black", "prop_asian", "prop_other")
  
  block_level_pop_2 <- block_level_pop_2[ , !(names(block_level_pop_2) %in% drops)]
  
  #********************************************
  #Create voting district level dataset with estimated populations for each demographic
  CA_block_level_voting_data$Geoid10 <- as.character(CA_block_level_voting_data$Geoid10)
  CA_block_level_voting_data$blockID_for_merge <- substr(CA_block_level_voting_data$Geoid10, 2, 15)
  block_level_pop_2$BLOCKID10 <- as.character(block_level_pop_2$BLOCKID10)
  
  #Note, there are about 33k census blocks that do not have election results
  #The population of these census blocks in aggregate is 146,277
  #87% of these blocks have a population of zero.
  #In the remaining 13%, the average population is 33 people and the max is 4,134
  #Assumption, set these census blocks as politically neutral
  block_level_pop_and_voting_data <- merge(x = block_level_pop_2, y = CA_block_level_voting_data[,c("PRSDEM", "PRSREP", "blockID_for_merge")],
                                              by.x = c("BLOCKID10"), by.y = c("blockID_for_merge"), all.x = TRUE)
  
  #Set the blocks that did not merge as politically neutral
  block_level_pop_and_voting_data$PRSDEM <- ifelse(!is.na(block_level_pop_and_voting_data$PRSDEM),
                                                      block_level_pop_and_voting_data$PRSDEM,
                                                      block_level_pop_and_voting_data$POP10 * 0.5)
  
  block_level_pop_and_voting_data$PRSREP <- ifelse(!is.na(block_level_pop_and_voting_data$PRSREP),
                                                      block_level_pop_and_voting_data$PRSREP,
                                                      block_level_pop_and_voting_data$POP10 * 0.5)
  
  #adjust names
  names(block_level_pop_and_voting_data)[7] <- "block_pop_total"
  names(block_level_pop_and_voting_data)[13] <- "Dem_votes_Pres_08"
  names(block_level_pop_and_voting_data)[14] <- "Rep_votes_Pres_08"
  names(block_level_pop_and_voting_data)[2] <- "STATEFP"
  names(block_level_pop_and_voting_data)[3] <- "COUNTYFP"
  names(block_level_pop_and_voting_data)[4] <- "TRACTCE"
  names(block_level_pop_and_voting_data)[5] <- "BLKGRPCE"
  

  #Aggregate to the block group level
  blockgroup_pop_and_voting_data <- ddply(block_level_pop_and_voting_data, c("STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE"), summarize,
                                             block_pop_total = sum(as.numeric(block_pop_total)),
                                             block_pop_white_est = sum(as.numeric(block_pop_white_est)),
                                             block_pop_hisp_est = sum(as.numeric(block_pop_hisp_est)),
                                             block_pop_black_est = sum(as.numeric(block_pop_black_est)),
                                             block_pop_asian_est = sum(as.numeric(block_pop_asian_est)),
                                             block_pop_other_est = sum(as.numeric(block_pop_other_est)),
                                             Dem_votes_Pres_08 = sum(as.numeric(Dem_votes_Pres_08)),
                                             Rep_votes_Pres_08 = sum(as.numeric(Rep_votes_Pres_08)))
  
  #merge in age and income
  blockgroup_pop_and_voting_data <- merge(blockgroup_pop_and_voting_data, blocks.income)
  blockgroup_pop_and_voting_data <- merge(blockgroup_pop_and_voting_data, blocks.age)
  
  return(blockgroup_pop_and_voting_data)
}

#Call function to pull data for LA, San Diego, and Sacramento counties
LA_blockgroup_pop_and_voting_data <- county.data.pull("Los Angeles")
SD_blockgroup_pop_and_voting_data <- county.data.pull("San Diego")
SAC_blockgroup_pop_and_voting_data <- county.data.pull("Sacramento")

#Save as R data
save(CA_block_group_shapes,
     LA_blockgroup_pop_and_voting_data,
     SD_blockgroup_pop_and_voting_data,
     SAC_blockgroup_pop_and_voting_data,
     file = "SAC_LA_SD_blockgroup_pop_voting_and_shapes.RData")

load("SAC_LA_SD_blockgroup_pop_voting_and_shapes.RData")








