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


# install.packages('RMySQL')
library(dplyr)
library(RMySQL)

# database connection
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


# ONE TIME SET UP: upload tables into db ('data')
# ------------------------------------------------
# setwd("~/Documents/MIDS/redistrictr")
# assignments = read.csv("./Data/assignments.csv", header=T)
# assignments$id = as.factor(assignments$id)
# assignments$solution_id = as.factor(assignments$solution_id)
# assignments$geoid = as.factor(assignments$geoid)
# assignments$assignment = as.factor(assignments$assignment)
# copy_to(my_db, assignments, temporary=F)
# 
# solutions = read.csv("./Data/solutions.csv", header=T)
# solutions$id = as.factor(solutions$id)
# solutions$target_id = as.factor(solutions$target_id)
# copy_to(my_db, solutions, temporary=F)
# 
# targets = read.csv("./Data/targets.csv", header=T)
# targets$id = as.factor(targets$id)
# copy_to(my_db, targets, temporary=F)



# function to get unique solution_id's from assignments table
getNumSol = function() {
  n = a %>% distinct(solution_id) %>% count() %>% collect()
  return(n$n)
}

# function to return dataframe of geoid and assignment given a solution_id
getAssignments = function(sol_id) {
  subset = filter(a, solution_id == sol_id) %>% collect()
  return(as.data.frame(subset[,c("geoid","assignment")]))
}




# read data from database
tables = getTables()
a = tables$assignments # assignments per solution_id
s = tables$solutions # solution_id, target_id, calculations
t = tables$targets # target_id & what is being optimized


data = merge(CA_block_group_shapes, SD_blockgroup_pop_and_voting_data_2, "GEOID")
data$GEOID = as.numeric(data$GEOID)


# get some colorzzz
colors = c(RColorBrewer::brewer.pal(5, 'Set2'))

# Define UI ----
ui <- fluidPage(

  # tags$head(tags$style("
  #     .header{background-color: pink;}"
  # )),
  
  theme=shinytheme("sandstone"),

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

# Define server logic ----
server <- function(input, output, session) {
  
  # take the solution set that is optimized for the selected optimization factor (optfactor) (100 solutions) 
  # and order by the optimization factor to get the 6 best solutions
  solution_subset = reactive({
    return(s[s$target_id==t[t[,input$optfactor]==1,"id"],][order(s[s$target_id==t[t[,input$optfactor]==1,"id"],][,input$optfactor], decreasing=T),])
    })
  
  # get the data for the county selected
  selected = reactive({
    return(data[data$COUNTYFP.x==input$county,])
  })
  
  getAssignments = reactive({
    function(sol_id) {
    subset = filter(a, solution_id == sol_id) %>% collect()
    return(as.data.frame(subset[,c("geoid","assignment")]))
    }
  })
  

  output$map1 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[1,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })

  output$map2 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[2,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })

  output$map3 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[3,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })

  output$map4 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[4,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })


  output$map5 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[5,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })

  output$map6 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = merge(selected(),
                               getAssignments()(solution_subset()[6,]$id),
                               by.x='GEOID',
                               by.y='geoid'),
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorFactor(colors, as.factor(assignment))(as.factor(assignment)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(assignment))
  })

}


# Run the app ----
shinyApp(ui = ui, server = server)

