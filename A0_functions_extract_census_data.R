# This file define functions to extract 2010 census data and save them to csv files.
# Last reviewed 4/29/2017

# The 2010 census data, with urban and rural update, were downloaded from
# http://www2.census.gov/census_2010/04-Summary_File_1/Urban_Rural_Update/ 
# For each state the data were unzipped to its own folder named with its 
# abbreviation, for example, "MA" for Massachusetts. Under this folder there are
# ma000012010.ur1, ma000022010.ur1, ..., ma000482010.ur1, and mageo2010.ur1 files.

library(data.table)
library(magrittr)
library(ggmap)


# define functions ============================================================
get_full_geo_race <- function(state_abbr_vector, zero_to_NA = TRUE,
                              read_geo = TRUE, read_race = TRUE) {
    # This function get the full census data of urban and rural population, and 
    # races. Keep all rows in the summary data file. The return just add columns
    # of races to that of get_full_geo(). Keep it as a seperate function.
    
    # args___________
    # state_abbr_vector : string vector
    #     vector of state abbriviations such as c("MA", "RI")
    # zero_to_NA : logical
    #     option to convert numbers zero to NA to reduce the plot point
    # read_geo : logical
    #     weather to read population in geo-component, such as urban and rural
    # read_race : logical
    #     weather to read race population
    
    # return_________
    # a data.table of population in the state vector
    
    population_list <- list()
    for (state_abbr in state_abbr_vector) {
        print(state_abbr)
        # setup file path, change according to the location of downloaded 2010
        # census data
        folder <- paste0("~/dropbox_datasets/US_2010_census/", state_abbr, "/")
        geofile <- paste0(folder, tolower(state_abbr), "geo2010.ur1")
        f02file <- paste0(folder, tolower(state_abbr), "000022010.ur1")
        f03file <- paste0(folder, tolower(state_abbr), "000032010.ur1")
        
        # read data
        print("read geofile")
        geo_code <- fread(geofile, sep = "\n", header = FALSE)
        # replace unicodes in geofile of these state 
        if (state_abbr %in% c("US", "TX", "NM", "CA", "AZ", "CO")) {
            geo_code[, V1 := gsub("[\xf1\xe1\xe9\xed\xfc\xf3\xfa]", "9", V1)]
        }
        
        # extract data
        population <- geo_code[, .(state = state_abbr,
                              level_code = substr(V1, 9, 11),
                              geo_component = substr(V1, 12, 13),
                              lat = as.numeric(substr(V1, 337, 347)),
                              lon = as.numeric(substr(V1, 348, 359)))] 
        if (read_geo){
            print("read f02file")
            f02 <- fread(f02file, header = FALSE)
            population[, total := f02[, V6]] %>%
                .[, urban := f02[, V7]] %>%
                .[, urban_area := f02[, V8]] %>%
                .[, urban_cluster := f02[, V9]] %>%
                .[, rural := f02[, V10]]
        }
        if (read_race){
            print("read f03file")
            f03 <- fread(f03file, header = FALSE)
            population[, white := f03[, V7]] %>%
                .[, black := f03[, V8]] %>%
                .[, asian := f03[, V10]]
        }
        
        # convert zero to NA
        if (zero_to_NA) {
            # the method is copied from Edit2 of the answer by Matt Dowle at
            # http://stackoverflow.com/questions/7235657/fastest-way-to-replace-nas-in-a-large-data-table
            for (i in seq_along(population)) {
                set(population, i = which(population[[i]] == 0), j = i, value = NA)
            }
        }
        
        population_list[[state_abbr]] <- population
    }
    rbindlist(population_list)
}


plot_urban_rural_on_map <- function(state_abbr, state_full_geo, zoom = 7) {
    # This function plot urbanized area, urban clusters, and rural area at block
    # level of a state on google map
    # Require internet connection to download google map
    
    # args_______
    # state_abbr: abbreviation of a state, such as "MA" and "FL"
    # state_full_geo: the data.table obtained from function 
    #     get_full_geo_race(read_race = FALSE). This
    #     function runs a long time. So get it done outside of the 
    #     plot_urban_rural_on_map function.
    # zoom: zoom when using get_map() to download map data. Adjust accordingly.
    
    # returns_____
    # no return but make a plot
    
    block <- state_full_geo %>%
        .[level_code == "100"] %>%     # level code for block is "100" instead of 101
        .[, .(lat, lon, urban_area, urban_cluster, rural)] 
    
    map <- get_map(location = state_abbr, zoom = zoom)  # using ggmap package
    ggmap(map) +         
        # make sure urban_area is the top layer and rural at bottom
        geom_point(data = block[!is.na(rural)], 
                   aes(lon, lat, size = rural, color = "rural area"),
                   alpha = 0.3) +
        geom_point(data = block[!is.na(urban_cluster)], 
                   aes(lon, lat, size = urban_cluster, color = "small urban area"),
                   alpha = 0.3) +
        geom_point(data = block[!is.na(urban_area)], 
                   aes(lon, lat, size = urban_area, color = "large urban area"),
                   alpha = 0.3) +    # darker than pink
        scale_color_manual("",
                           breaks = c("large urban area",  # order keys in legend
                                      "small urban area",
                                      "rural area"),
                           values = c("large urban area" = "#DE90F5",
                                      "small urban area" = "orange",
                                      "rural area" = "cyan")) +
        theme(legend.position = "top",
              legend.text = element_text(size = 20),
              axis.title = element_blank(),
              axis.text = element_blank(),
              axis.ticks = element_blank()) +
        scale_size_area(max_size = 20) + 
        # override and fix legend key sizes
        guides(size = FALSE, color = guide_legend(override.aes = list(size=5)))
}


