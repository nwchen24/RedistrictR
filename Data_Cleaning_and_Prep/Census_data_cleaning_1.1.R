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
WI_tract_shapes <- tracts(state = 'WI', cb=TRUE)

# get voting district shapes
WI_voting_district_shapes <- voting_districts(state = 'WI')

# get block group shapes
WI_block_group_shapes <- block_groups(state = 'WI')

# This site has a table showing the level of data and arguments required
# https://rdrr.io/cran/acs/man/geo.make.html

# Chapter 5 of this data report contains a list of tables.
# https://www.census.gov/prod/cen2010/doc/sf1.pdf

# this defines the area over which you would like to gather data
dane_county_geo=geo.make(state="WI", county="Dane", tract = "*", block.group="*", check = T)

# span = 0 for decennial census
# table.number = "P3" is a table summarizing race. See above for a link to a file containing table numbers
# table.number = "P5" is a table containing race broken out by Hispanic / latino
# use of col.names = "pretty" above gives the full column definitions
# if you want Census variable IDs use col.names="auto".
race<-acs.fetch(endyear = 2010, span = 0, dataset = "sf1", geography = dane_county_geo,
                table.number = "P5", col.names = "pretty", case.sensitive = F)

# Convert the downloaded data to dataframe
dane.county.blocks.race <- as.data.frame(race@estimate)

# add variables for state, county, tract, and block group
dane.county.blocks.race$state <- race@geography$state
dane.county.blocks.race$county <- race@geography$county
dane.county.blocks.race$tract <- race@geography$tract
dane.county.blocks.race$blockgroup <- race@geography$blockgroup

# Rename variables"P5. HISPANIC OR LATINO ORIGIN BY RACE: Total population"                                                          
names(dane.county.blocks.race) <- c("total_population",
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
  

#Sum of total population is 488k for Dane County, WI
sum(dane.county.blocks.race$total_population)

# You can download mapping from census tracts to 113th congressional districts from this link
# https://www.census.gov/geo/maps-data/data/cd_state.html

#**********************************************************************************
# Census block groups (the smallest unit on which the census reports data) will not always be self contained within voting districts
# We need to map census block groups to voting districts which are the building blocks from which our tool will build new district proposals.

# Steps for achieving voting districts with prior election results and demographic data.
# 1. Have:
#       - voting district election data from Harvard.
#       - dataset linking census blocks to voting district.
#       - dataset linking census block to census block group.
#       - dataset with population of each census block.
#       - dataset with census block group demographics.
# 3. Get the proportion of each census block group represented by each census block.
#       - merge census block group populations with census block to census block group crosswalk.
#       - merge census block group demographics with dataset created above.
#       - get proportion of census block group population within each block
#       - proportionally assign the number of individuals in each census block group category to each block
# 4. Merge created block level demographic dataset with census block to voting district mapping
# 5. Merge in voting district election results


#********************************
# Import data
setwd("/Users/nwchen24/Desktop/UC_Berkeley/w210_capstone/Gerrymandering/Data")
getwd()

#Import pre-cleaned Wisconsin dataset
WI_block_level_precleaned <- read.csv("55_redist_data.csv")


#import voting data
#Data https://dataverse.harvard.edu/dataset.xhtml?persistentId=hdl:1902.1/21919
#Data documentation https://dataverse.harvard.edu/file.xhtml?fileId=2456568&version=RELEASED&version=.0
load("WI_voting_data.RData")
WI_voting_data <- x

# import block level populations
WI_block_level_pop <- read.csv("WI_block_level_population.csv")

# import block to VTD crosswalk
# https://www.census.gov/geo/maps-data/data/baf.html
WI_block_to_VTD_crosswalk <- read.csv("WI_block_to_VTD_crosswalk.txt")

#Add block group to census block level dataset
#Block group corresponds to the first number of the block. Blocks are grouped within tracts.
WI_block_level_pop$blockgroup <- substring(as.character(WI_block_level_pop$BLOCKCE), 1, 1)

#Import VTD names
WI_vtd_names <- read.delim("WI_Voting_district_names.txt", sep = "|")

#********************************************
# TESTING THIS BLOCK GROUP ASSIGNMENT
# Group by block group to get total population within each block group, then compare against block group level population downloaded directly
calculated_block_group_pop <- ddply(WI_block_level_pop, c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup"), summarize,
                                         calculated_population=sum(POP10))

# Merge with directly downloaded data to see whether the sum of the block's individual populations matches the block groups
# This block group assignment works!
block_group_pop_compare <- merge(x = calculated_block_group_pop, y = dane.county.blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population")])
#********************************************


#********************************************
#Get estimated counts of each demographic in each block by proportional assignment
#Merge block group total population with block level populations
WI_block_level_pop_2 <- merge(x = WI_block_level_pop, y = dane.county.blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population",
                                                                                  "not_hisp_latin_total",  "hisp_latin_total",
                                                                                   "not_hisp_latin_white", "hisp_latin_white",
                                                                                   "not_hisp_latin_black", "hisp_latin_black",
                                                                                   "not_hisp_latin_asian", "hisp_latin_asian"
                                                                                   )])
