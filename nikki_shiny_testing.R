library(sp)
library(leaflet)
library(shiny)
library(mapview)
library(RColorBrewer)


library(scales)
library(lattice)
library(dtplyr)
library(htmltools)

# use CA spatial data
CA = CA_block_group_shapes
sd_join = merge(CA, SD_blockgroup_pop_and_voting_data, by="GEOID")


# get some colorzzz
colors = c(RColorBrewer::brewer.pal(10, 'Spectral'),RColorBrewer::brewer.pal(6, 'Dark2'))

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
                                          "Vote Efficiency" = 'efficiency',
                                          "Communities of Interest" = 'communities',
                                          "Majority Minority" = 'majmin'),
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
  
  output$map1 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                     options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                color = "#444444", weight = .3, smoothFactor = 0.5,
                opacity = 1.0, fillOpacity = 0.9,
                fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                highlightOptions = highlightOptions(color = "white", weight=1,
                                                    bringToFront = TRUE),
                label = ~htmlEscape(existing_district))
  })

  output$map2 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(existing_district))
  })
  
  output$map3 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(existing_district))
  })
  
  output$map4 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(existing_district))
  })
  
  
  output$map5 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(existing_district))
  })
  
  output$map6 = renderLeaflet({
    leaflet(options=leafletOptions(attribution=NULL)) %>%
      addProviderTiles(providers$Stamen.TonerLite,
                       options = providerTileOptions(attribution=NULL)) %>%
      addPolygons(data = sd_join[sd_join$COUNTYFP.x==input$county,],
                  color = "#444444", weight = .3, smoothFactor = 0.5,
                  opacity = 1.0, fillOpacity = 0.9,
                  fillColor = ~colorQuantile(colors[1:10], as.numeric(existing_district))(as.numeric(existing_district)),
                  highlightOptions = highlightOptions(color = "white", weight = 1,
                                                      bringToFront = TRUE),
                  label = ~htmlEscape(existing_district))
  })
  
}


# Run the app ----
shinyApp(ui = ui, server = server)

