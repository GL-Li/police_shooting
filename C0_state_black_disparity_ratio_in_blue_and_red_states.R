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
                            title = NULL,
                            ylabel = NULL,
                            size_breaks = NULL,
                            fill_breaks = NULL,
                            annotation = NULL) {
    # This function plot the relationship between disparity ratio and vote for
    # Obama in 2012 election for each state. States with more than 3 blacks killed or
    # more than 300,000 black population state-wide are highlighted.
    
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
    # number of black people killed in the choose_geo
    black_killed <- shooting_count_urban_rural("B") %>%
        .[, black_killed := .[[choose_geo]]] %>%    # use variable as column name
        .[, .(state, black_killed)]                 # and [[]] to return a vector
    
    # number of all known races killed in the choose_geo
    total_killed <- shooting_count_urban_rural("all") %>%
        .[, total_killed := .[[choose_geo]]] %>%
        .[, .(state, total_killed)]
    
    # black population in choose_geo of each state in 2010 census
    black_population <- get_total_geo_population(choose_geo) %>%
        .[, population_percent := round(100 * black / total, 2)] %>%
        .[, .(state, black_population = black, population_percent)]
    
    # percent of vote for Obama in each state in 2012 election
    vote_obama <- vote_obama_2012() %>%
        setnames(., "perc_vote", "vote_percent")
    
    ###
    ### Join all data for plot. Highlight selected states in new column 
    ### with alpha = 1 and others with alpha = 0.2. Color blue and red state in
    ### new column color
    data_plot <- black_killed[total_killed, on=.(state)] %>%
        .[, black_killed_percent := round(black_killed / total_killed, 3) * 100] %>%
        black_population[., on = "state"] %>%
        vote_obama[., on = "state"] %>%
        .[vote_percent >= 50, color := "blue"] %>%
        .[vote_percent < 50, color := "red"] %>%
        .[state %in% selected_states, alpha := 1] %>%
        .[!state %in% selected_states, alpha := 0.2]
    
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
    # also if any ratio greater than 10, capped at 10 for better plotting
    data_plot[ratio > 10, ratio := 10]
    
    ###
    ### plot ratio vs vote for obama in 2012 
    ###
    # set up default arguments
    geo_name <- switch(choose_geo,
                       all_geo = "all area",
                       urban = "urban area",
                       UA = "large urban area",     # urbanized area
                       UC = "small urban area",     # urban cluster
                       rural = "rural area")
    if (is.null(title)) {
        title <- paste0("Relationship between disparity ratio in ", geo_name, 
                        " and vote for Obama in 2012 election")
    }
    if (is.null(ylabel)) {
        ylabel <- paste0("Disparity ratio in ", geo_name)
    }

    # prepare breaks for scale_size and scale fill, from min to max in real plot
    if (is.null(size_breaks)) {
        # using ceiling and floor to make sure breaks are in real data range.
        # otherwise it will not shown in legend label
        mini = ceiling(min(data_plot[["black_population"]]) / 1e5) / 10
        maxi = floor(max(data_plot[["black_population"]]) / 1e5) / 10
        dif = maxi - mini
        size_breaks <- c(mini, round(mini+0.3*dif, 1), round(mini+0.6*dif, 1), maxi)
    }
    if (is.null(fill_breaks)) {
        mini = min(data_plot[["black_killed"]])
        maxi = max(data_plot[["black_killed"]])
        dif = maxi - mini
        fill_breaks <- c(mini, round(mini+0.3*dif), round(mini+0.6*dif), maxi)
    }
    if (is.null(annotation)) {
        annotation <- paste0("Highligted are significant        and          states with\n", 
                            "more than 3 black people killed or with more than\n", 
                            "300,000 black population. Ratios greater\n",
                            "than 10 are set to 10.")
    }
    
    # only plot the selected state
    ggplot(data_plot, aes(vote_percent, ratio, color = color, alpha = alpha)) +
        geom_point(aes(size = black_population/1e6, fill = black_killed), pch = 21) +
        geom_text_repel(aes(label = state), size = 4) +
        geom_smooth(aes(weight = black_population), method = "lm", se = FALSE, color = "black", linetype = 2, size = 0.2) +
        
        # title, axis and legends === 
        ggtitle(title) +
        scale_x_continuous("Vote for Obama in 2012 presidential election",
                           breaks = c(30, 50, 70, 90), 
                           labels = paste0(c(30, 50, 70, 90), "%")) +
        scale_y_continuous(ylabel, breaks = seq(0, 11, 2)) +
        scale_size_area("black\npopulation\n(million)",
                        breaks = size_breaks,
                        guide = guide_legend(order = 1,   # first legend
                                             override.aes = list(shape = 1))) +
        scale_fill_gradient("number of\nblacks killed", 
                            low = "white", high = "black", 
                            breaks = fill_breaks,
                            guide = guide_legend(order = 2,   # second legend
                                                 override.aes = list(size=4))) +
        scale_color_identity() +    # default guide = "none" for scale_xxx_identity()
        scale_alpha_identity() +
        
        # annotations ===
        # national disparity ratio is 2.48 if calculated with black alone population,
        # 2.27 if calculated including black in combination with other races. take 
        # the mean, 2.37, for national disparity ratio
        geom_hline(yintercept = 2.37, linetype = 2, size = 0.2, color = "grey50") +
        annotate("text", x = 70, y = 2.2, label = "national disparity ratio", color = "grey50") +
        
        # so sad, cannot control text color in annotation, have to do this way
        annotate("text", x = 24, y = 10, hjust = 0, vjust = 1, color = "grey50",
                 label = annotation) +
        annotate("text", x = 39.1, y = 10, hjust = 0, vjust = 1, alpha = 1,
                 label = "red", color = "red") +
        annotate("text", x = 44.7, y = 10, hjust = 0, vjust = 1, alpha = 1,
                 label = "blue", color = "blue") +
        
        # themes === 
        theme_bw() +
        theme(plot.title = element_text(hjust = 0.5),
              axis.title = element_text(color = "grey50"),
              axis.text = element_text(color = "grey50"),
              axis.ticks = element_line(color = "grey50"),
              legend.position = c(0.91, 0.4),
              legend.title = element_text(color = "grey50"),
              legend.text = element_text(color = "grey50"),
              panel.background = element_rect(fill = "white"),
              panel.border = element_rect(color = "grey50"),
              panel.grid.major = element_line(color = "grey98"),
              panel.grid.minor = element_line(color = "grey98")) +

    # save plot 
    ggsave(filename = paste0("figures_temp/", save_as), width = 9, height = 5.5)
}