#rename block group population
names(WI_block_level_pop_2)[10] <- "blockgroup_pop_total"

#combine some columns
WI_block_level_pop_2$blockgroup_pop_white <- WI_block_level_pop_2$not_hisp_latin_white + WI_block_level_pop_2$hisp_latin_white
WI_block_level_pop_2$blockgroup_pop_black <- WI_block_level_pop_2$not_hisp_latin_black + WI_block_level_pop_2$hisp_latin_black
WI_block_level_pop_2$blockgroup_pop_asian <- WI_block_level_pop_2$not_hisp_latin_asian + WI_block_level_pop_2$hisp_latin_asian
WI_block_level_pop_2$blockgroup_pop_hisp <- WI_block_level_pop_2$hisp_latin_total
#Other includes american indian / native alaskan and hawiian and pacific islanders
WI_block_level_pop_2$blockgroup_pop_other <- WI_block_level_pop_2$blockgroup_pop_total - WI_block_level_pop_2$blockgroup_pop_white - WI_block_level_pop_2$blockgroup_pop_black - WI_block_level_pop_2$blockgroup_pop_asian

#remove variables we don't want
drops <- c("not_hisp_latin_total","hisp_latin_total", "not_hisp_latin_white", "hisp_latin_white",
           "not_hisp_latin_black", "hisp_latin_black", "not_hisp_latin_asian", "hisp_latin_asian",
           "HOUSING10", "PARTFLG")
WI_block_level_pop_2 <- WI_block_level_pop_2[ , !(names(WI_block_level_pop_2) %in% drops)]

#get proportion of each block to be assigned to each demographic
WI_block_level_pop_2$prop_hisp <- WI_block_level_pop_2$blockgroup_pop_hisp / WI_block_level_pop_2$blockgroup_pop_total
WI_block_level_pop_2$prop_white <- WI_block_level_pop_2$blockgroup_pop_white / WI_block_level_pop_2$blockgroup_pop_total
WI_block_level_pop_2$prop_black <- WI_block_level_pop_2$blockgroup_pop_black / WI_block_level_pop_2$blockgroup_pop_total
WI_block_level_pop_2$prop_asian <- WI_block_level_pop_2$blockgroup_pop_asian / WI_block_level_pop_2$blockgroup_pop_total
WI_block_level_pop_2$prop_other <- WI_block_level_pop_2$blockgroup_pop_other / WI_block_level_pop_2$blockgroup_pop_total

#remove variables we don't want
drops <- c("blockgroup_pop_hisp","blockgroup_pop_white", "blockgroup_pop_black", "blockgroup_pop_asian",
           "blockgroup_pop_other", "blockgroup_pop_total")

WI_block_level_pop_2 <- WI_block_level_pop_2[ , !(names(WI_block_level_pop_2) %in% drops)]

