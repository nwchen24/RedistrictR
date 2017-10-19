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

# this defines the area over which you would like to gather data
LA_county_geo=geo.make(state="CA", county="Los Angeles", tract = "*", block.group="*", check = T)

# span = 0 for decennial census
# table.number = "P3" is a table summarizing race. See above for a link to a file containing table numbers
# table.number = "P5" is a table containing race broken out by Hispanic / latino
# use of col.names = "pretty" above gives the full column definitions
# if you want Census variable IDs use col.names="auto".
race<-acs.fetch(endyear = 2010, span = 0, dataset = "sf1", geography = LA_county_geo,
                table.number = "P5", col.names = "pretty", case.sensitive = F)



# Convert the downloaded data to dataframe
LA.blocks.race <- as.data.frame(race@estimate)

# add variables for state, county, tract, and block group
LA.blocks.race$state <- race@geography$state
LA.blocks.race$county <- race@geography$county
LA.blocks.race$tract <- race@geography$tract
LA.blocks.race$blockgroup <- race@geography$blockgroup

# Rename variables"P5. HISPANIC OR LATINO ORIGIN BY RACE: Total population"                                                          
names(LA.blocks.race) <- c("total_population",
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
  

#Sum of total population is 9,8 M for Los Angeles County, CA
sum(LA.blocks.race$total_population)

# You can download mapping from census tracts to 113th congressional districts from this link
# https://www.census.gov/geo/maps-data/data/cd_state.html


#*******************************
#Download economic data
#Look at tables here: https://www.census.gov/programs-surveys/acs/technical-documentation/table-shells.2010.html
#Table B19049 has median income by 
#acs.lookup(endyear=2011, span=5,dataset="acs", keyword= c("median","income","household","total"), case.sensitive=F)

income <- acs.fetch(endyear = 2011, span = 5, dataset = "acs", geography = LA_county_geo,
                      table.number = "B19049", col.names = "pretty", case.sensitive = F)

#put estimates in dataframe
LA.blocks.income <- as.data.frame(income@estimate)

# add variables for state, county, tract, and block group
LA.blocks.income$STATEFP <- income@geography$state
LA.blocks.income$COUNTYFP <- income@geography$county
LA.blocks.income$TRACTCE <- income@geography$tract
LA.blocks.income$BLKGRPCE <- income@geography$blockgroup

rownames(LA.blocks.income) <- seq(length=nrow(LA.blocks.income))

#Rename columns
names(LA.blocks.income)[1] <- c("overall_median_income")

#drop columns we don't need
LA.blocks.income <- LA.blocks.income[,c("overall_median_income", "STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE")]


#*******************************
#Download age data
#Look at tables here: https://www.census.gov/programs-surveys/acs/technical-documentation/table-shells.2010.html
#Table B19049 has median income by 
#acs.lookup(endyear=2011, span=5,dataset="acs", keyword= c("median","income", "household","total"), case.sensitive=F)

income <- acs.fetch(endyear = 2010, span = 5, dataset = "acs", geography = LA_county_geo,
                    table.number = "B19049", col.names = "pretty", case.sensitive = F)

#put estimates in dataframe
LA.blocks.income <- as.data.frame(income@estimate)

# add variables for state, county, tract, and block group
LA.blocks.income$STATEFP <- income@geography$state
LA.blocks.income$COUNTYFP <- income@geography$county
LA.blocks.income$TRACTCE <- income@geography$tract
LA.blocks.income$BLKGRPCE <- income@geography$blockgroup

rownames(LA.blocks.income) <- seq(length=nrow(LA.blocks.income))

#Rename columns
names(LA.blocks.income)[1] <- c("overall_median_income")

#drop columns we don't need
LA.blocks.income <- LA.blocks.income[,c("overall_median_income", "STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE")]


#Download age data
#Look at tables here: https://www.census.gov/programs-surveys/acs/technical-documentation/table-shells.2010.html
#Table B01002 has median age
#acs.lookup(endyear=2011, span=5,dataset="acs", keyword= c("median","age","total"), case.sensitive=F)

age <- acs.fetch(endyear = 2011, span = 5, dataset = "acs", geography = LA_county_geo,
                    table.number = "B01002", col.names = "pretty", case.sensitive = F)

#put estimates in dataframe
LA.blocks.age <- as.data.frame(age@estimate)

# add variables for state, county, tract, and block group
LA.blocks.age$STATEFP <- age@geography$state
LA.blocks.age$COUNTYFP <- age@geography$county
LA.blocks.age$TRACTCE <- age@geography$tract
LA.blocks.age$BLKGRPCE <- age@geography$blockgroup

rownames(LA.blocks.age) <- seq(length=nrow(LA.blocks.age))

#Rename columns
names(LA.blocks.age)[1] <- c("overall_median_age")

#drop columns we don't need
LA.blocks.age <- LA.blocks.age[,c("overall_median_age", "STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE")]



#********************************
# Import data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data/Los_Angeles")
getwd()

#import voting data
#Data https://dataverse.harvard.edu/dataset.xhtml?persistentId=hdl:1902.1/21919
#Data documentation https://dataverse.harvard.edu/file.xhtml?fileId=2456568&version=RELEASED&version=.0
load("CA_2010_voting_data.RData")
CA_voting_data <- x

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
LA_county_block_level_voting_data <- read.dbf("19_PRS.dbf")


#********************************************
# TESTING THIS BLOCK GROUP ASSIGNMENT
# Group by block group to get total population within each block group, then compare against block group level population downloaded directly
calculated_block_group_pop <- ddply(CA_block_level_pop, c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup"), summarize,
                                         calculated_population=sum(POP10))

# Merge with directly downloaded data to see whether the sum of the block's individual populations matches the block groups
# This block group assignment works!
block_group_pop_compare <- merge(x = calculated_block_group_pop, y = LA.blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population")])
#********************************************


#********************************************
#Get estimated counts of each demographic in each block by proportional assignment
#Merge block group total population with block level populations
LA_block_level_pop_2 <- merge(x = CA_block_level_pop, y = LA.blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population",
                                                                                  "not_hisp_latin_total",  "hisp_latin_total",
                                                                                   "not_hisp_latin_white", "hisp_latin_white",
                                                                                   "not_hisp_latin_black", "hisp_latin_black",
                                                                                   "not_hisp_latin_asian", "hisp_latin_asian"
                                                                                   )])

