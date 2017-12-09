#                 __ _      __        _       __      
#   ____ ___  ___/ /(_)___ / /_ ____ (_)____ / /_ ____
#  / __// -_)/ _  // /(_-</ __// __// // __// __// __/
# /_/   \__/ \_,_//_//___/\__//_/  /_/ \__/ \__//_/   
#              
# redistrictR: a project for fairness in redistricting
# by Joe Izenman, Nicholas Chen, Nicole Lee

# -------------------------------------------------- #
# ------------- S E R V E R   S I D E -------------- #
# -------------------------------------------------- #


# rsconnect::deployApp("./Documents/MIDS/redistrictr/Shiny App/")

# install devtools version of ggplot2
# devtools::install_github('hadley/ggplot2')

library(sp)
library(leaflet)
library(shiny)
library(shinythemes)
library(mapview)
library(RColorBrewer)
library(plotly)

library(scales)
library(lattice)
library(dtplyr)
library(dbplyr)
library(htmltools)

library(dplyr)
library(RMySQL)
library(ggplot2)



# define function for grabbing tables from rdb
getTables = function(host="redistrictr.cdm5j7ydnstx.us-east-1.rds.amazonaws.com",
                     port=3306,
                     dbname="data",
                     user="master",
                     password="redistrictr") {
  my_db = src_mysql(dbname=dbname,host=host,port=port,user=user,password=password)
  # src_tbls(my_db)
  
  # read tables
  return(list(assignments = tbl(my_db, "assignments"),
              solutions = as.data.frame(tbl(my_db, "solutions")),
              targets = as.data.frame(tbl(my_db, "targets"))))
}


# get tables from rdb
tables = getTables()
a = tables$assignments # assignments per solution_id
s = tables$solutions # solution_id, target_id, calculations
t = tables$targets # target_id & what is being optimized

# get base data
load("./SD_all_data.RData")
data = merge(SD_block_group_shapes, SD_blockgroup_pop_and_voting_data_2, "GEOID", all.x=FALSE)
data$GEOID = as.numeric(data$GEOID)


server <- function(input, output, session) {
  
  # change tab to application when start button is clicked
  observeEvent(input$start, {
    print("clicked")
    updateTabsetPanel(session, "redistrictR",
                     selected = "Application")
  })
  
  # take the solution set that is optimized for the selected optimization factor (optfactor) (100 solutions) 
  # and order by the optimization factor to get the 6 best solutions
  solution_subset = reactive({
    target = t[t[,2]== (if ("compactness" %in% input$optfactor) 1 else 0) & t[,3]== (if ("vote_efficiency" %in% input$optfactor) 1 else 0) & t[,4] == (if ("cluster_proximity" %in% input$optfactor) 1 else 0),]
    return(s[s$target_id==target$id,][order(s[s$target_id==target$id,][,"fitness"], decreasing=T),])
    
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
  
  map_theme = providers$CartoDB.DarkMatterNoLabels
  
  output$compactness = renderPlotly({
    p = ggplot(solution_subset(), aes(round(compactness,2))) +
      xlab("Compactness Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) +
      theme(panel.background = element_blank(),
          plot.background = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.ticks = element_blank(),
          axis.title.x= element_text(color="white"),
          axis.text.x = element_text(color="white"),
          axis.title.y = element_blank(),
          axis.text.y = element_blank())
    
    p = style(p, hoverinfo="x+y")
    
    ggplotly(p) %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
  
  }
  )
  
  
  output$vote_efficiency = renderPlotly({
    p = ggplot(solution_subset(), aes(round(vote_efficiency,2))) +
      xlab("Vote Efficiency Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank())
    
    p = style(p, hoverinfo="x+y")
    
    ggplotly(p) %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
  }
  )
  
  output$cluster_proximity = renderPlotly({
    p = ggplot(solution_subset(), aes(round(cluster_proximity,2))) +
      xlab("Geographic Cluster Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank())
    
    p = style(p, hoverinfo="x+y")
    
    ggplotly(p) %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
  }
  )
  
  
  output$map1 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(map_theme,
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
      addProviderTiles(map_theme,
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
      addProviderTiles(map_theme,
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
      addProviderTiles(map_theme,
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
      addProviderTiles(map_theme,
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
      addProviderTiles(map_theme,
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