# disparity ratio of states binned as red, neutral and blue states ============
get_binned_state_geo <- function(choose_geo = "all_geo") {
    # This function returns population and people killed by police in
    # binned red state (50% or less vote for obama in 2012 election) and blue 
    # state (50% more vote for Obama) of the chosen geo-component. Disparity ratio
    # also computed
    
    # args______________
    # choose_geo: geo_component, choosen from "all_geo", "urban", "UA", "UC",
    #     "rural".
    
    # number black people killed in the choose_geo
    black_killed <- shooting_count_urban_rural("B") %>%
        .[, black_killed := .[[choose_geo]]] %>%    # use variable as column name
        .[, .(state, black_killed)]
    
    # number of all known races killed in the choose_geo
    total_killed <- shooting_count_urban_rural("all") %>%
        .[, total_killed := .[[choose_geo]]] %>%
        .[, .(state, total_killed)]
    
    
    # total and black population in each state in 2010 census
    total_and_black_population <- get_total_geo_population(choose_geo) %>%
        .[, .(state, total_population = total, 
              black_population = black)]
    
    # percent of vote for Obama in each state in 2012 election
    vote_obama <- vote_obama_2012() %>%
        setnames(., "perc_vote", "vote_percent")
    
    # join all data for plot
    data_plot <- total_killed[black_killed, on=.(state)] %>%
        total_and_black_population[., on = "state"] %>%
        vote_obama[., on = "state"]
    
    # bin by vote percent into three groups and add a new column for it
    # red: vote_percent < 45%
    # neutral: 45% <= vote_percent <= 55%
    # blue: vote_percent > 55%
    data_plot[, red_blue := cut(vote_percent, 
                                breaks = c(0, 50, 100),
                                labels = c("red", "blue"))]
    
    data_binned <- data_plot[, .(sum_total_population = sum(total_population),
                                 sum_black_population = sum(black_population),
                                 sum_total_killed = sum(total_killed),
                                 sum_black_killed = sum(black_killed)),
                             by = red_blue] %>%
        .[, black_population_percent := round(100 * sum_black_population / sum_total_population, 2)] %>%
        .[, black_killed_percent := round(100 * sum_black_killed / sum_total_killed, 2)] %>%
        .[, black_killed_per_million := round(sum_black_killed / sum_black_population * 1e6, 2)] %>%
        .[, non_black_killed_per_million := round((sum_total_killed -sum_black_killed) / 
                                                      (sum_total_population -sum_black_population) * 1e6, 2)] %>%
        .[, disparity_ratio := round(black_killed_per_million / non_black_killed_per_million, 2)] %>%
        .[, geo_component := switch(choose_geo, 
                                    "all_geo" = "all area",
                                    "urban" = "urban area",
                                    "UA" = "urbanized area",
                                    "UC" = "urban cluster",
                                    "rural" = "rural area")]
}


