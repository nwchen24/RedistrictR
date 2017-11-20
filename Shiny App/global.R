#                 __ _      __        _       __      
#   ____ ___  ___/ /(_)___ / /_ ____ (_)____ / /_ ____
#  / __// -_)/ _  // /(_-</ __// __// // __// __// __/
# /_/   \__/ \_,_//_//___/\__//_/  /_/ \__/ \__//_/   
#              
# redistrictR: a project for fairness in redistricting
# by Joe Izenman, Nicholas Chen, Nicole Lee

# -------------------------------------------------- #
# ---------- U S E R   I N T E R F A C E ----------- #
# -------------------------------------------------- #

library(sp)
library(leaflet)
library(shiny)
library(shinythemes)
library(mapview)
library(RColorBrewer)

library(scales)
library(lattice)
library(dtplyr)
library(htmltools)

library(dplyr)
library(RMySQL)


# define function for grabbing tables from rdb
getTables = function(host="redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com",
                     port=3306,
                     dbname="data",
                     user="master",
                     password="redistrictr") {
  my_db = src_mysql(dbname=dbname,host=host,port=port,user=user,password=password)
  # src_tbls(my_db)
  
  # read tables
  return(list(assignments = as.data.frame(tbl(my_db, "assignments")),
              solutions = as.data.frame(tbl(my_db, "solutions")),
              targets = as.data.frame(tbl(my_db, "targets"))))
  }


# get tables from rdb
tables = getTables()
a = tables$assignments # assignments per solution_id
s = tables$solutions # solution_id, target_id, calculations
t = tables$targets # target_id & what is being optimized

# get base data
load("SD_blockgroup_pop_voting_and_shapes.RData")
data = merge(CA_block_group_shapes, SD_blockgroup_pop_and_voting_data_2, "GEOID")
data$GEOID = as.numeric(data$GEOID)

# define some colors for the districts
colors = c("navajowhite3","lightsteelblue3","darkslategray4","rosybrown1","navajowhite4")

