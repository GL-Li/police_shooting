# This file defines functions for preparing Washington Post fatal police shooting data.
# Last reviewed 4/24/2017


library(data.table)
library(magrittr)
library(ggmap)

# define geological functions =================================================

convert_state_names <- function(state_names, from, to) {
    # This function converts state names between lower case and abbriavation
    
    # args_______________
    # state_names: vector of state names in lower case or abbrevation
    # from: format of names to be converted, take value "abbr" or "low"
    # to: format of converted names, take value "low" or "abbr"
    
    # return____________
    # a vector of converted state names
    
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
             "oregon", "pennsylvania", "rhode island", "south carolina", "south dakota", 
             "tennessee", "texas", "utah", "vermont", "virginia", "washington", 
             "west virginia", "wisconsin", "wyoming")
    
    # make a lookup table to convert between lowercase and abbrivation state names
    convert_to <- get(to)
    names(convert_to) <- get(from)
    
    # return results
    convert_to[state_names]
}

state_center_lon_lat <- function(){
    # this function returns the coordinate of the center of each state so that we
    # can plot something at the center instead of fill the whole map. 
    # Data were downloaded with ggmap::geocoding and then fine tuned.
    
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
    # This function return the longitude and latitude of cities where police 
    # shooting death occured
    
    # downloading city coordinates takes a long time. save the download to local 
    # computer as a csv file
    if (!file.exists("downloaded_data/city_coord.csv")) {
        # keep only location information from raw data
        shooting <- fread("downloaded_data/database.csv") %>%
            .[, .(city_state = paste0(city, ", ", state))]
        
        city_coord <- data.table(geocode(unique(shooting[, city_state]))) # no duplicate
        city_coord[["city_state"]] <- unique(shooting[, city_state])
        write.csv(city_coord, file = "downloaded_data/city_coord.csv", row.names = FALSE)
    }
    city_coord <- fread("downloaded_data/city_coord.csv")
}

# prepare shooting data =======================================================
read_shooting_data <- function(unarmed = FALSE) {
    # read shooting data
    
    # args_______
    # unarmed: logical
    #    weather the victim is unarmed
    
    # returns_____
    # data.table of shooting database
    
    shooting <- fread("downloaded_data/database.csv")
    # data.table not working in ifelse()
    # shooting <- ifelse(unarmed, shooting[armed == "unarmed"], shooting)
    if(unarmed) {
        shooting <- shooting[armed == "unarmed"]
    } 
    return(shooting)
}

shooting_race_location <- function(unarmed = FALSE){
    # This function returns a data.table of all shooting cases. Each row is a 
    # shooting case with location of the incident and race of the shooted.
    
    # args_______
    # unarmed: logical
    #    weather the victim is unarmed

    # keep only race and location
    shooting <- read_shooting_data(unarmed) %>%
        .[race != ""] %>%         # remove unknown race
        .[, .(race = race, city_state = paste0(city, ", ", state))]
    
    # add city coordinate to shooting data
    city_coord <- city_lon_lat()
    shooting <- city_coord[shooting, on = "city_state"]
}


shooting_city_count <- function(choose_race = "all", unarmed = FALSE) {
    # This function returns the number of people of the specified race killed by 
    # police in each city 
    
    # args____________
    # choose_race: "W" for white, "B" for black, "H" for hispanic, "A" for asian,
    #              and "all" for all races
    # unarmed: logical
    #    weather the victim is unarmed
    
    # return__________
    # a data.table of the number of race killed in each city
    
    # only care race and location here
    shooting <- shooting_race_location(unarmed)
    
    # count shooting death in each city of the selected race
    if (choose_race == "all") {
        city_count <- shooting[, .(count = .N), by = .(city_state)] %>%
            .[order(-count)]
    } else {
        city_count <- shooting[race == choose_race] %>%
            .[, .(count = .N), by = .(city_state)] %>%
            .[order(-count)]
    }

    # add lon and lat to city_count
    city_coord <- city_lon_lat()
    city_count <- city_coord[city_count, on = .(city_state)]
}