plot_grouped_state_disparity <- function() {
    # This function plot disparity ration and number of people per million killed by police in 
    # grouped blue and red states
    
    # prepare data ===
    all_geo <- get_binned_state_geo("all_geo")
    UA <- get_binned_state_geo("UA")
    UC <- get_binned_state_geo("UC")
    rural <- get_binned_state_geo("rural")
    data_plot <- rbindlist(list(all_geo, UA, UC, rural)) %>%
        # keep only needed columns
        .[, .(red_blue, black_killed_per_million, non_black_killed_per_million, geo_component)] %>%
        # convert to long table for plot
        melt(measure.vars = c("black_killed_per_million", "non_black_killed_per_million"),
             variable.name = "race",
             value.name = "killed_per_million") %>%
        # change values in column "race"
        .[, race := ifelse(race == "black_killed_per_million", "black", "non-\nblack")] %>%
        # reorder levels of geo_component
        .[, geo_component := factor(geo_component, levels = c("all area", "urbanized area",
                                                               "urban cluster", "rural area"))] %>%
        # reorder rows 
        setorder(geo_component, red_blue, race) %>%
        # add new column for position
        .[, x_position := c(1, 3, 5.2, 7.2,       # all area
                            11, 13, 15.2, 17.2,   # UA
                            20, 22, 24.2, 26.2,   # UC
                            29, 31, 33.2, 35.2)] %>%  # all area
        # add alpha to mute UC and rural area
        .[, alpha := c(rep(1, 8), rep(0.3, 8))]
    
    # label data tables
    state_label <- data.table(x_position = c(2, 6.2, 12, 16.2, 21, 25.2, 30, 34.2),
                              label = c("red states", "blue states"),
                              color = c("red", "blue"))
    geo_label <- data.table(x_position = c(4.1, 14.1, 23.1, 32.1),
                            label = c("All Area", 
                                      "Large Urban Area\npopulation > 50000",
                                      "Small Urban Area\npopulation < 50000",
                                      "Rural Area"),
                            color = c("grey30", "grey30", "black", "black"))
    
    # disparity data table
    data_disparity_plot <- rbindlist(list(all_geo, UA, UC, rural)) %>%
        .[, .(red_blue, disparity_ratio, geo_component)] %>%
        .[, geo_component := factor(geo_component, levels = c("all area", "urbanized area",
                                                              "urban cluster", "rural area"))] %>%
        setorder(geo_component, red_blue) %>%
        .[, x_position := c(2, 6.2, 12, 16.2, 21, 25.2, 30, 34.2)] %>%
        .[, color := c("black", "black", "purple", "purple", "orange", "orange", "cyan", "cyan")]
    
    # make plot ===
    ggplot(data_plot, aes(x_position, killed_per_million)) +
        geom_bar(stat = "identity", aes(color = red_blue, fill = race), size = 0.5, width = 1.9) +
        scale_fill_manual(values = c("black" = "gray70", "non-black" = "white")) +
        xlim(0, 36.5) +
        ylim(-1.5, 45.2) +
        
        # add state label
        # geom_text(data = state_label, aes(x_position, y = -0.5, label = label, color = color),
        #           size = 3, lineheight = 0.7, vjust = 1) +
        # add geo label
        geom_text(data = geo_label, aes(x_position, y = 40, label = label, color = color), 
                  size = 3.5, vjust = 1, lineheight = 0.7) +
        # add black and non-black label
        geom_text(aes(x_position, 0.2, label = race, color = red_blue), size = 2.5, 
                  lineheight = 0.7, vjust = 0) +
        # add number label
        geom_text(aes(x = x_position, y = killed_per_million + 0.2, color = red_blue,
                      label = killed_per_million), vjust = 0, hjust = 0.5, size = 2.8) +
        scale_color_identity() +
        
        # add a vertical line to split all area and other areas
        annotate("segment", x = 9.1, xend = 9.1, y = 0, yend = 20.5, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 0, yend = 20.5, linetype = 2, size = 0.2) +
        annotate("segment", x = 27.6, xend = 27.6, y = 0, yend = 20.5, linetype = 2, size = 0.2) +
        

        # add a fake title
        annotate("text", x = 0, y = 23, size = 3.5, hjust = 0, parse = TRUE, color = "grey30",
                 label = 'bold("Number of fatal police shooting per million population of black and non-black people")') +
        
        # add disparity ratio ===
        # magnify and move y axis for better contrast
        geom_line(data = data_disparity_plot, size = 1, color = "grey30",
                  aes(x = x_position, y = 2 * disparity_ratio + 26, group = geo_component)) +
        geom_point(data = data_disparity_plot, size = 3,
                   aes(x = x_position, y = 2 * disparity_ratio + 26, color = red_blue)) +
        geom_text(data = data_disparity_plot, size = 3, hjust = 1,
                  aes(x = x_position, y = 2 * disparity_ratio + 27, label = disparity_ratio, color = red_blue)) +
        annotate("segment", x = 9.1, xend = 9.1, y = 25, yend = 36, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 25, yend = 36, linetype = 2, size = 0.2) +
        annotate("segment", x = 27.6, xend = 27.6, y = 25, yend = 36, linetype = 2, size = 0.2) +
        
        # add title
        annotate("text", x = 0, y = 45, hjust = 0, size = 4.5, parse = TRUE,
                 label = 'bold("Fatal Police Shooting in       and         states")') +
        # sad that geom_text not good at text color, have to di it this way
        annotate("text", x = 12.75, y = 45.15, hjust = 0, color = "red", size = 4.5, parse = TRUE,
                 label = 'bold("red")') +
        annotate("text", x = 17, y = 45.15, hjust = 0, color = "blue", size = 4.5, parse = TRUE,
                 label = 'bold("blue")') + 
        
        annotate("text", x = 0, y = 42, hjust = 0, lineheight = 0.9, size = 3.5, parse = TRUE, color = "grey30",
                 label = 'bold("How many times black people are as likely to be fatally shot by police as non-black people")') +
        
        # shade small urban area and rural area
        annotate("rect", xmin = 18.5, xmax = 36.5, ymin = 25, ymax = 41, fill = "white", alpha = 0.7) +
        annotate("rect", xmin = 18.5, xmax = 36.5, ymin = -1.5, ymax = 22.3, fill = "white", alpha = 0.7) +
        
        theme(plot.title = element_text(size = 10, face = "bold"),
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              axis.title = element_blank(),
              legend.position = "none",
              panel.grid = element_blank(),
              panel.background = element_blank(),
              plot.margin = unit(c(2, 0, -5, 0), "mm"))  # negative number set margin
    
    # save plot
    ggsave(filename = "figures_temp/geo_disparity_vertical.png", width = 6.5, height = 6)
}

