library(geosphere)
library(rgeos)
library(sp)
library(raster)
library(Matrix)

# Functions
get_adjacency <- function(shapes) {
  n <- length(shapes)
  adj_list <- rgeos::gTouches(shapes, byid=TRUE, returnDense=FALSE)
  adjacency <- Matrix(FALSE, nrow=n, ncol=n)
  edges <- Matrix(0, nrow=n, ncol=n)
  
  for(i in 1:n) {
    neighbors <- adj_list[[i]]
    for(j in neighbors) {
      pair <- shapes[c(i, j),]
      both_perim <- sum(pair@data$perimeter)
      joint_perim <- geosphere::perimeter(maptools::unionSpatialPolygons(pair, c(1, 1)))
      edge <- (both_perim - joint_perim) / 2
      if(edge < 0.5) { edge <- 0 }
      edges[i, j] <- edge
      edges[j, i] <- edge
      adjacency[i, j] <- TRUE
      adjacency[j, i] <- TRUE
    }
  }
  
  return(list("adjacency"=adjacency, "edges"=edges))
}

# Load Nick's Data
load("data/SD_blockgroup_pop_voting_w_clusters.RData")

# Filter shapes list to match
SD_blockgroup_shapes <- CA_block_group_shapes[CA_block_group_shapes@data$GEOID %in% SD_blockgroup_pop_and_voting_data$GEOID,]
SD_blockgroup_shapes <- SD_blockgroup_shapes[order(SD_blockgroup_shapes@data$GEOID),]

# Add base area and perimeter measures
SD_blockgroup_pop_and_voting_data$area <- geosphere::areaPolygon(SD_blockgroup_shapes)
SD_blockgroup_pop_and_voting_data$perimeter <- geosphere::perimeter(SD_blockgroup_shapes)
SD_blockgroup_shapes@data$perimeter <- SD_blockgroup_pop_and_voting_data$perimeter

# Adjacency (pairwise boolean) and edge list (pairwise shared edge length)
SD_adjacency <- get_adjacency(SD_blockgroup_shapes)

# Add outer_edge measure: 
SD_blockgroup_pop_and_voting_data$outer_edge <- SD_blockgroup_pop_and_voting_data$perimeter - Matrix::colSums(SD_adjacency$edges)
SD_blockgroup_pop_and_voting_data[SD_blockgroup_pop_and_voting_data$outer_edge < 0.00001,"outer_edge"] <- 0

write.csv(SD_blockgroup_pop_and_voting_data, "data/SD_data.csv")
Matrix::writeMM(SD_adjacency$adjacency, "data/SD_adjacency.mtx")
Matrix::writeMM(SD_adjacency$edges, "data/SD_edges.mtx")

test_solution <- read.csv("data/initial.csv", header=FALSE)
test_solution_shapes <- maptools::unionSpatialPolygons(SD_blockgroup_shapes, test_solution$V1)
plot(test_solution_shapes, col=c('#7fc97f','#beaed4','#fdc086','#ffff99','#386cb0'), border=NA)

test_solution <- read.csv("data/mutate.csv", header=FALSE)
test_solution_shapes <- maptools::unionSpatialPolygons(SD_blockgroup_shapes, test_solution$V1)
plot(test_solution_shapes, col=c('#7fc97f','#beaed4','#fdc086','#ffff99','#386cb0'), border=NA)




test_solution <- read.csv("data/i5.csv", header=FALSE)
test_solution_shapes <- maptools::unionSpatialPolygons(SD_blockgroup_shapes, test_solution$V1)
plot(test_solution_shapes, col=c('#7fc97f','#beaed4','#fdc086','#ffff99','#386cb0'), border=NA)