#get estimated number of individuals in each block in each demographic group
#Note, this makes the assumption that different demographic populations are uniformly distributed throughout the block groups
WI_block_level_pop_2$block_pop_white_est <- WI_block_level_pop_2$POP10 * WI_block_level_pop_2$prop_white
WI_block_level_pop_2$block_pop_hisp_est <- WI_block_level_pop_2$POP10 * WI_block_level_pop_2$prop_hisp
WI_block_level_pop_2$block_pop_black_est <- WI_block_level_pop_2$POP10 * WI_block_level_pop_2$prop_black
WI_block_level_pop_2$block_pop_asian_est <- WI_block_level_pop_2$POP10 * WI_block_level_pop_2$prop_asian
WI_block_level_pop_2$block_pop_other_est <- WI_block_level_pop_2$POP10 * WI_block_level_pop_2$prop_other

#remove variables we don't want
drops <- c("prop_white","prop_hisp", "prop_black", "prop_asian", "prop_other")

WI_block_level_pop_2 <- WI_block_level_pop_2[ , !(names(WI_block_level_pop_2) %in% drops)]

#********************************************
#Create voting district level dataset with estimated populations for each demographic

#remove county from block to vtd crosswalk for merge
WI_block_to_VTD_crosswalk2 <- WI_block_to_VTD_crosswalk[,c("BLOCKID", "DISTRICT")]

#rename columns for merge
names(WI_block_to_VTD_crosswalk2) <- c("BLOCKID_from_crosswalk", "VTD")


#Having trouble getting these to merge
#deconstruct blockID in the crosswalk
#BLOCKID:  15-character code that is the concatenation of fields consisting of the 2-character state FIPS code, the 3-character county FIPS code, the 6-character census tract code, and the 4-character tabulation block code.
WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk <- as.character(WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk)

WI_block_to_VTD_crosswalk2$STATEFP10 <- as.numeric(substr(WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk, 1, 2))
WI_block_to_VTD_crosswalk2$COUNTYFP10 <- as.numeric(substr(WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk, 3, 5))
WI_block_to_VTD_crosswalk2$TRACTCE10 <- as.numeric(substr(WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk, 6, 11))
WI_block_to_VTD_crosswalk2$BLOCKCE <- as.numeric(substr(WI_block_to_VTD_crosswalk2$BLOCKID_from_crosswalk, 12, 15))

#merge on VTD names to block-VTD crosswalk
#standardize VTD names
WI_vtd_names$VTD_NAME <- toupper(WI_vtd_names$VTD_NAME)
WI_vtd_names$VTD_NAME <- gsub(" VOTING DISTRICT", "", WI_vtd_names$VTD_NAME)
WI_vtd_names$VTD_NAME <- gsub("\\s", "", WI_vtd_names$VTD_NAME)

WI_block_to_VTD_crosswalk2 <- merge(x = WI_block_to_VTD_crosswalk2, y = WI_vtd_names[,c("COUNTY_CODE", "VTD_CODE", "VTD_NAME")], by.x = c("COUNTYFP10", "VTD"),
                                  by.y = c("COUNTY_CODE", "VTD_CODE"))

#merge block level populations with voting districts
WI_voting_block_district_pops <- merge(x = WI_block_to_VTD_crosswalk2, y = WI_block_level_pop_2, by = c("STATEFP10", "COUNTYFP10","TRACTCE10","BLOCKCE"))

#*******************************
#*******************************
#*******************************
#*******************************
#*******************************
#*******************************

Dane_voting_data <- WI_voting_data[WI_voting_data$county == "Dane",]

#standardize voting district name
Dane_voting_data$precinct <- toupper(Dane_voting_data$precinct)
Dane_voting_data$precinct <- gsub("\\s", "", Dane_voting_data$precinct)

#rename precinct column
Dane_voting_data$VTD_NAME <- Dane_voting_data$precinct


#drop some variables we don't need
drops <- c("precinct", "state", "year", "vtd", "mcd", "mcd_code", "county", "ward", "fips")
Dane_voting_data <- Dane_voting_data[ , !(names(Dane_voting_data) %in% drops)]