#rename block group population
names(LA_block_level_pop_2)[10] <- "blockgroup_pop_total"

#combine some columns
LA_block_level_pop_2$blockgroup_pop_white <- LA_block_level_pop_2$not_hisp_latin_white + LA_block_level_pop_2$hisp_latin_white
LA_block_level_pop_2$blockgroup_pop_black <- LA_block_level_pop_2$not_hisp_latin_black + LA_block_level_pop_2$hisp_latin_black
LA_block_level_pop_2$blockgroup_pop_asian <- LA_block_level_pop_2$not_hisp_latin_asian + LA_block_level_pop_2$hisp_latin_asian
LA_block_level_pop_2$blockgroup_pop_hisp <- LA_block_level_pop_2$hisp_latin_total

#Other includes american indian / native alaskan and hawiian and pacific islanders
LA_block_level_pop_2$blockgroup_pop_other <- LA_block_level_pop_2$blockgroup_pop_total -
  LA_block_level_pop_2$blockgroup_pop_white -
  LA_block_level_pop_2$blockgroup_pop_black -
  LA_block_level_pop_2$blockgroup_pop_asian

#remove variables we don't want
drops <- c("not_hisp_latin_total","hisp_latin_total", "not_hisp_latin_white", "hisp_latin_white",
           "not_hisp_latin_black", "hisp_latin_black", "not_hisp_latin_asian", "hisp_latin_asian",
           "HOUSING10", "PARTFLG")
LA_block_level_pop_2 <- LA_block_level_pop_2[ , !(names(LA_block_level_pop_2) %in% drops)]

#get proportion of each block to be assigned to each demographic
LA_block_level_pop_2$prop_hisp <- LA_block_level_pop_2$blockgroup_pop_hisp / LA_block_level_pop_2$blockgroup_pop_total
LA_block_level_pop_2$prop_white <- LA_block_level_pop_2$blockgroup_pop_white / LA_block_level_pop_2$blockgroup_pop_total
LA_block_level_pop_2$prop_black <- LA_block_level_pop_2$blockgroup_pop_black / LA_block_level_pop_2$blockgroup_pop_total
LA_block_level_pop_2$prop_asian <- LA_block_level_pop_2$blockgroup_pop_asian / LA_block_level_pop_2$blockgroup_pop_total
LA_block_level_pop_2$prop_other <- LA_block_level_pop_2$blockgroup_pop_other / LA_block_level_pop_2$blockgroup_pop_total

#remove variables we don't want
drops <- c("blockgroup_pop_hisp","blockgroup_pop_white", "blockgroup_pop_black", "blockgroup_pop_asian",
           "blockgroup_pop_other", "blockgroup_pop_total")

LA_block_level_pop_2 <- LA_block_level_pop_2[ , !(names(LA_block_level_pop_2) %in% drops)]

