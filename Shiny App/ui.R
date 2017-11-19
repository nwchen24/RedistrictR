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


# start page
fluidPage(
  
  theme=shinytheme("slate"),
  
  navbarPage(
    "redistrictR",
    
    tabPanel("Application",
             fluidRow(
               # class = "header",
               column(width=2,
                      h3("County:")),
               column(width=3,
                      selectInput(inputId = "county",
                                  choices = list("San Diego" = '073',
                                                 "Los Angeles" = '037'),
                                  label = "",
                                  selected = '073')),
               column(width=4,
                      h3("Optimize districts on:")),
               column(width=3,
                      selectInput("optfactor",
                                  choices = list("Compactness" = 'compactness',
                                                 "Vote Efficiency" = 'vote_efficiency',
                                                 "Communities of Interest" = 'communities',
                                                 "Geographic Cluster" = 'cluster_proximity'),
                                  label = "",
                                  selected = 'compactness'))
             ),
             
             br(),br(),
             
             fluidRow(
               column(width=4,
                      h3("Results"),
                      strong("Contiguity"), hr(), br(),br(),
                      strong("Compactness"), hr(), br(),br(),
                      strong("Vote Efficiency"), hr(), br(),br(),
                      strong("Majoriy Minority")),
               
               column(width=8,
                      h3("Most Optimal District Maps"),
                      fluidRow(
                        column(width=4,
                               leafletOutput("map1", width="100%", height=200),
                               br()),
                        column(width=4,
                               leafletOutput("map2", width="100%", height=200),
                               br()),
                        column(width=4,
                               leafletOutput("map3", width="100%", height=200),
                               br())
                      ),
                      
                      fluidRow(
                        column(width=4,
                               leafletOutput("map4", width="100%", height=200)),
                        column(width=4,
                               leafletOutput("map5", width="100%", height=200)),
                        column(width=4,
                               leafletOutput("map6", width="100%", height=200))
                      )
               )
             )),
    
    
    tabPanel("About",
             h5("redistrictR is a project by Joe Izenman, Nick Chen, and Nikki Lee")),
    
    
    tabPanel("Feedback",
             h5("coming soon"))
    
    
  )
  )