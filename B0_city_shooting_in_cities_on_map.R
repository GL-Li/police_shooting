# This file is to explore the location of the shootings, in urbanized area, urban
# clusters or rural area. The geo-component data is from 2010 census

# last reviewed 8/4/2017

library(ggplot2)
library(ggrepel)
library(data.table)
library(ggmap)

source("A0_functions_prepare_shooting_data.R")
source("A0_functions_extract_census_data.R")


plot_shooting_on_state_map <- function(state_abbr, 
                                       zoom = 7,
                                       choose_race = "*", 
                                       weapon = "*", 
                                       max_size=20){
    ## Plot location and number of shooting in the map of a state specifying
    ## urban_area, urban_cluster, and rural area. 
    ## display a map of the state with urbanized area in pink, urban clusters in 
    ## orange, and rural area in cyan. The location of shooting is marked with 
    ## a red cycle and the cycle area represents number of shooting. 
    ##
    ## args_______
    ## state_abbr: string
    ##    abbrevation of a state, such as "MA", "RI"
    ## race : string
    ##    "*" for all races, "B" for black
    ## weapon : string
    ##    weapon the victim carrying, "*" for all weapons, "unarmed", "gun", 
    ##    "knife" ...
    ## zoom : integer
    ##    zoom level of google map
    ##
    ## returns______
    ##     plot and save a figure, no return
    
    # only include cities in selected state
    city_count <- count_shooting_city(choose_race, weapon)

    # use full race name
    race <- switch(choose_race,
                   "*" = "all_races",
                   "B" = "black",
                   "W" = "white",
                   "A" = "asian")
    
    plot_title <- paste("Fatal police shooting in", 
                         cap_words_1st_letter(convert_state_names(state_abbr)))
    save_as <- paste0("figures_temp/block_level_", race, "_killed_", state_abbr, "_map.png")
    
    plot_urban_rural_on_map(state_abbr, zoom, max_size) +
        geom_point(data = city_count, aes(lon, lat, size = count * 100000), 
                   alpha = 1, color = "red", shape = 1) + 
        # mark rural and small urban shooting
        geom_point(data = city_count[urban_rural %in% c("urban_cluster", "rural")],
                   aes(lon, lat), shape = 4) +
        theme(legend.text = element_text(size = 11),
              plot.caption = element_text(color = "grey50", family = "monospace")) +
        labs(title = plot_title,
             subtitle = "Location and number of shootings are marked by open red circles.\nBlack crosses mark shootings in rural or small urban areas.",
             caption = "Soruces: Washington Post, Census 2010, and Google Map")
    ggsave(filename = save_as , width = 8, height = 8)
    print(paste("Figure saved:", save_as))
}


# plot shooting on national map ===============================================
plot_shooting_US_map <- function(choose_race = "*", weapon = "*"){
    ## plot shooting location and count on US geo-population map
    ##
    ## args______
    ## race : string
    ##    "*" for all races, "B" for black
    ## weapon : string
    ##    weapon the victim carrying, "all" weapons, "unarmed", "gun", "knife" ...
    ##
    ## returns______
    ## save a plot, no return
    
    city_count <- count_shooting_city(choose_race, weapon)
    
    # use full race name
    race <- switch(choose_race,
                   "*" = "all_races",
                   "B" = "black",
                   "W" = "white",
                   "A" = "asian")
    
    # census data at block level 
    block <- fread("~/dropbox_datasets/US_2010_census/extracted_csv/full_geo_race_block_level")
    # us map data
    us_map <- get_map(location = "Wichita", zoom = 4)    # Wichita is center of US
    state_border <- map_data("state")
    
    # takes a very long time to plot and save, need 6G memory to process
    print("Be patient. Needs 6G memory and takes a long time.")
    save_as <- paste0("figures_temp/", race, "_with_", weapon, "_killed_US_map_block_level.png")
    ggmap(us_map) +
        geom_point(data = block[!is.na(rural)], aes(lon, lat, size = rural),
                   alpha = 0.7, color = "cyan", stroke = 0) +
        geom_point(data = block[!is.na(urban_cluster)], aes(lon, lat, size = urban_cluster),
                   alpha = 0.7, color = "orange", stroke = 0) +  # stroke = 0 to remove circle border
        geom_point(data = block[!is.na(urban_area)], aes(lon, lat, size = urban_area),
                   alpha = 0.7, color = "#DE90F5", stroke = 0) +
        geom_point(data = city_count, aes(lon, lat, size = count * 3000), 
                   color = "red", shape = 1) +
        # use geom_path for state border: it does not force connecting last and 
        # first point as geom_polygon
        geom_path(data = state_border, aes(long, lat, group = group), color = "black", alpha = 0.5) +
        scale_size_area(max_size = 5)
    ggsave(filename = save_as, width = 12, height = 12)
    print(paste("Figure saved as:", save_as))
}
