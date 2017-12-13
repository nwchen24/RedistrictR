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
              solutions = tbl(my_db, "solutions"),
              targets = tbl(my_db, "targets")))
}


# get tables from rdb
tables = getTables()
a = as.data.frame(tables$assignments) # assignments per solution_id
s = as.data.frame(tables$solutions) # solution_id, target_id, calculations
t = as.data.frame(tables$targets) # target_id & what is being optimized

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
    showNotification(paste("Please give me some time to load!"), type="message", duration=2)
  })
  
  # take the solution set that is optimized for the selected optimization factor (optfactor) (100 solutions) 
  # and order by the optimization factor to get the 6 best solutions
  solution_subset = reactive({
    target = t[t[,2]== (if ("compactness" %in% input$optfactor) 1 else 0) & t[,3]== (if ("vote_efficiency" %in% input$optfactor) 1 else 0) & t[,4] == (if ("cluster_proximity" %in% input$optfactor) 1 else 0),]
    return(s[s$target_id==target$id,][order(s[s$target_id==target$id,][,"fitness"], decreasing=T),])
    print("getting solution subset")
  })
  
  # get the data for the county selected
  selected = reactive({
    return(data[data$COUNTYFP.x==input$county,])
  })
  
  getAssignments = reactive({
    function(sol_id) {
      subset = filter(a, solution_id == sol_id) %>% collect()
      return(as.data.frame(subset[,c("geoid","assignment")]))
      print('getting assignments')
    }
  })
  
  map_theme = providers$CartoDB.DarkMatterNoLabels
  
  #####################################
  ### ZOOMING IN WHEN CLICK ONE MAP ###
  #####################################
  
  observeEvent(input$map1_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({as.character(round(solution_subset()[1,]$compactness,2))})
    output$map_select_ve = renderText({as.character(round(solution_subset()[1,]$vote_efficiency,2))})
    output$map_select_cp = renderText({as.character(round(solution_subset()[1,]$cluster_proximity,2))})
    
  })
  
  observeEvent(input$map2_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({round(solution_subset()[2,]$compactness,2)})
    output$map_select_ve = renderText({round(solution_subset()[2,]$vote_efficiency,2)})
    output$map_select_cp = renderText({round(solution_subset()[2,]$cluster_proximity,2)})
  })
  
  observeEvent(input$map3_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({round(solution_subset()[3,]$compactness,2)})
    output$map_select_ve = renderText({round(solution_subset()[3,]$vote_efficiency,2)})
    output$map_select_cp = renderText({round(solution_subset()[3,]$cluster_proximity,2)})
  })
  
  observeEvent(input$map4_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({round(solution_subset()[4,]$compactness,2)})
    output$map_select_ve = renderText({round(solution_subset()[4,]$vote_efficiency,2)})
    output$map_select_cp = renderText({round(solution_subset()[4,]$cluster_proximity,2)})
  })
  
  observeEvent(input$map5_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({round(solution_subset()[5,]$compactness,2)})
    output$map_select_ve = renderText({round(solution_subset()[5,]$vote_efficiency,2)})
    output$map_select_cp = renderText({round(solution_subset()[5,]$cluster_proximity,2)})
  })
  
  observeEvent(input$map6_shape_click, {
    print("zooming")
    updateTabsetPanel(session, "redistrictR",
                      selected = "Zoom")
    output$map_select = renderLeaflet({
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
                    label = ~paste("district:", assignment))
    })
    output$map_select_c = renderText({round(solution_subset()[6,]$compactness,2)})
    output$map_select_ve = renderText({round(solution_subset()[6,]$vote_efficiency,2)})
    output$map_select_cp = renderText({round(solution_subset()[6,]$cluster_proximity,2)})
  })

  
  
  ######################################
  ## HIGHLIGHTING BARS ON LEFT CHARTS ##
  ######################################
  
  # setting colors and reactive values for color changes
  cols_base = rgb(1,1,1,alpha=0.5)
  bar_cols = reactiveValues()
  bar_cols$compactness = cols_base
  bar_cols$vote_efficiency = cols_base
  bar_cols$cluster_proximity = cols_base
  
  ############################################################
  ## HIGHLIGHT COMPACTNESS CHART BASED ON MOUSEOVER OF PLOT ##
  ############################################################
  
  observeEvent(input$map1_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[1,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  
  observeEvent(input$map2_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[2,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  
  observeEvent(input$map3_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[3,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  
  observeEvent(input$map4_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[4,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  
  observeEvent(input$map5_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[5,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  
  observeEvent(input$map6_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(compactness,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[6,]$compactness,2))
    bar_cols$compactness = rep(cols_base, nrow(sub_comp))
    bar_cols$compactness[ind] = "yellow"
    names(bar_cols$compactness) = sub_comp$c
  })
  

  #################################################################
  ## HIGHLIGHT vote_efficiency CHART BASED ON MOUSEOVER OF PLOT ###
  #################################################################
  
  observeEvent(input$map1_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[1,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  observeEvent(input$map2_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[2,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  observeEvent(input$map3_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[3,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  observeEvent(input$map4_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[4,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  observeEvent(input$map5_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[5,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  observeEvent(input$map6_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(vote_efficiency,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[6,]$vote_efficiency,2))
    bar_cols$vote_efficiency = rep(cols_base, nrow(sub_comp))
    bar_cols$vote_efficiency[ind] = "yellow"
    names(bar_cols$vote_efficiency) = sub_comp$c
  })
  
  ###################################################################
  ## HIGHLIGHT cluster_proximity CHART BASED ON MOUSEOVER OF PLOT ###
  ###################################################################
  
  observeEvent(input$map1_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[1,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  
  observeEvent(input$map2_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[2,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  
  observeEvent(input$map3_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[3,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  
  observeEvent(input$map4_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[4,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  
  observeEvent(input$map5_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[5,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  
  observeEvent(input$map6_shape_mouseover, {
    sub_comp = solution_subset() %>% group_by("c" = round(cluster_proximity,2)) %>% count()
    ind = which(sub_comp$c==round(solution_subset()[6,]$cluster_proximity,2))
    bar_cols$cluster_proximity = rep(cols_base, nrow(sub_comp))
    bar_cols$cluster_proximity[ind] = "yellow"
    names(bar_cols$cluster_proximity) = sub_comp$c
  })
  

  ##########################################
  ### RESULT DISTRIBUTIONS ON LEFT PANEL ###
  ##########################################
  
  output$compactness = renderPlotly({
    p = ggplot(solution_subset(), aes(x=round(compactness,2), text=paste(..count..,"potential maps with","<br>","compactness of",x))) +
      xlab("Compactness Score") +
      geom_bar(fill = bar_cols$compactness) +
      theme(panel.background = element_blank(),
          plot.background = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          axis.ticks = element_blank(),
          axis.title.x= element_text(color="white"),
          axis.text.x = element_text(color="white"),
          axis.title.y = element_blank(),
          axis.text.y = element_blank(),
          legend.position="none") +
      geom_vline(xintercept = 0.251689, col="#98282890")
    
    p$elementId <- NULL

    ggplotly(p, tooltip = c("text")) %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
    }
  )
  
  
  output$vote_efficiency = renderPlotly({
    p = ggplot(solution_subset(), aes(round(vote_efficiency,2), text=paste(..count..,"potential maps with","<br>","vote efficiency score of",x))) +
      xlab("Vote Efficiency Score") +
      geom_bar(fill=bar_cols$vote_efficiency) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank(),
            legend.position="none") +
      geom_vline(xintercept = 0.92414, col="#98282890")

    p$elementId <- NULL
    
    ggplotly(p, tooltip="text") %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
  }
  )
  
  output$cluster_proximity = renderPlotly({
    p = ggplot(solution_subset(), aes(round(cluster_proximity,2), text=paste(..count..,"potential maps with","<br>","cluster proximity score of",x))) +
      xlab("Geographic Cluster Score") +
      geom_bar(fill=bar_cols$cluster_proximity) + 
      theme(panel.background = element_blank(),
            plot.background = element_blank(),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x= element_text(color="white"),
            axis.text.x = element_text(color="white"),
            axis.title.y = element_blank(),
            axis.text.y = element_blank(),
            legend.position="none") +
      geom_vline(xintercept = 0.4962796, col="#98282890")
    
    p$elementId <- NULL
    
    ggplotly(p, tooltip="text") %>% config(displayModeBar = F) %>%
      layout(plot_bgcolor='transparent') %>%
      layout(paper_bgcolor='transparent')
  }
  )
  
  
  ###################################
  ### LEAFLET MAPS ON RIGHT PANEL ###
  ###################################
  
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
                  label = ~paste("district:", assignment))
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
                  label = ~paste("district:", assignment))
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
                  label = ~paste("district:", assignment))
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
                  label = ~paste("district:", assignment))
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
                  label = ~paste("district:", assignment))
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
                  label = ~paste("district:", assignment))
  })

  
}
