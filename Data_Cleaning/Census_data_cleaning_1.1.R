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

# import block level populations
WI_block_level_pop <- read.csv("WI_block_level_population.csv")

# import block to VTD crosswalk
# https://www.census.gov/geo/maps-data/data/baf.html
WI_block_to_VTD_crosswalk <- read.csv("WI_block_to_VTD_crosswalk.txt")

#Add block group to census block level dataset
#Block group corresponds to the first number of the block. Blocks are grouped within tracts.
WI_block_level_pop$blockgroup <- substring(as.character(WI_block_level_pop$BLOCKCE), 1, 1)

#********************************************
# TESTING THIS BLOCK GROUP ASSIGNMENT
# Group by block group to get total population within each block group, then compare against block group level population downloaded directly
calculated_block_group_pop <- ddply(WI_block_level_pop, c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup"), summarize,
                                         calculated_population=sum(POP10))

# Merge with directly downloaded data
# This block group assignment works!
block_group_pop_compare <- merge(x = calculated_block_group_pop, y = dane.county.blocks.race[,c("STATEFP10", "COUNTYFP10", "TRACTCE10", "blockgroup", "total_population")])


test <- WI_block_level_pop[WI_block_level_pop$TRACTCE10 == 11102,]



#**********************************************************************************
# All counties in a state
# Get full list of counties in a state
# fips.county is a dataframe that comes with the acs package and lists all counties in all states.
PA.counties <- fips.county[fips.county$State == "PA", c("County.ANSI")]

#try setting geography for all counties in PA
PA_all_counties_geo=geo.make(state="PA", county=PA.counties, tract = "*", block.group="*", check = T)

#download 


























