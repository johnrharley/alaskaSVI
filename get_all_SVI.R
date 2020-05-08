get_all_SVI <- function(state = "AK", geography = "block group") {
  sapply(list("get_SVI_values.R", "get_SVI_percentages.R", "SVI_flags.R", "SVI_rankings.R"), source, .GlobalEnv)
  if(geography == "block group") {
    
    SVI_BlockGroup <- read.csv("./data/SVI_BlockGroup.csv", stringsAsFactors = F)
    #### raw values (total population, median income, etc)
    
    SVI_values <- get_SVI_values(SVI_BlockGroup, geography = geography, state=state)
    
    #### percentage (percent unemployed, percent single parent, etc)
    
    SVI_percentages <- get_SVI_percentages(SVI_BlockGroup, SVI_values = SVI_values, geography = geography, state=state)
    
    #### rankings (percent rankings for each variable)
    
    SVI_rankings <- SVI_rankings(SVI_percentages = SVI_percentages, SVI_values = SVI_values)
    
    #### flags (returns a flag if the GEOID is in the 90th percentile)
    
    SVI_flags <- SVI_flags(SVI_rankings = SVI_rankings)
    
    # finally merge all of the data
    
    SVI_values %>%
      inner_join(SVI_percentages) %>%
      inner_join(SVI_rankings) %>%
      inner_join(SVI_flags) -> SVI_DATA
    
    # get spatial data for block groups (or whatever geometry)
    return(SVI_DATA)
  } else {
    
    traditionalSVI <- read.csv("./data/SVI_Variables.csv", stringsAsFactors = F)
    
    SVI_values <- get_SVI_values(traditionalSVI, geography = geography, state=state)
    
    #### percentage (percent unemployed, percent single parent, etc)
    
    SVI_percentages <- get_SVI_percentages(traditionalSVI, SVI_values = SVI_values, geography = geography, state=state)
    
    #### rankings (percent rankings for each variable)
    
    SVI_rankings <- SVI_rankings(SVI_percentages = SVI_percentages, SVI_values = SVI_values)
    
    #### flags (returns a flag if the GEOID is in the 90th percentile)
    
    SVI_flags <- SVI_flags(SVI_rankings = SVI_rankings)
    
    # finally merge all of the data
    
    SVI_values %>%
      inner_join(SVI_percentages) %>%
      inner_join(SVI_rankings) %>%
      inner_join(SVI_flags) -> SVI_DATA
    
    
  } 
  return(SVI_DATA)
}