get_total_geo_population <- function(geo_comp = "all_geo") {
    # This function extract the total population in specified geocomponent such as
    # all geo, urban, urbanized area, urban cluster, and rural area.
    # The total population in the geocomponent is further grouped into population 
    # in urban/rural area if applicable, as well as population of different races.
    
    # takes less than 1 sec to run
    
    # args___________
    # geo_comp: geocomponent taking values from "all_geo", "urban", "UA" for urbanized
    #      area, "UC" for urban cluster, and "rural"
    
    # return_________
    # data.table of total population in 50 states and DC
    
    geo_code <- c("00", "01", "04", "28", "43")
    names(geo_code) <- c("all_geo", "urban", "UA", "UC", "rural")
    
    state_abbr_vector <- c("DC", "MS", "LA", "GA", "MD", "SC", "AL", "NC",
                           "DE", "VA", "TN", "FL", "AR", "NY", "IL", "NJ",
                           "MI", "OH", "TX", "MO", "PA", "CT", "IN", "NV",
                           "KY", "MA", "OK", "RI", "CA", "KS", "WI", "MN",
                           "NE", "CO", "AK", "AZ", "WA", "WV", "HI", "NM",
                           "IA", "OR", "WY", "UT", "NH", "SD", "ND", "ME",
                           "ID", "VT", "MT")

    total_list <- list()
    for (state_abbr in state_abbr_vector) {
        # print(state_abbr)
        # setup file path
        folder <- paste0("~/dropbox_datasets/US_2010_census/", state_abbr, "/")
        geofile <- paste0(folder, tolower(state_abbr), "geo2010.ur1")
        f02file <- paste0(folder, tolower(state_abbr), "000022010.ur1")
        f03file <- paste0(folder, tolower(state_abbr), "000032010.ur1")
        
        # read data
        # fread check whole data file before read. when just read a few lines,
        # fread is actually much slower than read.csv
        geo <- setDT(read.csv(geofile, sep = "\n", header = FALSE, nrows = 5))
        f02 <- setDT(read.csv(f02file, header = FALSE, nrows = 5))
        f03 <- setDT(read.csv(f03file, header = FALSE, nrows = 5))

        # extract data
        population <- geo[, .(state = state_abbr,
                              level_code = substr(V1, 9, 11), 
                              geo_component = substr(V1, 12, 13),
                              lat = as.numeric(substr(V1, 337, 347)),
                              lon = as.numeric(substr(V1, 348, 359)))] %>%
            .[, total := f02[, V6]] %>%
            .[, urban := f02[, V7]] %>%
            .[, urban_area := f02[, V8]] %>%
            .[, urban_cluster := f02[, V9]] %>%
            .[, rural := f02[, V10]] %>%
            .[, white := f03[, V7]] %>%
            .[, black := f03[, V8]] %>%
            .[, asian := f03[, V10]] %>%
            .[level_code == "040" & geo_component == geo_code[geo_comp]]
        total_list[[state_abbr]] <- population
    }
    rbindlist(total_list)
}



# write data to csv ===========================================================
# all_state <- c("DC", "MS", "LA", "GA", "MD", "SC", "AL", "NC", 
#                "DE", "VA", "TN", "FL", "AR", "NY", "IL", "NJ", 
#                "MI", "OH", "TX", "MO", "PA", "CT", "IN", "NV", 
#                "KY", "MA", "OK", "RI", "CA", "KS", "WI", "MN", 
#                "NE", "CO", "AK", "AZ", "WA", "WV", "HI", "NM", 
#                "IA", "OR", "WY", "UT", "NH", "SD", "ND", "ME",
#                "ID", "VT", "MT")
# 
# full_geo_race <- get_full_geo_race(all_state)
# write.csv(full_geo_race, file = "extracted_csv/full_geo_race_all_state.csv", 
#           row.names = FALSE)
