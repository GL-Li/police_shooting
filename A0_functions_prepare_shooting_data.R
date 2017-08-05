# This file defines functions for preparing Washington Post fatal police shooting data.
# Last reviewed 8/4/2017


library(data.table)
library(magrittr)
library(ggmap)
library(geosphere)
library(stringr)

# load function to extract census data
source("A0_functions_extract_census_data.R")

# define helper and geological functions =================================================
cap_words_1st_letter <- function(words) {
    ## This function capitalizes first letter of each words and keep all other  
    ## letters lower, for example, "rHode isLand" to "Rhode Island"
    ##
    ## modified from http://stackoverflow.com/questions/6364783/capitalize-the-first-letter-of-both-words-in-a-two-word-string
    ##
    ## args______
    ## words : string vector
    ##
    ## returns______
    ## Same words string with capitalized first letter of each words
    ##
    ## example______
    ## cap_words_1st_letter("rHode isLand")

    gsub("(^|[[:space:]])([[:alpha:]])", "\\1\\U\\2", tolower(words), perl=TRUE)
}

convert_state_names <- function(state_names) {
    ## This function converts state names between lower case and abbriavation
    ##
    ## args_______________
    ## state_names: string
    ##    vector of state names in standard name or abbrevation, for example,
    ##    "New York", "new york", "NY"
    ##
    ## return____________
    ## a named vector of converted state names
    ##
    ## example__________
    ## convert_state_names(c("RI", "MA"))
    
    abbr <- c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", 
              "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", 
              "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", 
              "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", 
              "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY")
    low <- c("alabama", "alaska", "arizona", "arkansas", "california", "colorado", 
             "connecticut", "delaware", "district of columbia", "florida", 
             "georgia","hawaii", "idaho", "illinois", "indiana", "iowa", "kansas", 
             "kentucky", "louisiana", "maine", "maryland", "massachusetts", 
             "michigan", "minnesota", "mississippi", "missouri", "montana", 
             "nebraska", "nevada", "new hampshire", "new jersey", "new mexico", 
             "new york", "north carolina", "north dakota", "ohio", "oklahoma", 
             "oregon", "pennsylvania", "rhode island", "south carolina", 
             "south dakota", "tennessee", "texas", "utah", "vermont", 
             "virginia", "washington", "west virginia", "wisconsin", "wyoming")
    
    # make sure input state names are standard
    stopifnot(all(state_names %in% abbr | all(tolower(state_names) %in% low)))
    
    # determine converting from what and to what
    if (all(nchar(state_names) == 2)){
        from = "abbr"
        to = "low"
    } else {
        state_names <- tolower(state_names) # handle big letters
        from = "low"
        to = "abbr"
    }
    
    # make a lookup table to convert between lowercase and abbrivation state names
    convert_to <- get(to)
    names(convert_to) <- get(from)
    
    # return results
    convert_to[state_names]
}

state_center_lon_lat <- function(){
    ## this function returns the coordinate of the center of each state so that we
    ## can plot something at the center instead of fill the whole map. 
    ## Data were downloaded with ggmap::geocoding and then fine tuned.
    ## do NOT change or update numbers
    
    state_center_coord <- data.table(
        state = c("DC", "MS", "LA", "GA", "MD", "SC", "AL", "NC", 
                  "DE", "VA", "TN", "FL", "AR", "NY", "IL", "NJ", 
                  "MI", "OH", "TX", "MO", "PA", "CT", "IN", "NV", 
                  "KY", "MA", "OK", "RI", "CA", "KS", "WI", "MN", 
                  "NE", "CO", "AK", "AZ", "WA", "WV", "HI", "NM", 
                  "IA", "OR", "WY", "UT", "NH", "SD", "ND", "ME", 
                  "ID", "VT", "MT"),
        lon = c(-77,     -89.6,   -92.46,   -83.3,   -76.6,   -80.76,  -86.7,  -78.82, 
                -75.4,   -78.66,   -86.58,  -81.52,  -92.53,  -74.72,  -89.3,  -74.41, 
                -84.6,   -82.91,   -99.4,   -92.53,  -77.69,  -72.5,   -86.13, -116.92, 
                -84.47,  -72,      -97.09,  -71.5,   -119.42, -98.48,  -89.79, -94.69, 
                -99.9,   -105.78,  -117,    -111.59, -120.44, -80.85,  -105.5, -105.87, 
                -93.4,   -120.55,  -107.49, -111.59, -71.57,  -100.22, -100.6, -69.25, 
                -114.74, -72.58,   -109.36),
        lat = c(38.9,  32.75, 30.98, 32.47, 39.3,  33.84, 32.92, 35.66, 
                38.9,  37.43, 35.72, 27.66, 35.2,  43.3,  40.63, 40.06, 
                44.31, 40.42, 31.97, 38.46, 41,    41.6,  40.27, 39.8, 
                37.74, 42.4,  35.31, 41.7,  36.78, 38.61, 44.78, 46.73, 
                41.49, 39.15, 30,    34.35, 47.72, 38.6,  26,    34.52, 
                41.88, 43.8,  43.08, 39.32, 43.39, 44.37, 47.55, 45.35, 
                44.07, 44.36, 46.88)
    )
}


