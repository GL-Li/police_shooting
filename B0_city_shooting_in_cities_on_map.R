# This file is to explore the location of the shootings, in urbanized area, urban
# clusters or rural area. The geo-component data is from 2010 census

# last reviewed 2/9/2017

library(ggplot2)
library(ggrepel)
library(data.table)
library(ggmap)

source("A0_functions_prepare_shooting_data.R")
source("A0_functions_extract_census_data.R")
# setwd("~/Dropbox/dataset_analysis/kaggle_police_shooting_WSJ")

# count people killed in a state urban or rural map ===========================
# display a map of the state with urbanized area in pink, urban clusters in orange,
# and rural area in cyan. The location of shooting is marked with a red cycle
# and the cycle area represents number of shooting. 
city_count <- shooting_city_count("all")
geo <- get_full_geo("GA")
plot_urban_rural_on_map("Macon, GA, US", geo, 7) +
    geom_point(data = city_count, aes(lon, lat, size = count * 100000), 
               alpha = 1, color = "red", shape = 1) + 
    theme(legend.text = element_text(size = 11)) +
    labs(title = "Fatal police shooting in Georgia",
         subtitle = "Location and number of shootings are marked by open red circles")
ggsave(filename = "figures_temp/block_level_all_killed_GA_map.png", width = 8, height = 8)


# plot shooting on national map ===============================================
city_count <- shooting_city_count("all", unarmed = TRUE)

# census data at census tract level 
# CT <- fread("../us_2010_census/extracted_csv/full_geo_race_census_tract_level")
# block group level
#BG <- fread("../us_2010_census/extracted_csv/full_geo_race_block_group_level.csv")
# plot on us map
block <- fread("~/dropbox_datasets/US_2010_census/extracted_csv/full_geo_race_block_level")
us_map <- get_map(location = "Wichita", zoom = 4)
state_border <- map_data("state")

# takes a very long time to plot and save, need 6G memory to process
ggmap(us_map) +
    geom_point(data = block[!is.na(rural)], aes(lon, lat, size = rural),
               alpha = 0.7, color = "cyan", stroke = 0) +
    geom_point(data = block[!is.na(urban_cluster)], aes(lon, lat, size = urban_cluster),
               alpha = 0.7, color = "orange", stroke = 0) +  # stroke = 0 to remove circle border
    geom_point(data = block[!is.na(urban_area)], aes(lon, lat, size = urban_area),
               alpha = 0.7, color = "#DE90F5", stroke = 0) +
    geom_point(data = city_count, aes(lon, lat, size = count * 3000), 
               color = "red", shape = 1) +
    geom_polygon(data = state_border, aes(long, lat, group = group), color = "black", fill = NA) +
    scale_size_area(max_size = 5)
ggsave(filename = "figures_temp/block_level_black_killed_us_map.png", width = 12, height = 12)


# US west
us_map_west <- get_map(location = "Moore, UT", zoom = 5)
ggmap(us_map_west) +
    geom_point(data = block[!is.na(rural)], aes(lon, lat, size = rural),
               alpha = 0.7, color = "cyan", stroke = 0) +
    geom_point(data = block[!is.na(urban_cluster)], aes(lon, lat, size = urban_cluster),
               alpha = 0.7, color = "orange", stroke = 0) +  # stroke = 0 to remove circle border
    geom_point(data = block[!is.na(urban_area)], aes(lon, lat, size = urban_area),
               alpha = 0.7, color = "#DE90F5", stroke = 0) +
    geom_point(data = city_count, aes(lon, lat, size = count * 3000), 
               color = "red", shape = 1) +
    scale_size_area(max_size = 5)
ggsave(filename = "figures/BG_level_all_killed_us_west_map.png", width = 12, height = 12)

# US east
us_map_east <- get_map(location = "Sevierville, TN", zoom = 5)
ggmap(us_map_east) +
    geom_point(data = block[!is.na(rural)], aes(lon, lat, size = rural),
               alpha = 0.7, color = "cyan", stroke = 0) +
    geom_point(data = block[!is.na(urban_cluster)], aes(lon, lat, size = urban_cluster),
               alpha = 0.7, color = "orange", stroke = 0) +  # stroke = 0 to remove circle border
    geom_point(data = block[!is.na(urban_area)], aes(lon, lat, size = urban_area),
               alpha = 0.7, color = "#DE90F5", stroke = 0) +
    geom_point(data = city_count, aes(lon, lat, size = count * 3000), 
               color = "red", shape = 1) +
    scale_size_area(max_size = 5)
ggsave(filename = "figures/BG_level_all_killed_us_east_map.png", width = 12, height = 12)



