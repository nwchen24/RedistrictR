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
# Get the shape files for WI

# grab the spatial data (tigris)
# get census tracts
WI_tract_shapes <- tracts(state = 'WI', cb=TRUE)

# get voting district shapes
WI_voting_district_shapes <- voting_districts(state = 'WI')

# get block group shapes
WI_block_group_shapes <- block_groups(state = 'WI')

# This site has a table showing the level of data and arguments required
# https://rdrr.io/cran/acs/man/geo.make.html

#********************************
# Import data
#Import pre-cleaned Wisconsin dataset
#This dataset was accessed from the link below
#descriptions for the variables can also be found at this link
#http://www.publicmapping.org/resources/data#TOC-Election-Data
temp <- tempfile()
download.file("https://s3.amazonaws.com/redistricting_supplement_data/redist/55_redist_data.zip",temp)
WI_combined_data <- read.csv(unz(temp, "55_redist_data.csv"))
unlink(temp)



