#Create numeric county variable
Dane_voting_data$fips_cnty <- as.character(Dane_voting_data$fips_cnty)
Dane_voting_data$COUNTYFP10 <- as.numeric(substr(Dane_voting_data$fips_cnty, 3, 6))

#Merge in voting data with population based on voting distric name
Dane_combined_data <- merge(x = WI_voting_block_district_pops, y = Dane_voting_data, by = c("COUNTYFP10", "VTD_NAME"))

#*************************************************
#sum up to the VTD level
Dane_combined_data_VTD <- ddply(Dane_combined_data, c("VTD_NAME", "VTD", "STATEFP10", "COUNTYFP10"), summarize,
                                pop_total = sum(POP10), pop_white = sum(block_pop_white_est),
                                pop_hisp = sum(block_pop_hisp_est), pop_black = sum(block_pop_black_est),
                                pop_asian = sum(block_pop_asian_est), pop_other = sum(block_pop_other_est),
                                g2010_USH_dv = max(g2010_USH_dv),g2010_USH_rv = max(g2010_USH_rv),
                                g2010_USH_tv = max(g2010_USH_tv), g2010_STH_dv = max(g2010_STH_dv),
                                g2010_STH_rv = max(g2010_STH_rv), g2010_STH_tv = max(g2010_STH_tv),
                                g2010_GOV_dv = max(g2010_GOV_dv), g2010_GOV_rv = max(g2010_GOV_rv),
                                g2010_GOV_tv = max(g2010_GOV_tv), g2010_ATG_dv = max(g2010_ATG_dv),
                                g2010_ATG_rv = max(g2010_ATG_rv), g2010_ATG_tv = max(g2010_ATG_tv),
                                g2010_SOS_dv = max(g2010_SOS_dv), g2010_SOS_rv = max(g2010_SOS_rv),
                                g2010_SOS_tv = max(g2010_SOS_tv), g2010_TRE_dv = max(g2010_TRE_dv),
                                g2010_TRE_rv = max(g2010_TRE_rv), g2010_TRE_tv = max(g2010_TRE_tv), 
                                g2010_USS_dv = max(g2010_USS_dv), g2010_USS_rv = max(g2010_USS_rv),
                                g2010_USS_tv = max(g2010_USS_tv), g2010_STS_dv = max(g2010_STS_dv),
                                g2010_STS_rv = max(g2010_STS_rv), g2010_STS_tv = max(g2010_STS_tv))


#Export
#This file contains:
#    (1) precinct / VTD level election results and estimated populations
#    (2) shape files for all VTDs in Wisconsin.
#The populations were estimated by apportioning block group level populations for each demographic down to the block level.
#Block group populations were assigned to the block level proportional to the share of each block group represented by each block.
#These block level populations for each demographic were then summed up to the VTD / precinct level to match election data collected by Harvard.
#The population variables all start with 'pop' and should be relatively self explanatory.

#The election results, all for 2010, all start with 'g2010'.
#The three letters between the two underscores identify the election as follows:
#    USH: US House
#    USS: US Senate
#    GOV: Governor
#    ATG: Attorney General
#    STH: State house / lower assembly
#    SOS: Secretary of State
#    TRE: State Treasurer
#    STS: State Senate / upper house
#The last two letters identify votes cast for each party as follows.
#    dv: Democratic votes
#    rv: Republican votes
#    tv: total votes.

save(Dane_combined_data_VTD, WI_voting_district_shapes, file = "Dane_County_WI_VTD_pop_voting_shapes.RData")

load("Dane_County_WI_VTD_pop_voting_shapes.RData")

#**********************************************************************************
# All counties in a state
# Get full list of counties in a state
# fips.county is a dataframe that comes with the acs package and lists all counties in all states.
WI.counties <- fips.county[fips.county$State == "PA", c("County.ANSI")]

#try setting geography for all counties in PA
WI_all_counties_geo=geo.make(state="WI", county=WI.counties, tract = "*", block.group="*", check = T)