plot_disparity_ratio_geo <- function() {
    # plot number of people per million killed by police in binned blue and red
    # states
    
    all_geo <- get_binned_state_geo("all_geo")
    UA <- get_binned_state_geo("UA")
    UC <- get_binned_state_geo("UC")
    rural <- get_binned_state_geo("rural")
    data_plot <- rbindlist(list(all_geo, UA, UC, rural)) %>%
        # keep only needed columns
        .[,.(red_blue, sum_black_killed, disparity_ratio, geo_component)] %>%
        # plot "blue" ahead of "red"
        .[, red_blue := factor(red_blue, levels = c("red", "blue"))] %>%
        # use numbers for x is easier to handle than factors
        .[, x_position := as.integer(red_blue)] %>%
        .[red_blue == "blue", blue_label := disparity_ratio] %>%
        .[red_blue == "red", red_label := disparity_ratio] %>%
        .[red_blue == "blue", blue_geo_label := geo_component]
    
    ggplot(data_plot, aes(x_position, disparity_ratio, group = geo_component, color = geo_component)) +
        geom_point(size = 2) +
        geom_line() + 
        ylim(-0.1, 4.5) +   # change to 7 if add title and description
        xlim(0.65, 2.1) +
        scale_color_manual(values = c("all area" = "black",
                                      "urbanized area" = "purple",
                                      "urban cluster" = "orange",
                                      "rural area" = "cyan")) +
        
        # label disparity ratio numbers
        geom_text(aes(label = red_label), hjust = 1.2, size = 3.2) +
        geom_text(aes(label = blue_label), hjust = -0.2, size = 3.2) +
        
        # label urban, rural area
        annotate("text", x = 0.87, y = 0.84, label = "urban area\n< 50000", 
                 hjust = 1, vjust = 0.5, lineheight = 0.8, color = "orange", size = 3.5) +
        annotate("text", x = 0.87, y = 1.68, label = "all area",
                 hjust = 1, vjust = 0.7, color = "black", size = 3.5) +
        annotate("text", x = 0.87, y = 1.94, label = "urban area\n> 50000", 
                 hjust = 1, vjust = 0.3, lineheight = 0.8, color = "purple", size = 3.5) +
        annotate("text", x = 0.87, y = 0.27, label = "rural area", 
                 hjust = 1, vjust = 0.5, lineheight = 0.8, color = "cyan", size = 3.5) +
        
        # add on blue and red states label
        annotate("text", x = 2, y = -0.1, label = "blue\nstates", color = "blue", 
                 lineheight = 0.7, size = 4) +
        annotate("text", x = 1, y = -0.1, label = "red\nstates", color = "red", 
                 lineheight = 0.7, size = 4) +
        
        # add verticle lines for blue and red states
        annotate("segment", x = 2, xend = 2, y = 0.2, yend = 4.4, linetype = 3, 
                 color = "blue", size = 0.2) +
        annotate("segment", x = 1, xend = 1, y = 0.2, yend = 2.1, linetype = 3, 
                 color = "red", size = 0.2) +
        
        # add description
        # ggtitle(paste0("Fatal police shooting: more discrimination against black",
        #                "\npeople in blue states than in red states")) +
        # annotate("text", x = 0.65, y = 7, vjust = 0.9, hjust = 0.00,  lineheight = 0.9, size = 3.5,
        #          label = paste0("In red states, black people are 1.68 times as likely to be killed by\n",
        #                         "police as non-black people.\n\n",
        #                         "This disparity ratio doubles to 3.26 in blue states.\n\n",
        #                         "In large urban area with more than 50000 population, which accounts\n",
        #                         "for 92% of black people killed, the disparity ratio is 1.94 in red states\n",
        #                         "and 3.07 in blue states.")) +
        annotate("text", x = 0.65, y = 4, hjust = 0, lineheight = 0.9, size = 3.5, parse = TRUE,
                 label = 'bold("How many times are black people as likely to be\nfatally shot by police as non-black people?")') +

        theme(plot.title = element_text(size = 12, face = "bold"),
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              axis.title = element_blank(),
              legend.position = "none",
              panel.grid = element_blank(),
              panel.background = element_blank())               
    ggsave(filename = "figures_temp/disparity_ratio_geo.png", width = 5, height = 3)
}
# plot_disparity_ratio_geo()
