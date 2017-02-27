# This file compare the disparity ratio of the probability of black people to that of non 
# black people being shot dead by police in blue and in red states.

library(ggplot2)
library(ggrepel)
library(data.table)
library(ggmap)
library(magrittr)

# load functions for police shooting data
source("~/Dropbox/dataset_analysis/police_shooting/A0_functions_prepare_shooting_data.R")

# load functions for 2010 census data
source("~/Dropbox/dataset_analysis/us_2010_census/A0_functions_extract_census_data.R")


# disparity ration of each state ==============================================

# define the function to make plot
plot_ratio_vote <- function(choose_geo = "all_geo", 
                            save_as = paste0(choose_geo, "_ratio.png"),
                            title = "default",
                            ylabel = "default",
                            size_breaks = "default",
                            fill_breaks = "default",
                            annotation = "default") {
    # This function plot the relationship between disparity ratio and vote for
    # Obama in 2012 election for states that have more than 3 blacks killed or
    # more than 300,000 black population state-wide
    
    # args_____________
    # choose_geo: geocomponent in 2010 census, "all_geo" for all areas, "urban"
    #     for urban, "UA" for urbanized area, "UC" for urban cluster, "rural" for 
    #     rural area. 
    # save_as: save the plot to the file name. By default, it contains the 
    #     choose_geo plus _ratio.png
    # title: title of the plot, default provided below
    # ylabel: label of y axis, default provided below
    # size_breaks: breaks for scale_size_area(), default provided below
    # fill_breaks: breaks for scale_fill_gradient(), default provided below
    # annotation: label for annotate(), default provided below
    # return______________
    # a save png figure

    ###
    ### select states that has more than 3 blacks killed OR more than 300,000
    ###
    black_killed_all_geo <- shooting_state_count("B")
    total_black_population <- get_total_geo_population("all_geo") %>%
        .[, .(state, black)]
    selected_states <- black_killed_all_geo[total_black_population, on = .(state)] %>%
        .[count > 3 | black > 300000, state]
    
    ###
    ### prepare data
    ###
    # number black people killed in the choose_geo
    black_killed <- shooting_count_urban_rural("B") %>%
        .[, black_killed := .[[choose_geo]]] %>%    # use variable as column name
        .[, .(state, black_killed)]
    
    # number of all known races killed in the choose_geo
    total_killed <- shooting_count_urban_rural("all") %>%
        .[, total_killed := .[[choose_geo]]] %>%
        .[, .(state, total_killed)]
    
    # black population in each state in 2010 census
    black_population <- get_total_geo_population(choose_geo) %>%
        .[, population_percent := round(100 * black / total, 2)] %>%
        .[, .(state, black_population = black, population_percent)]
    
    # percent of vote for Obama in each state in 2012 election
    vote_obama <- vote_obama_2012() %>%
        setnames(., "perc_vote", "vote_percent")
    
    ###
    ### join all data for plot
    ###
    data_plot <- black_killed[total_killed, on=.(state)] %>%
        .[, black_killed_percent := round(black_killed / total_killed, 3) * 100] %>%
        black_population[., on = "state"] %>%
        vote_obama[., on = "state"]
    
    ###
    ### add disparity ratio for plot
    ###
    # now we can calculate the ratio that represents how many times blacks are likely 
    # to be killed by polce compared to non-blacks. 
    # the ratio is calculated with k * (100 - p) / (p * (100 - k)) where k is percent 
    # of blacks among killed and p is percent of black population.
    data_plot[,  ratio := round(black_killed_percent * (100 - population_percent) / 
                                    (population_percent * (100 - black_killed_percent)), 3)]
    # if all killed are blacks. the ratio is infinity. we use 10 to represent it.
    # also if any ration greater than 10, capped at 10 for better plotting
    data_plot[ratio > 10, ratio := 10]
    
    ###
    ### plot ratio vs vote for obama in 2012 
    ###
    # set up default arguments
    geo_name <- switch(choose_geo,
                       all_geo = "entire state",
                       urban = "urban areas",
                       UA = "urbanized areas",
                       UC = "urban clusters",
                       rural = "rural areas")
    if (title == "default") {
        title <- paste0("Relationship between the disparity ratio in ", geo_name, 
                        " and vote for Obama in 2012 election")
    }
    if (ylabel == "default") {
        ylabel <- paste0("Disparity ratio in ", geo_name)
    }

    # prepare breaks for scale_size and scale fill
    if (all(size_breaks == "default")) {
        size_breaks <- floor(10 * max(data_plot[["black_population"]]) / 1e6) *
            c(0.01, 0.02, 0.05, 0.1)
    }
    if (all(fill_breaks == "default")) {
        fill_breaks <- round(max(data_plot[["black_killed"]]) * c(0.1, 0.2, 0.5, 1)) %>%
            unique
    }
    if (annotation == "default") {
        annotation <- paste("Only showing data of states with more than 3 black", 
                            "people killed or\nwith more than 300,000 black population.", 
                            "Ratios greater than 10 are \nset to 10 for plotting.")
    }
    
    # only plot the selected state
    ggplot(data_plot[state %in% selected_states], aes(vote_percent, ratio)) +
        geom_point(aes(size = black_population/1e6, fill = black_killed), pch = 21) +
        scale_size_area(breaks = size_breaks,
                        guide = guide_legend(title = "black\npopulation\n(million)",
                                             override.aes = list(shape = 1))) +
        scale_fill_gradient(low = "white", high = "black", breaks = fill_breaks,
                            guide = guide_legend(title = "number of\nblacks killed", 
                                                 override.aes = list(size=4))) +
        geom_text_repel(aes(label = state), size = 4) +
        geom_smooth(method = "lm", se = FALSE, color = "black", linetype = 2, size = 0.2) +
        xlab("Percentage of vote for Obama in 2012 (%)") +
        ylab(ylabel) +
        ggtitle(title) +
        theme(plot.title = element_text(hjust = 0.5),
              legend.position = c(0.91, 0.4),
              panel.background = element_rect(fill = "#C1F7C1")) +
        # national disparity ratio is 2.48 if calculated with black alone population,
        # 2.27 if calculated including black in combination with other races. take 
        # the mean for national disparity ratio
        geom_hline(yintercept = 2.37, linetype = 2, size = 0.2) +
        annotate("text", x = 70, y = 2.2, label = "national disparity ratio") +
        scale_y_continuous(breaks = seq(0, 11, 2)) +
        annotate("text", x = 33, y = 9.5, hjust = 0, alpha = 0.5,
                 label = annotation)
    ggsave(filename = paste0("figures/", save_as), width = 9, height = 5.5)
}


# disparity ratio of states binned as red, neutral and blue states ============

