# This file compare the disparity ratio of the probability of black people to that of non 
# black people being shot dead by police in blue and in red states.
# last reviewed 8/5/2017

library(ggplot2)
library(ggrepel)
library(data.table)
library(ggmap)
library(magrittr)

# load functions for police shooting data
source("A0_functions_prepare_shooting_data.R")

# load functions for 2010 census data
source("A0_functions_extract_census_data.R")


# disparity ration of each state ==============================================

# define the function to make plot
plot_ratio_vote <- function(geo_comp = "*", 
                            save_as = paste0(geo_comp, "_ratio_vote.png"),
                            title = NULL,
                            ylabel = NULL,
                            size_breaks = NULL,
                            fill_breaks = NULL,
                            annotation = NULL) {
    ## This function plots the relationship between disparity ratio and vote for
    ## Obama in 2012 election for each state. States with more than 3 blacks 
    ## killed or more than 300,000 black population state-wide are highlighted.
    ##
    ## args_____________
    ## geo_comp: string
    ##     geocomponent in 2010 census, "*" for all areas, "urban"
    ##     for urban, "UA" for urbanized area, "UC" for urban cluster, "rural" for 
    ##     rural area. 
    ## save_as: string
    ##     save the plot to the file name. By default, it contains the 
    ##     geo_comp plus _ratio.png
    ## title: string
    ##     title of the plot, default provided below
    ## ylabel: string
    ##    label of y axis, default provided below
    ## size_breaks: numbers
    ##     breaks for scale_size_area(), default provided below
    ## fill_breaks: numbers
    ##     breaks for scale_fill_gradient(), default provided below
    ## annotation: string
    ##     label for annotate(), default provided below
    ##
    ## return______________
    ## a saved png figure
    ##
    
    # prepare data ===
    
    # select states that has more than 3 blacks killed OR more than 300,000
    black_killed_all_geo <- count_shooting_state("B")
    total_black_population <- get_total_geo_population("*") %>%
        .[, .(state, black)]
    selected_states <- black_killed_all_geo[total_black_population, on = .(state)] %>%
        .[count > 3 | black > 300000, state]
    
    # number of black people killed in the geo_comp
    black_killed <- count_shooting_urban_rural("B") %>%
        .[, black_killed := .[[ifelse(geo_comp == "*", "all_geo", geo_comp)]]] %>%    # use variable as column name
        .[, .(state, black_killed)]          # and [[]] to return a vector
    
    # number of all known races killed in the geo_comp
    total_killed <- count_shooting_urban_rural("*") %>%
        .[, total_killed := .[[ifelse(geo_comp == "*", "all_geo", geo_comp)]]] %>%
        .[, .(state, total_killed)]
    
    # black population in geo_comp of each state in 2010 census
    black_population <- get_total_geo_population(geo_comp) %>%
        .[, population_percent := round(100 * black / total, 2)] %>%
        .[, .(state, black_population = black, population_percent)]
    
    # percent of vote for Obama in each state in 2012 election
    vote_obama <- vote_obama_2012() %>%
        setnames(., "perc_vote", "vote_percent")
    
    
    # Join all data for plot. Highlight selected states in new column 
    # with alpha = 1 and others with alpha = 0.2. Color blue and red state in
    # new column color
    data_plot <- black_killed[total_killed, on=.(state)] %>%
        .[, black_killed_percent := round(black_killed / total_killed, 3) * 100] %>%
        black_population[., on = "state"] %>%
        vote_obama[., on = "state"] %>%
        .[, color := is_red_or_blue(state)] %>%
        .[state %in% selected_states, alpha := 1] %>%
        .[!state %in% selected_states, alpha := 0.2]
    
    
    # add disparity ratio for plot ===
 
    # now we can calculate the ratio that represents how many times blacks are likely 
    # to be killed by polce compared to non-blacks. 
    # the ratio is calculated with k * (100 - p) / (p * (100 - k)) where k is percent 
    # of blacks among killed and p is percent of black population.
    data_plot[,  ratio := round(black_killed_percent * (100 - population_percent) / 
                                    (population_percent * (100 - black_killed_percent)), 3)]
    # if all killed are blacks. the ratio is infinity. we use 10 to represent it.
    # also if any ratio greater than 10, capped at 10 for better plotting
    data_plot[ratio > 10, ratio := 10]
    

    ### plot ratio vs vote for obama in 2012 
    
    # set up default arguments
    geo_label <- switch(geo_comp,
                       "*" = "all area",
                       "urban" = "urban area",
                       "UA" = "large urban area",     # urbanized area
                       "UC" = "small urban area",     # urban cluster
                       "rural" = "rural area")
    if (is.null(title)) {
        title <- paste0("Relationship between disparity ratio in ", geo_label, 
                        " and vote for Obama in 2012 election")
    }
    if (is.null(ylabel)) {
        ylabel <- paste0("Disparity ratio in ", geo_label)
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
    
    # make plot === 
    ggplot(data_plot, aes(vote_percent, ratio, color = color, alpha = alpha)) +
        geom_point(aes(size = black_population/1e6, fill = black_killed), pch = 21) +
        geom_text_repel(aes(label = state), size = 4) +
        # smooth with highlighted states
        stat_smooth(data = data_plot[state %in% selected_states], 
                    aes(vote_percent, ratio, weight = black_population), 
                    method = "lm", se = FALSE, 
                    color = "black", linetype = 2, size = 0.2) +
        
        # title, axis and legends === 
        labs(title = "Disparity ratio increases with vote for Obama in 2012 election",
             subtitle = "fatal police shooting in January 2015 - June 2017",
             caption = "Source: Washington Post and Census 2010",
             x = "Vote for Obama in 2012 presidential election",
             y = ylabel,
             size = "black\npopulation\n(million)",
             fill = "number of\nblacks killed") +
        scale_x_continuous(limits = c(20, 92),
                           breaks = c(30, 50, 70, 90), 
                           labels = paste0(c(30, 50, 70, 90), "%")) +
        scale_y_continuous(breaks = seq(0, 11, 2)) +
        scale_size_area(breaks = size_breaks) +
        scale_fill_gradient(low = "white", high = "black", 
                            breaks = fill_breaks) +
        scale_color_identity() +    # default guide = "none" for scale_xxx_identity()
        scale_alpha_identity() +
        guides(size = guide_legend(order = 1,   # first legend
                                   override.aes = list(shape = 1)),
               fill = guide_legend(order = 2,   # second legend
                                   override.aes = list(size=4))) +
        
        # annotations ===
        # national disparity ratio is 2.48 if calculated with black alone population,
        # 2.27 if calculated including black in combination with other races. take 
        # the mean, 2.37, for national disparity ratio
        geom_hline(yintercept = 2.37, linetype = 2, size = 0.2, color = "grey50") +
        annotate("text", x = 70, y = 2.2, label = "national disparity ratio", color = "grey50") +
        
        # so sad, cannot control text color in annotation, have to do this way
        annotate("text", x = 20, y = 10, hjust = 0, vjust = 1, color = "grey50",
                 label = annotation) +
        annotate("text", x = 36.3, y = 10, hjust = 0, vjust = 1, alpha = 1,
                 label = "red", color = "red") +
        annotate("text", x = 42.2, y = 10, hjust = 0, vjust = 1, alpha = 1,
                 label = "blue", color = "blue") +
        
        # themes === 
        theme_bw() +
        theme(plot.title = element_text(hjust = 0),
              plot.caption = element_text(color = "grey50", family = "monospace"),
              axis.title = element_text(color = "grey50"),
              axis.text = element_text(color = "grey50"),
              axis.ticks = element_line(color = "grey50"),
              legend.position = c(0.91, 0.4),
              legend.title = element_text(color = "grey50"),
              legend.text = element_text(color = "grey50"),
              panel.background = element_rect(fill = "white"),
              panel.border = element_rect(color = "grey50"),
              panel.grid.major = element_line(color = "grey98"),
              panel.grid.minor = element_line(color = "grey98"))

    # save plot 
    ggsave(filename = paste0("figures_temp/", save_as), width = 9, height = 5.5)
}


# disparity ratio of states grouped as red and blue states ============
get_ratio_grouped_state <- function(geo_comp = "*", weapon = "*") {
    ## This function compares black and non-black people, returning population 
    ## and counts killed by police in binned red state (50% or less vote for 
    ## obama in 2012 election) and blue state (50% more vote for Obama) of the 
    ## selected geo-component and weapon. Disparity ratio also computed
    ##
    ## args______________
    ## geo_comp: string
    ##     geo_component, choosen from "*", "urban", "UA", "UC",
    ##     "rural". "*" for all geo-component
    ## weapon: string
    ##     weapon the victim was carrying when being shot, "*" for all weapons

    
    # number of black people killed in the geo_comp
    black_killed <- count_shooting_urban_rural("B", weapon) %>%
        .[, black_killed := .[[ifelse(geo_comp == "*", "all_geo", geo_comp)]]] %>%    # use variable as column name
        .[, .(state, black_killed)]
    
    # number of all known races killed in the geo_comp
    total_killed <- count_shooting_urban_rural("*", weapon) %>%
        .[, total_killed := .[[ifelse(geo_comp == "*", "all_geo", geo_comp)]]] %>%
        .[, .(state, total_killed)]
    
    
    # total and black population in selected geo-component of each state in 2010 census
    total_and_black_population <- get_total_geo_population(geo_comp) %>%
        .[, .(state, total_population = total, black_population = black)]
    
    # percent of vote for Obama in each state in 2012 election
    vote_obama <- vote_obama_2012() %>%
        setnames(., "perc_vote", "vote_percent")
    
    # join all data for plot
    data_plot <- total_killed[black_killed, on=.(state)] %>%
        total_and_black_population[., on = "state"] %>%
        vote_obama[., on = "state"] %>%
        .[, red_blue := is_red_or_blue(state)]
    
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
        .[, geo_component := switch(geo_comp, 
                                    "*" = "all area",
                                    "urban" = "urban area",
                                    "UA" = "urbanized area",
                                    "UC" = "urban cluster",
                                    "rural" = "rural area")]
}



plot_disparity_grouped_state <- function(weapon = "*") {
    ## This function plots disparity ratio and number of people per million  
    ## killed by police in grouped blue and red states at state level, into  
    ## three geo-components:
    ## 1) all area, 
    ## 2) large urban area (urbanized area), and 
    ## 3) rural and small urban area (urban cluster)
    
    # args___________
    # weapon: string
    #    weapon the victim was carrying when being shot, "*" for all weapons
    
    # prepare data ===
    all_geo <- get_ratio_grouped_state("*", weapon)
    UA <- get_ratio_grouped_state("UA", weapon)
    UC <- get_ratio_grouped_state("UC", weapon)
    rural <- get_ratio_grouped_state("rural", weapon)

    # combined rural and UC 
    rural_UC <- as.data.table(as.matrix(UC[, 2:5]) + as.matrix(rural[, 2:5])) %>%
        .[, blue_red := c("blue", "red")] %>%
        # move blue_red as first coloumn
        setcolorder(c("blue_red", setdiff(names(.), "blue_red"))) %>%
        .[, black_population_percent := round(100 * sum_black_population / sum_total_population, 2)] %>%
        .[, black_killed_percent := round(100 * sum_black_killed / sum_total_killed, 2)] %>%
        .[, black_killed_per_million := round(sum_black_killed / sum_black_population * 1e6, 2)] %>%
        .[, non_black_killed_per_million := round((sum_total_killed -sum_black_killed) / 
                                                      (sum_total_population -sum_black_population) * 1e6, 2)] %>%
        .[, disparity_ratio := round(black_killed_per_million / non_black_killed_per_million, 2)] %>%
        .[, geo_component := "rural and urban cluster"]
    
    data_plot <- rbindlist(list(all_geo, UA, rural_UC)) %>%
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
                                                              "rural and urban cluster"))] %>%
        # reorder rows 
        setorder(geo_component, -red_blue, race) %>%
        # add new column for position
        .[, x_position := c(1, 3, 5.2, 7.2,       # all area
                            11, 13, 15.2, 17.2,   # UA
                            20, 22, 24.2, 26.2)]  # rural and UC

    # label data tables
    state_label <- data.table(x_position = c(2, 6.2, 12, 16.2, 21, 25.2),
                              label = c("red states", "blue states"),
                              color = c("red", "blue"))
    geo_label <- data.table(x_position = c(4.1, 14.1, 23.1),
                            label = c("All Area", 
                                      "Large Urban Area\npopulation > 50000",
                                      "Rural and Small Urban Area"),
                            color = c("grey30", "grey30", "grey30"))
    
    # disparity data table
    data_disparity_plot <- rbindlist(list(all_geo, UA, rural_UC)) %>%
        .[, .(red_blue, disparity_ratio, geo_component)] %>%
        .[, geo_component := factor(geo_component, levels = c("all area", "urbanized area",
                                                              "rural and urban cluster"))] %>%
        setorder(geo_component, -red_blue) %>%
        .[, x_position := c(2, 6.2, 12, 16.2, 21, 25.2)] %>%
        .[, color := c("black", "black", "purple", "purple", "orange", "orange")]
    
    # make plot ===
    ggplot(data_plot, aes(x_position, killed_per_million)) +
        geom_col(aes(color = red_blue, fill = race), size = 0.5, width = 1.9) +
        
        # add state label
        # geom_text(data = state_label, aes(x_position, y = -0.5, label = label, color = color),
        #           size = 3, lineheight = 0.7, vjust = 1) +
        # add geo label
        geom_text(data = geo_label, aes(x_position, y = 37, label = label, color = color), 
                  size = 3.5, vjust = 1, lineheight = 0.7) +
        # add black and non-black label
        geom_text(aes(x_position, 0.2, label = race, color = red_blue), size = 2.5, 
                  lineheight = 0.7, vjust = 0) +
        # add number label
        geom_text(aes(x = x_position, y = killed_per_million + 0.2, color = red_blue,
                      label = killed_per_million), vjust = 0, hjust = 0.5, size = 2.8) +
        scale_color_identity() +
        scale_fill_manual(values = c("black" = "gray70", "non-black" = "white")) +
        xlim(0, 27.5) +
        ylim(-3, 44.2) +

        # add a vertical line to split geo-components
        annotate("segment", x = 9.1, xend = 9.1, y = 0, yend = 16, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 0, yend = 16, linetype = 2, size = 0.2) +

        # add a fake subtitle
        annotate("text", x = 0, y = 20, size = 3.5, hjust = 0, parse = TRUE, color = "grey30",
                 label = 'bold("Number of fatal police shooting per million population of black and non-black people")') +
        
        # add disparity ratio ===
        # magnify and move y axis for better contrast
        geom_line(data = data_disparity_plot, size = 1, color = "grey90",
                  aes(x = x_position, y = 2 * disparity_ratio + 23, group = geo_component)) +
        geom_point(data = data_disparity_plot, size = 3,
                   aes(x = x_position, y = 2 * disparity_ratio + 23, color = red_blue)) +
        geom_text(data = data_disparity_plot, size = 3, hjust = 1,
                  aes(x = x_position, y = 2 * disparity_ratio + 24, label = disparity_ratio, color = red_blue)) +
        annotate("segment", x = 9.1, xend = 9.1, y = 22, yend = 33, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 22, yend = 33, linetype = 2, size = 0.2) +

        # add title
        annotate("text", x = 0, y = 44, hjust = 0, size = 4.5, parse = TRUE,
                 label = 'bold("Disparity is larger in                     than in        ")') +
        annotate("text", x = 0, y = 42, hjust = 0, size = 3.5, parse = TRUE,
                 label = 'bold("fatal police shooting in January 2015 - June 2017")') +
        # sad that geom_text not good at text color, have to di it this way
        annotate("text", x = 8.35, y = 44.2, hjust = 0, color = "blue", size = 4.5, 
                 parse = TRUE, label = 'bold("blue states")') +
        annotate("text", x = 15.95, y = 44.2, hjust = 0, color = "red", size = 4.5, 
                 parse = TRUE, label = 'bold("red states")') + 
        
        annotate("text", x = 0, y = 39, hjust = 0, lineheight = 0.9, size = 3.5, 
                 parse = TRUE, color = "grey30",
                 label = 'bold("How many times black people are as likely to be killed by police as non-black people")') +
        # fake a caption
        annotate("text", x = 27, y = -3, hjust = 1, color = "grey50", 
                 family = "monospace", size = 3,
                 label = "Sources: Washington Post and Census 2010") +
        theme(plot.title = element_text(size = 10, face = "bold"),
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              axis.title = element_blank(),
              legend.position = "none",
              panel.grid = element_blank(),
              panel.background = element_blank(),
              plot.margin = unit(c(2, 0, 0, 0), "mm"))  # negative number set margin
    
    # save plot
    ggsave(filename = "figures_temp/geo_disparity_vertical.png", width = 6.5, height = 5.5)
}

