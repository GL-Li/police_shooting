# More discrimination against black people by police officers in blue states? 
This project is to analyze the [Washington Post database](https://github.com/washingtonpost/data-police-shootings) of civilians shot and killed by on-duty police officers in the United States in year 2015 and 2016. 

## Summary
Over 1000 civilians are fatally shot by police officers each year in the United States. Black people are more than twice as likely to to killed as non-black people. Racism is often blamed for this disparity. 

If racism does play a role, we would expect smaller disparity in blue states than in red states, as black people are believed to face less discrimination in blue states. 

Surprisingly, the analysis of the Washington Post shooting data shows that the disparity is twice as large in blue states as in red states. If we use the disparity as a measure of racism, blue states are more discriminative against black people than red states. 


## Disparity in red states and blue states as two groups

We divide the 50 states and DC into two groups, blue states and red states, using the 2012 presidential election data. As Obama is a black people, this data better represents racial issues than the most recent 2016 election data. A state is a blue state if 50% or more voted for Obama, a red state otherwise. We use 50% vote as the criteria instead of Obama winning because all other candidates are non-blacks. 

The disparity ratio and number of fatal police shooting per million population in the two groups are calcualted using the Washington Post database. The disparity ratio is defined as the ratio of the number of the fatal police shooting per million population of black people to that of non-black people.

The disparity ratio is much higher in blue state than in red state. In red states, black people are <span style="color:red">**1.68**</span> times as likely to be killed by police as non-black people. The disparity ratio doubles to <span style="color:blue">**3.26**</span> in blue states. The larger disparity in blue states is partly due to black people is more likely to be killed, but mainly accounted for by less likely non-black people being fatally shot per million population by police. The likelyhood of blacks being killed is 13.59 per million popultion in blue state, 20% larger than that in red state (11.32 per million). The likelyhood of non-black people being killed is 6.73 per million in red states, 61% higher than the 4.17 per million in blue states. 

One argues that higher disparity in blue states could be result of higher urbanization rate in blue states. Generally speaking, black people tend to live in large urban area in blue states where police are more likely to shoot. A fair comparison should compare the disparity in large urban area in red and blue states.

In large urban area with more than 50000 population, which accounts for 92% of black people killed, the disparity ratio is <span style="color:red">**1.94**</span> in red states and <span style="color:blue">**3.07**</span> in blue states. Almost all the difference is attributed to the fewer non-black people being killed in blue states (4.49 per million) than in red states (7.25 per million). Black people are equal likely to be killed in both blue states and red states in large urban area. 

<img src="figures/geo_disparity_vertical.png" alt="disparity ratio" style="width: 600px;"/>

## Disparity in individual states (large urban area only, move all state to appendix)
After treating red and blues states in two groups, let's look the disparity in individual states. We will pay attention to significant states with more than 300,000 black population, or with more than 3 black people killed by police. 

(check all numbers after database update) The following figure clearly shows larger disparity in blue states. The bluer a state is, the larger the disparity. While Obama got 90% vote in DC, all 8 killed by police are blacks. (all disparity ratios are capped at 10 to be plot in the figure) Among the traditional blue states, Illinois tops the list where the blacks are 7.6 times as likely as non-blacks to be killed. Massachusetts is 5.2 times, and New York 5.3 time. California is the best but still 3.0 times, higher than the national average, which is 2.2 times (use large urban average). On the other hand, all those below the national average are red states, including Texas, Alabama, Mississippi, and Tennessee. In particular, the blacks are only 61% as likely as non-blacks to be killed by police in Mississippi.

<img src="figures/disparity_vote_UA.png" alt="disparity ratio all area" style="width: 800px;"/>


## Data preparation