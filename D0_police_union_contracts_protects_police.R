# to analyze the ways police union contracts protect police officers from being held
# accountable. Original data and analysis in this website
# http://www.checkthepolice.org/#review

library(data.table)
library(magrittr)
source("A0_functions_prepare_shooting_data.R")

# read the report data
raw <- readxl::read_excel("downloaded_data/Police+Contracts+Content+Final+June.xlsx") %>%
    # delete empty rows and columns, convert to data.table, and simplify column names
    .[1:576, 1:7] %>%
    setDT %>%
    setnames("City/State", "city") %>%
    setnames("Category", "category") %>%
    # delete rows for "Police Bill of Rights" of states
    .[!(grepl("Police Bill of Rights", city))] %>%
    # remove empty space before and after city name, example: "Baltimore "
    .[, city := trimws(city)] 

# 100 largest cities in 2015. read the whole line and keep only city and state
# anoying thing is that sep can only be one byte so "--" is not a sep
largest_100 <- fread("downloaded_data/largest_100_cities_2015.csv", sep = "\n",
                     blank.lines.skip = TRUE, header = FALSE) %>%
    # get city and state names from each line
    .[, V1 := strsplit(V1, "--")] %>%
    .[, V1 := sapply(V1, function(x) x[3])] %>%
    .[, V1 := strsplit(V1, ",")] %>%
    .[, .(city = sapply(V1, function(x) x[1]), 
          state = sapply(V1, function(x) x[2]))] %>%
    .[, city := trimws(city)] %>%
    .[, state := trimws(state)] %>%
    # in 2010 census, Spokane, WA and Rochester, NY to replace Richmond, VA and 
    # Boise City, ID. Also change some city names to match the report
    .[city == "Richmond", ":=" (city = "Spokane", state = "WA")] %>%
    .[city == "Boise City", ":=" (city = "Rochester", state = "NY")] %>%
    .[city == "New York City", city := "New York"] %>%
    .[city == "Washington", city := "Washington D.C."] %>%
    # determine blue or red state
    .[, blue_red := sapply(state, function(x) is_red_or_blue(x))]

    

# add state to each city. use dput(uniq_category_count$city) to get city vector
# from later section
city_state <- data.table(
    city = c("Austin", "Hialeah", "Louisville", "San Antonio", "Seattle", 
             "Washington D.C.", "Albuquerque", "Anchorage", "Chicago", "Cleveland", 
             "Columbus", "Detroit", "Houston", "Jacksonville", "Laredo", "Lincoln", 
             "Orlando", "Phoenix", "Rochester", "St. Petersburg", "Tampa", 
             "Tucson", "Baltimore", "Baton Rouge", "Buffalo", "Chandler", 
             "Corpus Christi", "El Paso", "Honolulu", "Jersey City", "Las Vegas", 
             "Lexington", "Memphis", "Miami", "Minneapolis", "Oklahoma City", 
             "Omaha", "Portland", "San Diego", "Spokane", "St. Paul", "Toledo", 
             "Tulsa", "Wichita", "Cincinnati", "Fort Wayne", "Glendale", "Indianapolis", 
             "Kansas City", "Milwaukee", "North Las Vegas", "Pittsburgh", 
             "Reno", "Sacramento", "San Francisco", "San Jose", "Anaheim", 
             "Fort Worth", "Henderson", "Irvine", "Los Angeles", "Newark", 
             "St. Louis", "Bakersfield", "Madison", "Mesa", "New York", "Oakland", 
             "Philadelphia", "Riverside", "Santa Ana", "Stockton"),
    state = c("TX", "FL", "KY", "TX", "WA", "DC", "NM", "AK", "IL", "OH", "OH",
              "MI", "TX", "FL", "TX", "NE", "FL", "AZ", "NY", "FL", "FL", "AZ",
              "MD", "LA", "NY", "AZ", "TX", "TX", "HI", "NJ", "NV", "KY", "TN",
              "FL", "MN", "OK", "NE", "OR", "CA", "WA", "MN", "OH", "OK", "KS",
              "OH", "IN", "AZ", "IN", "KS", "WI", "NV", "PA", "NV", "CA", "CA",
              "CA", "CA", "TX", "NV", "CA", "CA", "NJ", "MO", "CA", "WI", "AZ",
              "NY", "CA", "PA", "CA", "CA", "CA")
)

# count total categories in a city ==================================================
# Category count
raw[, .(count = .N), by = .(category)]
    #                                Category count
    # 1:            Erases misconduct records    70
    # 2: Gives officers unfair access to info    72
    # 3:          Limits oversight/discipline   138
    # 4:     Requires city pay for misconduct    65
    # 5:      Restricts/delays interrogations   124
    # 6:              Disqualifies complaints    34


# number of unique category in each city
uniq_category_count <- unique(raw[, .(city, category)]) %>%
    .[, .(count = .N), by = .(city)] %>%
    .[order(-count)]


# number of all category in each city
category_count <- raw[, .(city, category)] %>%
    .[, .(count = .N), by = .(city)] %>%
    .[order(-count)]
    # cities in red states seems have more protection to police officers


# add cities not in the review
all_cities <- uniq_category_count[largest_100, on = .(city)] %>%
    .[is.na(count), count := 0]

# average count in blue and red state
avg_count <- all_cities[, .(avg = mean(count)), by = .(blue_red)]

# count each category =========================================================
uniq_each_category_count <- raw[, .(city, category)] %>%
    .[, .(count = .N), by = .(city, category)] %>%
    .[order(-count)]

all_city_each <- uniq_each_category_count[largest_100, on = .(city)] %>%
    .[is.na(count), count := 0]
all_city_each[, .(avg = mean(count)), by = .(blue_red, category)] %>%
    .[order(category, blue_red)] %>%
    .[!is.na(category)]
    #     blue_red                             category      avg
    #  1:     blue              Disqualifies complaints 1.357143
    #  2:      red              Disqualifies complaints 1.363636
    #  3:     blue            Erases misconduct records 1.714286
    #  4:      red            Erases misconduct records 1.466667
    #  5:     blue Gives officers unfair access to info 1.761905
    #  6:      red Gives officers unfair access to info 1.750000
    #  7:     blue          Limits oversight/discipline 2.150000
    #  8:      red          Limits oversight/discipline 2.166667
    #  9:     blue     Requires city pay for misconduct 1.692308
    # 10:      red     Requires city pay for misconduct 1.500000
    # 11:     blue      Restricts/delays interrogations 2.517241
    # 12:      red      Restricts/delays interrogations 2.428571