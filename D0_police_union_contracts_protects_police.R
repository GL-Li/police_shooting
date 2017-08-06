# to analyze how police union contracts protect police officers from being held
# accountable. Original data and analysis are in this website
# http://www.checkthepolice.org/#review

# reviewed police union contract of 81 cities out of 100 largest cities
#     72 have language to protect police officer in the specified category
#     9 do not have those description
# Birmingham, Chesapeake, and San Bernardino refused to send contracts
# remaining 16 do not have police union contract



library(data.table)
library(magrittr)
source("A0_functions_prepare_shooting_data.R")

# 100 largest cities in 2015, downloaded from 
# http://www.moderncities.com/article/2016-may-top-100-us-cities-ranked-by-2015-population
# The above report uses 2010 city data, which is two cities different from 2015
# list. Will change in the code.
# read the whole line and keep only city and state
# anoying thing is that sep can only be one byte so "--" is not a sep
largest_100 <- fread("downloaded_data/largest_100_cities_2015.csv", sep = "\n",
                     blank.lines.skip = TRUE, header = FALSE) %>%
    # get city and state names from each line
    .[, V1 := strsplit(V1, "--")] %>%
    .[, V2 := sapply(V1, function(x) x[3])] %>%
    .[, V2 := strsplit(V2, ",")] %>%
    .[, city := sapply(V2, function(x) x[1])] %>%
    .[, state := sapply(V2, function(x) x[2])] %>%
    .[, city := trimws(city)] %>%
    .[, state := trimws(state)] %>%
    # get population
    .[, V3 := sapply(V1, function(x) x[1])] %>%
    .[, V4 := sapply(V3, function(x) substr(x, 4, nchar(x)))] %>%
    .[, population := as.numeric(gsub("[^0-9]", "", V4))] %>%
    # keep only selected columns
    .[, .(city, state, population)] %>%
    # in 2010 census, Spokane, WA and Rochester, NY to replace Richmond, VA and 
    # Boise City, ID. Also change some city names to match the report
    .[city == "Richmond", ":=" (city = "Spokane", state = "WA", population = 215973)] %>%
    .[city == "Boise City", ":=" (city = "Rochester", state = "NY", population = 208880)] %>%
    .[city == "New York City", city := "New York"] %>%
    .[city == "Washington", city := "Washington D.C."] %>%
    # determine blue or red state
    .[, red_blue := is_red_or_blue(state)]



# read the report data and add state informaion
report <- readxl::read_excel("downloaded_data/Police+Contracts+Content+Final+June.xlsx") %>%
    # delete empty rows and columns, convert to data.table, and simplify column names
    .[1:576, 1:7] %>%
    setDT() %>%
    setnames("City/State", "city") %>%
    setnames("Category", "category") %>%
    # delete rows for "Police Bill of Rights" of states
    .[!(grepl("Police Bill of Rights", city))] %>%
    # remove empty space before and after city name, example: "Baltimore "
    .[, city := trimws(city)] %>%
    largest_100[., on = .(city)]


get_avg_count <- function(){
    ## average count of each category in each city in blue and red states
    ## average by all cities in the 100 largest cities, not only by those having the
    ## record.

    # total number of cities in blue and red cities
    n_blue <- largest_100[, .N, by = red_blue][1, N]
    n_red <- largest_100[, .N, by = red_blue][2, N]
    
    # average count of category in blue and red state
    avg_blue <- report[, .(blue = round(.N / n_blue, 2)), 
                       by = .(red_blue, category)] %>%
        .[red_blue == "blue"]
    avg_red <- report[, .(red = round(.N / n_red, 2)), 
                      by = .(red_blue, category)] %>%
        .[red_blue == "red"]
    
    avg <- avg_blue[avg_red, on = .(category)] %>%
        .[, .(category, blue, red)]
    
    # add a new row of total of all categories
    all_cat <- lapply(avg[, 2:3], sum) %>%
        setDT() %>%
        .[, category := "total"] %>%
        setcolorder(c("category", "blue", "red"))
    
    # conbine avg and total
    rbindlist(list(avg, all_cat))
}


get_weighted_avg_count <- function(){
    ## average count of each category in each city in blue and red states
    ## average by all cities in the 100 largest cities, not only by those having the
    ## record.
    ## weighted by population, the final output is number of category per million
    ## population
    
    # total population in blue and red cities
    pop_blue <- largest_100[, sum(population), by = red_blue][1, V1]
    pop_red <- largest_100[, sum(population), by = red_blue][2, V1]
    
    # average count of category in blue and red state
    avg_blue <- report[, .(blue = round(sum(population) / pop_blue, 2)), 
                       by = .(red_blue, category)] %>%
        .[red_blue == "blue"]
    avg_red <- report[, .(red = round(sum(population) / pop_red, 2)), 
                      by = .(red_blue, category)] %>%
        .[red_blue == "red"]
        
    avg <- avg_blue[avg_red, on = .(category)] %>%
        .[, .(category, blue, red)]
    
    # add a new row of total of all categories
    all_cat <- lapply(avg[, 2:3], sum) %>%
        setDT() %>%
        .[, category := "total"] %>%
        setcolorder(c("category", "blue", "red"))
    
    # conbine avg and total
     rbindlist(list(avg, all_cat))
}


# average count ==============================================================
avg <- get_avg_count()
    #                                category blue  red
    # 1:            Erases misconduct records 0.83 0.52
    # 2: Gives officers unfair access to info 0.64 0.83
    # 3:          Limits oversight/discipline 1.48 1.24
    # 4:     Requires city pay for misconduct 0.76 0.50
    # 5:      Restricts/delays interrogations 1.26 1.21
    # 6:              Disqualifies complaints 0.33 0.36
    # 7:                                total 5.30 4.66


weighted_avg <- get_weighted_avg_count()
    #                                category blue  red
    # 1:            Erases misconduct records 1.03 0.65
    # 2: Gives officers unfair access to info 0.64 0.93
    # 3:          Limits oversight/discipline 1.25 1.71
    # 4:     Requires city pay for misconduct 0.68 0.59
    # 5:      Restricts/delays interrogations 1.14 1.44
    # 6:              Disqualifies complaints 0.22 0.58
    # 7:                                total 4.96 5.90


