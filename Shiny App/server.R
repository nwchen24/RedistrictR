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
  
  map_theme = providers$CartoDB.DarkMatterNoLabels
  
  output$compactness = renderPlot({
    ggplot(solution_subset(), aes(round(compactness,2))) +
      xlab("Compactness Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank())
  },
  bg="transparent",
  execOnResize = TRUE
  )
  
  output$vote_efficiency = renderPlot({
    ggplot(solution_subset(), aes(round(vote_efficiency,2))) +
      xlab("Vote Efficiency Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank())
  },
  bg="transparent",
  execOnResize = TRUE
  )
  
  output$cluster_proximity = renderPlot({
    ggplot(solution_subset(), aes(round(cluster_proximity,2))) +
      xlab("Geographic Cluster Score") +
      geom_bar(fill=rgb(1,1,1, alpha=0.5)) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank())
  },
  bg="transparent",
  execOnResize = TRUE
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
