# add lat, lon, urban-rural columns to database and save the new database as csv 
# file for all future use

library(data.table)
library(magrittr)

source("A0_functions_extract_census_data.R")
source("A0_functions_prepare_shooting_data.R")

improve_database <- function(){
    # add lon and lat data
    shooting <- fread("downloaded_data/database.csv") %>%
        # avoid the same city name in different state by adding state name
        .[, city_state := paste0(city, ", ", state)] %>%
        .[, city := NULL] %>%
        # join lat and lon to each city
        city_lon_lat()[., on = .(city_state)] 
    
    # determing urban or rural area
    # To save time, do it state by state so that only need to read state census data
    # for one time
    for (stt in unique(shooting[, state])) {
        shooting[state == stt, urban_rural := identify_area(lat, lon, stt)]
    }  
    
    write.csv(shooting, file = "downloaded_data/database_improved.csv", row.names = FALSE)
}

improve_database()

