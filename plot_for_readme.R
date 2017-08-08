# plot all figures used in readme
source("A0_functions_extract_census_data.R")
source("A0_functions_prepare_shooting_data.R")
source("B0_city_shooting_in_cities_on_map.R")
source("C0_state_black_disparity_ratio_in_blue_and_red_states.R")


# compare disparity ratio in red and blue states as groups ====================

# all shooting case with known races
plot_disparity_grouped_state()


# disparity ratio ~ vote for Obama in large urban area ========================
plot_ratio_vote("UA")

# map of shooting death of all races in Georgia ===============================
plot_shooting_on_state_map(state = "GA", max_size = 20)