city_lon_lat <- function() {
    ## This function return the longitude and latitude of cities where police 
    ## shooting death occured
    
    # downloading city coordinates takes a long time. save the download to local 
    # computer as a csv file. When update, only download new cities that are not
    # previously downloaded
    if (!file.exists("downloaded_data/city_coord.csv")) {
        # keep only location information from raw data
        cities <- fread("downloaded_data/database.csv") %>%
            .[, paste0(city, ", ", state)] %>%
            unique()
        
        # need more complete address for geocode to avoid confusion
        geo_cities <- fread("downloaded_data/database.csv") %>%
            .[, paste0(city, ", ", convert_state_names(state, "abbr", "low"), " ,USA")] %>%
            unique()
        
        city_coord <- data.table(geocode(geo_cities)) # no duplicate
        city_coord[["city_state"]] <- cities
        write.csv(city_coord, file = "downloaded_data/city_coord.csv", row.names = FALSE)
    } else {
        # check for new cities
        all_cities <- fread("downloaded_data/database.csv") %>%
            .[, .(city_state = paste0(city, ", ", state))] %>%
            .[, unique(city_state)]
        prev_cities <- fread("downloaded_data/city_coord.csv") %>%
            .[, city_state]
        new_cities <- setdiff(all_cities, prev_cities)
        
        # download coordinates for new cities and combined with previous ones
        if (length(new_cities) > 0){
            new_geo_cities <- paste0(str_replace(new_cities, "..$", ""),
                                     convert_state_names(str_extract(new_cities, "..$"), "abbr", "low"),
                                     ", USA")
            new_coord <- data.table(geocode(new_geo_cities))
            new_coord[["city_state"]] <- new_cities
            all_coord <- rbindlist(list(fread("downloaded_data/city_coord.csv"), new_coord))
            write.csv(all_coord, file = "downloaded_data/city_coord.csv", row.names = FALSE)
        }
    }
    city_coord <- fread("downloaded_data/city_coord.csv") %>%
        # this city points to another location, correct it manually
        # tried again on 8/4/2017, this time geocode() gives correct result.
        # keep the code below anyway
        .[city_state == "Rockville, GA", ":=" (lon = -83.21877, lat = 33.32764)]
}


identify_area <- function(latitude, longitude, state) {
    ## This function identifies locations at (latitude, longitude) as urban areas,
    ## urban clusters, or rural areas.
    ##
    ## args______________________
    ## latitude, longitude : numeric 
    ##     vectors of latitude and longitude of the locations
    ## state : string
    ##     abbriation of the state where the location is in, for example "MA", "CA"
    ##
    ## return____________________
    ## area_name : character
    ##     vector of area name as one of "urban_area", "urban_cluster",
    ##     "rural"
    ##
    ## exmple________________
    ## identify_area(33.32764, -83.21877, "GA")
    
    # get census data at block level
    block <- get_full_geo_race(state, read_race = FALSE) %>%
        .[level_code == "100"] %>%     # level code for block is "100" instead of 101
        .[, .(lat, lon, urban_area, urban_cluster, rural)] %>%
        setkey(lat, lon)
    
    # place holder for the return area names
    area_name <- rep(NA, length(latitude))
    
    for (i in seq_along(latitude)) {
        if (mod(i, 100) == 0) print(i)
        lati <- latitude[i]
        longi <- longitude[i]
        
        # draw a box arround the location. If no blocks found, expand the box
        for (j in c(0.1, 1, 3, 6, 10, 15, 20, 50, 100)) {
            dif <- j * 0.01
            selected <- block[abs(lat - lati) + abs(lon - longi) < dif] %>%
                # the selected blocks must also have people living in
                .[is.na(urban_area) + is.na(urban_cluster) + is.na(rural) != 3]
            if (nrow(selected) > 0) break
        }
        
        # geocoding of city very occasionally downloads wrong coordinate, skip 
        # this mistake
        if (nrow(selected) == 0) {
            area_name[i] <- NA
        } else {
            # find the nearest block to the location and find which area it is called
            area_name[i] <- selected %>%
                # add column showing distance to c(lati, longi), 
                # distm() work for matrix and vectors, not good for columns
                .[, dist := distm(c(longi, lati), as.matrix(.[,.(lon, lat)]))[1,]] %>%
                # find the row with minimun distance, keep only areas
                .[dist == min(dist), .(urban_area, urban_cluster, rural)] %>%
                # keep the area with non-zero population
                colSums() %>%
                which.max() %>%
                names()
        }
    }
    return(area_name)
}