plot_unarmed_disparity_grouped_state <- function(weapon = "unarmed") {
    ## This function plot disparity ratio and number of unarmed people per million 
    ## killed by police in grouped blue and red states. Does not show rural and 
    ## small urban area data as the count is too few.
    ## Need to fine tune parameters so it defined as a separate function
    
    # prepare data ===
    all_geo <- get_ratio_grouped_state("*", weapon)
    UA <- get_ratio_grouped_state("UA", weapon)
    
    data_plot <- rbindlist(list(all_geo, UA)) %>%
        # keep only needed columns
        .[, .(red_blue, black_killed_per_million, non_black_killed_per_million, geo_component)] %>%
        # convert to long table for plot
        melt(measure.vars = c("black_killed_per_million", "non_black_killed_per_million"),
             variable.name = "race",
             value.name = "killed_per_million") %>%
        # change values in column "race"
        .[, race := ifelse(race == "black_killed_per_million", "black", "non-\nblack")] %>%
        # reorder levels of geo_component
        .[, geo_component := factor(geo_component, levels = c("all area", "urbanized area"))] %>%
        # reorder rows 
        setorder(geo_component, -red_blue, race) %>%
        # add new column for position
        .[, x_position := c(1, 3, 5.2, 7.2,       # all area
                            11, 13, 15.2, 17.2)]   # UA

    # label data tables
    state_label <- data.table(x_position = c(2, 6.2, 12, 16.2),
                              label = c("red states", "blue states"),
                              color = c("red", "blue"))
    geo_label <- data.table(x_position = c(4.1, 14.1),
                            label = c("All Area", 
                                      "Large Urban Area\npopulation > 50000"),
                            color = c("grey30", "grey30"))
    
    # disparity data table
    data_disparity_plot <- rbindlist(list(all_geo, UA)) %>%
        .[, .(red_blue, disparity_ratio, geo_component)] %>%
        .[, geo_component := factor(geo_component, levels = c("all area", "urbanized area"))] %>%
        setorder(geo_component, -red_blue) %>%
        .[, x_position := c(2, 6.2, 12, 16.2)] 
    
    # make plot ===
    ggplot(data_plot, aes(x_position, 9 * killed_per_million)) +
        geom_bar(stat = "identity", aes(color = red_blue, fill = race), size = 0.5, width = 1.9) +
        scale_fill_manual(values = c("black" = "gray70", "non-black" = "white")) +
        xlim(0, 18.5) +    # reduce x-axis so only show "all area" and "large urban area"
        ylim(-1.5, 43.2) +
        
        # add state label
        # geom_text(data = state_label, aes(x_position, y = -0.5, label = label, color = color),
        #           size = 3, lineheight = 0.7, vjust = 1) +
        # add geo label
        geom_text(data = geo_label, aes(x_position, y = 34, label = label, color = color), 
                  size = 3.5, vjust = 1, lineheight = 0.8) +
        # add black and non-black label
        geom_text(aes(x_position, 0.2, label = race, color = red_blue), size = 2.8, 
                  lineheight = 0.7, vjust = 0) +
        # add number label
        geom_text(aes(x = x_position, y = 9 * killed_per_million + 0.5, color = red_blue,
                      label = killed_per_million), vjust = 0, hjust = 0.5, size = 3) +
        scale_color_identity() +
        
        # add a vertical line to split all area and other areas
        annotate("segment", x = 9.1, xend = 9.1, y = 0, yend = 16, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 0, yend = 16, linetype = 2, size = 0.2) +
        
        # add a fake title
        annotate("text", x = 0, y = 19, size = 3.5, hjust = 0, parse = TRUE, color = "grey30",
                 label = 'bold("Number of fatal police shooting of unarmed civilians per million population of\nblack and non-black people")') +
        
        # add disparity ratio ===
        # magnify and move y axis for better contrast
        geom_line(data = data_disparity_plot, size = 1, color = "grey30",
                  aes(x = x_position, y = 2 * disparity_ratio + 19, group = geo_component)) +
        geom_point(data = data_disparity_plot, size = 3,
                   aes(x = x_position, y = 2 * disparity_ratio + 19, color = red_blue)) +
        geom_text(data = data_disparity_plot, size = 3, hjust = 1,
                  aes(x = x_position, y = 2 * disparity_ratio + 20, label = disparity_ratio, color = red_blue)) +
        annotate("segment", x = 9.1, xend = 9.1, y = 22, yend = 33, linetype = 2, size = 0.2) +
        annotate("segment", x = 18.6, xend = 18.6, y = 22, yend = 33, linetype = 2, size = 0.2) +
        
        # add title
        annotate("text", x = 0, y = 40.7, hjust = 0, size = 4.5, parse = TRUE,
                 label = 'bold("Fatal Police Shooting of unarmed civilians in       and         states\nsince 2015")') +
        # sad that geom_text not good at text color, have to di it this way
        annotate("text", x = 12.1, y = 43.15, hjust = 0, color = "red", size = 4.5, parse = TRUE,
                 label = 'bold("red")') +
        annotate("text", x = 14.3, y = 43.15, hjust = 0, color = "blue", size = 4.5, parse = TRUE,
                 label = 'bold("blue")') + 
        
        annotate("text", x = 0, y = 36, hjust = 0, lineheight = 0.9, size = 3.5, parse = TRUE, color = "grey30",
                 label = 'bold("How many times unarmed black people are as likely to be killed by police\nas non-black people")') +
        
        theme(plot.title = element_text(size = 10, face = "bold"),
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              axis.title = element_blank(),
              legend.position = "none",
              panel.grid = element_blank(),
              panel.background = element_blank(),
              plot.margin = unit(c(2, 0, -5, 0), "mm"))  # negative number set margin
    
    # save plot
    ggsave(filename = "figures_temp/geo_disparity_unarmed.png", width = 6.5, height = 5.5)
}


