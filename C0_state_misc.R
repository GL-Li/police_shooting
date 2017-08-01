library(ggplot2)
library(ggrepel)
library(data.table)
library(ggmap)
library(magrittr)

# load functions for police shooting data
source("A0_functions_prepare_shooting_data.R")

# load functions for 2010 census data
source("A0_functions_extract_census_data.R")

# black population in each geo-component ======================================

# population in each geo-components
all_geo <- get_total_geo_population() %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
ua <- get_total_geo_population("UA") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
uc <- get_total_geo_population("UC") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
rural <- get_total_geo_population("rural") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]


# black population in each component
b_total <- all_geo[, sum(black), blue_red]
b_ua <- ua[, sum(black), blue_red]
b_uc <- uc[, sum(black), blue_red]
b_rural <- rural[, sum(black), blue_red]

# what percent of black population in total black population in UA 

# blue states
b_ua[1, V1] / b_total[1, V1]
    # 0.93

# red state
b_ua[2, V1] / b_total[2, V1]


# black killed in each geo-components =========================================
# number of blacks killed in each geo in each state
all_geo <- count_shooting_state("B") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
ua <- count_shooting_state("B", geo_comp = "urban_area") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
uc <- count_shooting_state("B", geo_comp = "urban_cluster") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]
rural <- count_shooting_state("B", geo_comp = "rural") %>%
    .[, blue_red := sapply(state, is_red_or_blue)]

# total in blue and red states
b_total <- all_geo[, sum(count), blue_red]
b_ua <- ua[, sum(count), blue_red]
b_uc <- uc[, sum(count), blue_red]
b_rural <- rural[, sum(count), blue_red]

# what percent of black in total black killed in large urban area
# blue states
b_ua[1, V1] / b_total[1, V1]
    # 0.93
# red state
b_ua[2, V1] / b_total[2, V1]
    # 0.82

# blue and red
ua[, sum(count)] / all_geo[, sum(count)]
    # 0.88


# total and black killed in each geo-component ================================

# total killed in blue and red states
total <- count_shooting_urban_rural() %>%
    .[, blue_red := sapply(state, is_red_or_blue)] %>%
    .[, .(all_geo, UA, UC, rural, blue_red)] %>%
    .[, lapply(.SD, sum), by = blue_red]

    #    blue_red all_geo   UA  UC rural
    # 1:     blue    1278 1057 109   112
    # 2:      red    1031  675 195   161


# black killed in blue and red states
black <- count_shooting_urban_rural("B") %>%
    .[, blue_red := sapply(state, is_red_or_blue)] %>%
    .[, .(all_geo, UA, UC, rural, blue_red)] %>%
    .[, lapply(.SD, sum), by = blue_red]

    #    blue_red all_geo  UA UC rural
    # 1:     blue     358 333 12    13
    # 2:      red     250 205 24    21