# prepare shooting data =======================================================

read_shooting_data <- function(choose_race = "*", weapon = "*", geo_comp = "*") {
    ## read shooting data of selected race, weapon, and geo-component
    ##
    ## args_______
    ## choose_race: string
    ##    race of the victim, takes values of "W", "B", "H", "A", ...,
    ##    default "*" for all races
    ## weapon: string
    ##    weapon the victim was carrying when being shot, "unarmed", "gun", 
    ##    "knife", ..., default "*" for all weapons
    ## geo_comp: string
    ##    take values "urban_area", "urban_cluster", and "rural". default "*" 
    ##    for all geo-components
    ##
    ## returns_____
    ## data.table of improved shooting database
    
    shooting <- fread("downloaded_data/database_improved.csv") %>%
        # %like% is so cool, usage: vector %like% pattern
        .[race %like% choose_race] %>% 
        .[armed %like% weapon] %>%
        .[urban_rural %like% geo_comp]
}


count_shooting_city <- function(choose_race = "*", weapon = "*", geo_comp = "*") {
    ## This function returns the number of cases of selected race and weapon in  
    ## each city of selected geo-component, of known race. Unknow race cases are 
    ## removed.
    ##
    ## args_______
    ## choose_race: string
    ##    race of the victim, takes values of "W", "B", "H", "A", ...
    ##    default "*" for all races
    ## weapon: string
    ##    weapon the victim was carrying when being shot, "unarmed", "gun", 
    ##    "knife", ..., default "*" for all weapons
    ## geo_comp: string
    ##    take values "urban_area", "urban_cluster", and "rural". default "*" for
    ##    all geo-components
    ##
    ## return__________
    ## a data.table of the number of race killed in each city
    
    # remove shooting of unknown race
    shooting <- read_shooting_data(choose_race, weapon, geo_comp) %>%
        .[race != ""]
    
    # count shooting death in each city of the selected race
    city_count <- shooting[, .(count = .N), by = .(city_state)] %>%
        .[order(-count)]

    # add lon and lat to city_count
    city_coord <- city_lon_lat()
    city_count <- city_coord[city_count, on = .(city_state)]
    
    # add geo-component of the city
    geo_city <- shooting[, .(city_state, urban_rural, state)] %>%
        unique()
    city_count <- geo_city[city_count, on = .(city_state)]
}


count_shooting_state <- function(choose_race = "*", weapon = "*", geo_comp = "*") {
    ## This function calculate number of cases of police fatal shooting in each 
    ## state of selected race, weapon and geo-component
    ##
    ## args_______
    ## choose_race: string
    ##    race of the victim, takes values of "W", "B", "H", "A", ...
    ##    default "*" for all races
    ## weapon: string
    ##    weapon the victim was carrying when being shot, "unarmed", "gun", 
    ##    "knife", ..., default "*" for all weapons
    ## geo_comp: string
    ##    take values "urban_area", "urban_cluster", and "rural". default "*" for
    ##    all geo-components
    ##
    ## returns_________
    ## a data.table of the number of selected race and weapon in each state
    
    # make a single columns data table of states to join by data with missing 
    # state so that the return is force to include all states
    state_dt <- data.table(
        state = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", 
                  "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", 
                  "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", 
                  "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", 
                  "VT", "VA", "WA", "WV", "WI", "WY", "DC")
    )
    
    count <- read_shooting_data(choose_race, weapon, geo_comp) %>%
        .[race != ""] %>%          # remove unknown race if any
        .[, .(count = .N), by = .(state)] %>%
        # force to include all states
        .[state_dt, on = .(state)] %>%
        .[is.na(count), count := 0] %>%
        .[order(-count)]
}