plot_gun_unarmed_disparity <- function() {
    ## This function plots the disparity ratios and numbers of shooting per million
    ## population side by side for grouped red and blue states in large urban area
    
    # prepare data ===
    UA_gun <- get_ratio_grouped_state("UA", "gun") %>%
        .[, weapon := "gun"]
    UA_unarmed <- get_ratio_grouped_state("UA", "unarmed") %>%
        .[, weapon := "unarmed"]

    data_plot <- rbindlist(list(UA_gun, UA_unarmed)) %>%
        # keep only needed columns
        .[, .(red_blue, black_killed_per_million, non_black_killed_per_million, weapon)] %>%
        # convert to long table for plot
        melt(measure.vars = c("black_killed_per_million", "non_black_killed_per_million"),
             variable.name = "race",
             value.name = "killed_per_million") %>%
        # change values in column "race"
        .[, race := ifelse(race == "black_killed_per_million", "black", "non-black")] %>%
        # reorder levels of weapon
        .[, weapon := factor(weapon, levels = c("gun", "unarmed"))] %>%
        # reorder rows 
        setorder(weapon, -red_blue, race) %>%
        # add new column for position
        .[, x_position := c(1, 3, 5.2, 7.2,       # with gun
                            11, 13, 15.2, 17.2)]  # unarmed
    
    # label data tables
    state_label <- data.table(x_position = c(2, 6.2, 12, 16.2),
                              label = c("red states", "blue states"),
                              color = c("red", "blue"))
    weapon_label <- data.table(x_position = c(4.1, 14.1),
                            label = c("armed with gun", 
                                      "unarmed"),
                            color = c("grey30", "grey30"))
    
    # disparity data table
    data_disparity_plot <- rbindlist(list(UA_gun, UA_unarmed)) %>%
        .[, .(red_blue, disparity_ratio, weapon)] %>%
        .[, weapon := factor(weapon, levels = c("gun", "unarmed"))] %>%
        setorder(weapon, -red_blue) %>%
        .[, x_position := c(2, 6.2, 12, 16.2)]
    
    # make plot ===
    ggplot(data_plot, aes(x_position, 1.8 * killed_per_million)) +
        geom_bar(stat = "identity", aes(color = red_blue, fill = race), size = 0.5, width = 1.9) +
        scale_fill_manual(values = c("black" = "gray70", "non-black" = "white")) +
        xlim(0, 18.5) +    # reduce x-axis so only show "all area" and "large urban area"
        ylim(-1.5, 48.2) +
        
        # add state label
        # geom_text(data = state_label, aes(x_position, y = -0.5, label = label, color = color),
        #           size = 3, lineheight = 0.7, vjust = 1) +
        # add weapon label
        geom_text(data = weapon_label, aes(x_position, y = 39, label = label, color = color), 
                  size = 3.5, vjust = 1, lineheight = 0.8) +
        # add black and non-black label
        geom_text(aes(x_position, 0.2, label = race, color = red_blue), size = 2.8, 
                  lineheight = 0.7, vjust = 0) +
        # add number label
        geom_text(aes(x = x_position, y = 1.8 * killed_per_million + 0.5, color = red_blue,
                      label = killed_per_million), vjust = 0, hjust = 0.5, size = 3) +
        scale_color_identity() +
        
        # add a vertical line to split weapon
        annotate("segment", x = 9.1, xend = 9.1, y = 0, yend = 20, linetype = 2, size = 0.2) +

        # add a fake title
        annotate("text", x = 0, y = 23, size = 3.5, hjust = 0, parse = TRUE, color = "grey30",
                 label = 'bold("Number of fatal police shooting per million population of black and non-black people")') +
        
        # add disparity ratio ===
        # magnify and move y axis for better contrast
        geom_line(data = data_disparity_plot, size = 1, color = "grey90",
                  aes(x = x_position, y = 2 * disparity_ratio + 25, group = weapon)) +
        geom_point(data = data_disparity_plot, size = 3,
                   aes(x = x_position, y = 2 * disparity_ratio + 25, color = red_blue)) +
        geom_text(data = data_disparity_plot, size = 3, hjust = 1,
                  aes(x = x_position, y = 2 * disparity_ratio + 26, label = disparity_ratio, color = red_blue)) +
        annotate("segment", x = 9.1, xend = 9.1, y = 26, yend = 37, linetype = 2, size = 0.2) +

        # add title
        annotate("text", x = 0, y = 46, hjust = 0, size = 4.5, parse = TRUE,
                 label = 'bold("Fatal Police Shooting of civilians armed with gun or unarmed\nin       and         states large urban areas since 2015")') +
        # sad that geom_text not good at text color, have to di it this way
        annotate("text", x = 0.6, y = 46.15, hjust = 0, color = "red", size = 4.5, parse = TRUE,
                 label = 'bold("red")') +
        annotate("text", x = 2.8, y = 46.15, hjust = 0, color = "blue", size = 4.5, parse = TRUE,
                 label = 'bold("blue")') + 
        
        annotate("text", x = 0, y = 41, hjust = 0, lineheight = 0.9, size = 3.5, parse = TRUE, color = "grey30",
                 label = 'bold("How many times black people are as likely to be killed by police as non-black people")') +
        
        theme(plot.title = element_text(size = 10, face = "bold"),
              axis.text = element_blank(),
              axis.ticks = element_blank(),
              axis.title = element_blank(),
              legend.position = "none",
              panel.grid = element_blank(),
              panel.background = element_blank(),
              plot.margin = unit(c(2, 0, -5, 0), "mm"))  # negative number set margin
    
    # save plot
    ggsave(filename = "figures_temp/weapon_disparity_gun_unarmed.png", width = 6.5, height = 5.5)
}
    
