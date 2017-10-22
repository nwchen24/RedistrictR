#Program name - San Diego Spatial Join 1.0
#Get the districts that each block group falls within
#Date - October 21, 2017
#Author - Nick Chen

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

load("SAC_LA_SD_blockgroup_pop_voting_and_shapes.RData")

#import districts shape file downloaded from here:
#http://rdw.sandag.org/Account/gisdtview?dir=District
supervisor_boundaries <- readOGR(dsn = "./San_Diego/Supervisor_Districts/", layer = "Supervisor_Districts")


#Map census block groups to existing board of supervisor districts
#If a census block group's centroid falls within the boundaries of an existing district, we will assign that block group to that district
#This tutorial helped
#http://www.nickeubank.com/wp-content/uploads/2015/10/RGIS2_MergingSpatialData_part1_Joins.html

#Get centroids of census block groups
CA_blockgroup_centroids <- coordinates(CA_block_group_shapes)

#create spatial points dataframe from the centroids
CA_blockgroup_centroids <- SpatialPointsDataFrame(coords=CA_blockgroup_centroids, data=CA_block_group_shapes@data, 
                                                  proj4string=CRS("+proj=longlat +ellps=clrk66"))

#Look at the projections of the two spatial dataframes we want to merge
CA_blockgroup_centroids@proj4string
CA_block_group_shapes@proj4string
supervisor_boundaries@proj4string

#Reproject the supervisor boundaries to the same CRS (Coordinate Reference System) as the blockgroup centroids
common.crs <- CRS(proj4string(CA_blockgroup_centroids))
supervisor_boundaries.reprojected <- spTransform(supervisor_boundaries, common.crs)

supervisor_boundaries.reprojected@proj4string

#use the over command from the sp library to find out which supervisor districts each block group centroid falls within
blockgroup_districts <- over(CA_blockgroup_centroids, supervisor_boundaries.reprojected)

#Merge these districts back with the blockgroup centroids
CA_blockgroup_centroids <- spCbind(CA_blockgroup_centroids, blockgroup_districts)

CA_block_group_shapes_2 <- spCbind(CA_block_group_shapes, blockgroup_districts$DISTNO)

#limit blockgroup shapes to San Diego county
SD_blockgroup_shapes <- CA_block_group_shapes_2[!is.na(CA_block_group_shapes_2$blockgroup_districts.DISTNO),]

#Merge district with the SD blockgroup data
SD_blockgroup_pop_and_voting_data_2 <- merge(SD_blockgroup_pop_and_voting_data,
                                             SD_blockgroup_shapes[,c("GEOID", "blockgroup_districts.DISTNO")])


#rename the district column
names(SD_blockgroup_pop_and_voting_data_2)[16] <- "existing_district"

#Save
save(CA_block_group_shapes,
     SD_blockgroup_pop_and_voting_data_2,
     file = "SD_blockgroup_pop_voting_and_shapes.RData")