count_shooting_urban_rural <- function(choose_race = "*", weapon = "*") {
    ## This function returns a data.table of police shooting cases with victims  
    ## of selected race and weapon in urbanized area, urban clusters and rural  
    ## area of each state.
    ##
    ## args_______
    ## choose_race: string
    ##    race of the victim, takes values of "W", "B", "H", "A", ...
    ##    default "*" is for all races
    ## weapon: string
    ##    weapon the victim was carrying when being shot, "unarmed", "gun", 
    ##    "knife", ..., default "*" for all weapons
    ##
    ## returns______
    ## a data.table of the count of police shooting in each geo-component of 
    ## each state
    
    # make a single columns data table of states to join by data with missing 
    # state so that the return is force to include all states
    state_dt <- data.table(
        state = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", 
                  "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", 
                  "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", 
                  "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", 
                  "VT", "VA", "WA", "WV", "WI", "WY", "DC")
    )
    
    # count in each geo area
    count <- read_shooting_data(choose_race, weapon) %>%
        .[race != ""] %>%   # remove unknown race
        # count in all geo location
        .[, .N, by = .(state, urban_rural)]
    
    # seperate to each geo-component
    UA <- count[urban_rural == "urban_area", .(state, UA = N)] 
    UC <- count[urban_rural == "urban_cluster", .(state, UC = N)]
    rural <- count[urban_rural == "rural", .(state, rural = N)]
    
    # combine them into a large data.table , make sure to include all states
    # from very beginning even there is no count by forcing to include all states
    # with a join
    combined <- rural[state_dt, on = .(state)] %>%  
        UC[., on = .(state)] %>%
        UA[., on = .(state)] %>%
        # set NA to 0
        .[is.na(UA), UA := 0] %>%
        .[is.na(UC), UC := 0] %>%
        .[is.na(rural), rural := 0] %>%
        # add total urban, rural and small urban, and total geo
        .[, urban := UA + UC] %>%
        .[, all_geo := UA + UC + rural] %>%
        .[order(-all_geo)]
}

# prepare voting data =========================================================

vote_obama_2012 <- function(){
    ## This function returns a data.table of the percentage of people voted for 
    ## Obama in 2012 election in each state. Data from
    ## https://en.wikipedia.org/wiki/United_States_presidential_election,_2012
    
    vote_obama <- data.table(
        state = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", 
                  "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", 
                  "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", 
                  "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", 
                  "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", 
                  "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", 
                  "WV", "WI", "WY"),
        perc_vote = c(38.36, 40.81, 44.59, 36.88, 60.24, 51.49, 58.06, 58.61, 
                      90.91, 50.01, 45.48, 70.55, 32.62, 57.6,  43.93, 51.99, 
                      37.99, 37.8,  40.58, 56.27, 61.97, 60.65, 54.21, 52.65, 
                      43.79, 44.38, 41.7,  38.03, 52.36, 51.98, 58.38, 52.99, 
                      63.35, 48.35, 38.69, 50.67, 33.23, 54.24, 51.97, 62.7, 
                      44.09, 39.87, 39.08, 41.38, 24.75, 66.57, 51.16, 56.16, 
                      35.54, 52.83, 27.82)
    )
}

is_red_or_blue <- function(state_name_vector) {
    ## determing if each state in a vector is a blue or red state
    ## 
    ## args_______
    ## state_name_vector: string
    ##     a vector of state names in abbr such as c("MA", "RI", "TX")
    ##
    ## return_____
    ## a vector of state color such as c("blue", "blue", "red")
    
    vote <- vote_obama_2012() %>%
        .[state_name_vector, on = .(state)] %>%
        # add a new color for the color of each state
        .[perc_vote < 50, red_blue := "red"] %>%
        .[perc_vote >= 50, red_blue := "blue"] %>%
        # return only vector of colors
        .[, red_blue]
}