shooting_state_count <- function(choose_race = "all", unarmed = FALSE) {
    # This function calculate number of cases of police fatal shooting in each 
    # state of selected race
    
    # args_____________
    # choose_race: "W" for white, "B" for black, "H" for hispanic, "A" for asian,
    #    "all" for all races
    # unarmed: logical
    #    weather the victim is unarmed

    # returns_________
    # a data.table of the number of selected race killed in each state
    
    # make a single columns data table of states to join by data with missing state
    state_dt <- data.table(
        state = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID",
                  "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
                  "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND",
                  "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT",
                  "VA", "WA", "WV", "WI", "WY", "DC")
    )
    
    if (choose_race == "all"){
        count <- read_shooting_data(unarmed) %>%
            .[race != ""] %>%          # remove unknown race
            .[, .(state)] %>%
            .[, .(count = .N), by = .(state)] %>%
            .[state_dt, on = .(state)] %>%  # to add missing state
            .[is.na(count), count := 0] %>%
            .[order(-count)] 
    } else {
        count <- read_shooting_data(unarmed) %>%
            .[race != ""] %>%          # remove unknown race
            .[, .(race, state)] %>%
            .[, .(count = .N), by = .(state, race)] %>%
            .[race == choose_race] %>%
            .[, race := NULL] %>%
            .[state_dt, on = .(state)] %>%  # to add missing state
            .[is.na(count), count := 0] %>%
            .[order(-count)]
    }
    return(count)
}

shooting_count_urban_rural <- function(all_or_black = "all") {
    # This function returns a data.table of police shooting of all races or of 
    # blacks in urbanized area, urban clusters and rural area of each state.
    
    # args_________
    # all_or_black: all races or black race, take values "all" or "black"
    
    # returns______
    # a data.table of the count of police shooting
    
    # total number killed in each state
    total_killed <- shooting_state_count(all_or_black)
    
    if (all_or_black == "B") {
        # Number of blacks killed in urban clusters (UC) and rural area.
        # The numbers are counted from file "01_shooting_in_cities.R"
        # This number is for shooting cases in 2015 and 2016.
        # Have to recount for updated data.
        black_killd_UC_rural <- data.table(
            state = c("CA", "OR", "CO", "TX", "OK", "IA", "AR", "MS", "LA", "AL", "GA",
                      "FL", "SC", "NC", "KY", "VA", "WV", "PA", "NY", "IN", "IL", "WI"),
            UC =    c(3, 2, 1, 2, 3, 1, 0, 3, 2, 3, 1, 2, 1, 1, 2, 2, 1, 1, 0, 1, 1, 1),
            rural = c(0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0)
        )
        
        black_killed <- black_killd_UC_rural[total_killed, on = .(state)] %>%
            .[is.na(UC), UC := 0] %>%
            .[is.na(rural), rural := 0] %>%
            .[, UA := count - UC - rural] %>%
            .[, urban := UA + UC] %>%
            setnames(., "count", "all_geo")
        return(black_killed)
    }
    
    if (all_or_black == "all") {
        # total number killed (sum of all area) in each state, count from the same
        # file "01_shooting_in_cities.R". Numbers are for 2015 and 2016 shooting.
        total_killed_UC_rural <- data.table(
            state = c("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID",
                      "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN",
                      "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND",
                      "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT",
                      "VA", "WA", "WV", "WI", "WY", "DC"),
            UC = c(10, 2, 17, 2, 13, 3, 0, 0, 2, 10, 5, 3, 4, 2, 2, 7, 10, 5, 1, 0, 0,
                   2, 5, 4, 3, 3, 2, 1, 2, 1, 18, 2, 9, 0, 5, 15, 3, 1, 0, 5, 2, 8,
                   21, 3, 0, 3, 5, 4, 5, 4, 0),
            rural = c(8, 2, 4, 4, 9, 5, 2, 0, 5, 5, 0, 3, 0, 2, 1, 2, 11, 4, 1, 0, 0, 
                      6, 2, 5, 4, 3, 2, 1, 1, 2, 3, 4, 10, 1, 4, 12, 4, 4, 0, 7, 1, 3,
                      16, 0, 0, 6, 4, 6, 2, 0, 0)
        )
        
        total_killed <- total_killed_UC_rural[total_killed, on = .(state)] %>%
            .[, UA := count - UC - rural] %>%
            .[, urban := UA + UC] %>%
            setnames(., "count", "all_geo")
        return(total_killed)
    }
    
}

# prepare voting data =========================================================

vote_obama_2012 <- function(){
    # This function returns a data.table of the percentage of people voted for 
    # Obama in 2012 election in each state. Data from
    # https://en.wikipedia.org/wiki/United_States_presidential_election,_2012
    
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