#get estimated number of individuals in each block in each demographic group
#Note, this makes the assumption that different demographic populations are uniformly distributed throughout the block groups
LA_block_level_pop_2$block_pop_white_est <- LA_block_level_pop_2$POP10 * LA_block_level_pop_2$prop_white
LA_block_level_pop_2$block_pop_hisp_est <- LA_block_level_pop_2$POP10 * LA_block_level_pop_2$prop_hisp
LA_block_level_pop_2$block_pop_black_est <- LA_block_level_pop_2$POP10 * LA_block_level_pop_2$prop_black
LA_block_level_pop_2$block_pop_asian_est <- LA_block_level_pop_2$POP10 * LA_block_level_pop_2$prop_asian
LA_block_level_pop_2$block_pop_other_est <- LA_block_level_pop_2$POP10 * LA_block_level_pop_2$prop_other

#remove variables we don't want
drops <- c("prop_white","prop_hisp", "prop_black", "prop_asian", "prop_other")

LA_block_level_pop_2 <- LA_block_level_pop_2[ , !(names(LA_block_level_pop_2) %in% drops)]

#********************************************
#Create voting district level dataset with estimated populations for each demographic
LA_county_block_level_voting_data$Geoid10 <- as.character(LA_county_block_level_voting_data$Geoid10)
LA_county_block_level_voting_data$blockID_for_merge <- substr(LA_county_block_level_voting_data$Geoid10, 2, 15)
LA_block_level_pop_2$BLOCKID10 <- as.character(LA_block_level_pop_2$BLOCKID10)

#Note, there are about 33k census blocks that do not have election results
#The population of these census blocks in aggregate is 146,277
#87% of these blocks have a population of zero.
#In the remaining 13%, the average population is 33 people and the max is 4,134
#Assumption, set these census blocks as politically neutral
LA_block_level_pop_and_voting_data <- merge(x = LA_block_level_pop_2, y = LA_county_block_level_voting_data[,c("PRSDEM", "PRSREP", "blockID_for_merge")],
                     by.x = c("BLOCKID10"), by.y = c("blockID_for_merge"), all.x = TRUE)

nonmerged_blocks <- LA_block_level_pop_and_voting_data[is.na(LA_block_level_pop_and_voting_data$PRSDEM),]
sum(nonmerged_blocks$POP10)
sum(nonmerged_blocks$POP10 == 0) / nrow(nonmerged_blocks)
summary(nonmerged_blocks[nonmerged_blocks$POP10 != 0,]$POP10)
plot(density(nonmerged_blocks[nonmerged_blocks$POP10 != 0,]$POP10))

#Set the blocks that did not merge as politically neutral
LA_block_level_pop_and_voting_data$PRSDEM <- ifelse(!is.na(LA_block_level_pop_and_voting_data$PRSDEM),
                                                    LA_block_level_pop_and_voting_data$PRSDEM,
                                                    LA_block_level_pop_and_voting_data$POP10 * 0.5)

LA_block_level_pop_and_voting_data$PRSREP <- ifelse(!is.na(LA_block_level_pop_and_voting_data$PRSREP),
                                                    LA_block_level_pop_and_voting_data$PRSREP,
                                                    LA_block_level_pop_and_voting_data$POP10 * 0.5)

#adjust names
names(LA_block_level_pop_and_voting_data)[7] <- "block_pop_total"
names(LA_block_level_pop_and_voting_data)[13] <- "Dem_votes_Pres_08"
names(LA_block_level_pop_and_voting_data)[14] <- "Rep_votes_Pres_08"
names(LA_block_level_pop_and_voting_data)[2] <- "STATEFP"
names(LA_block_level_pop_and_voting_data)[3] <- "COUNTYFP"
names(LA_block_level_pop_and_voting_data)[4] <- "TRACTCE"
names(LA_block_level_pop_and_voting_data)[5] <- "BLKGRPCE"



names(LA_block_level_pop_and_voting_data)

#Aggregate to the block group level
LA_blockgroup_pop_and_voting_data <- ddply(LA_block_level_pop_and_voting_data, c("STATEFP", "COUNTYFP", "TRACTCE", "BLKGRPCE"), summarize,
                                           block_pop_total = sum(block_pop_total),
                                           block_pop_white_est = sum(block_pop_white_est),
                                           block_pop_hisp_est = sum(block_pop_hisp_est),
                                           block_pop_black_est = sum(block_pop_black_est),
                                           block_pop_asian_est = sum(block_pop_asian_est),
                                           block_pop_other_est = sum(block_pop_other_est),
                                           Dem_votes_Pres_08 = sum(Dem_votes_Pres_08),
                                           Rep_votes_Pres_08 = sum(Rep_votes_Pres_08))

#merge in age and income
LA_blockgroup_pop_and_voting_data <- merge(LA_blockgroup_pop_and_voting_data, LA.blocks.income)
LA_blockgroup_pop_and_voting_data <- merge(LA_blockgroup_pop_and_voting_data, LA.blocks.age)


#Save as R data
save(CA_block_group_shapes, LA_block_level_pop_and_voting_data,  file = "LA_County_CA_blockgroup_pop_voting_and_shapes.RData")














