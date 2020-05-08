# this script will get Census data for Alaska at multiple levels

# 
library(tidyverse)
library(tidycensus)
library(viridis)
library(tigris)
library(sp)
library(rlang)
#API key for queries
# census_api_key("7a77f79ad2c390fcef9156197ac6c1b32e78a1fb", install = TRUE)

# get shapefiles for place level in Alaska
ak_places <- tigris::places(state="AK")
# shapefiles for block groups in Alaska
ak_blocks <- tigris::block_groups(state="AK")
# shapefiles for county level in Alaska
ak_counties <- tigris::counties(state="AK")

#load all available variables for acs 5-year, ending in 2018

# set geographies to include in ACS API calls

##############


###### block group ######

# note that Data Profile (prefix "DP") tables are not available on the census block level.
# That being said, almost all of these values are available from detailed tables ("B" prefix) 
# Values here are *almost* exactly the same, with the two exception being "SNGPNT", or the estimate of the 
# nuber of single parent households:
# This metric, as far as I can tell, is not available in the detailed tables. However there is another
# metric which I think is actually superior, which is very similar. The number of households with children 
# under 18 with a single parent but *without* the qualifaction that it has to be "own children". This to
# me is a more accurate metric for the number of single parent households.

# The second metric is the percentage of disabled persons




SVI <- read.csv("SVI_BlockGroup.csv", stringsAsFactors = F)

get_SVI_values <- function(SVI, geography, state) {

  SVI %>%
    filter(Statistic == "Value") %>%
    filter(str_detect(Variables, pattern = ",")) -> VarsToParse
  # extract single variable values using get_acs()
  SVI %>%
    filter(Parse_Eqs == "Single") %>%
    filter(Statistic == "Value") -> single_variables
  
  acs_data <- get_acs(geography = geography, state=state, variables = single_variables$Variables, output="wide") 
  
  # extract metadata for naming variables to be consistent with CDC SVI
  SVI %>%
    filter(Statistic == "Value") %>%
    select(Variables, Names) %>%
    mutate(value = "E", error= "M") %>%
    pivot_longer(-c(Variables,Names), names_to = "value", values_to = "prefix") %>%
    mutate(variable_code = paste0(Variables, prefix), variable_name = paste(prefix, Names, sep="_")) %>% 
    left_join(SVI, by=c("Variables", "Names")) %>%
    select(Variables, variable_code, Domain, Description, variable_name) -> metadata
  
  # reset column names to SVI specifications
  replacementNames <- as.vector(metadata$variable_name[match(names(acs_data), metadata$variable_code)])
  colnames(acs_data) <- ifelse(is.na(replacementNames), colnames(acs_data), replacementNames)
    
  # this next section uses variables that have summary equations (are not a single table variable) 
  if(length(VarsToParse) > 0) {
    # pulls all variables necessary to create calculations from parsed equations
    str_split(VarsToParse$Variables, pattern =", ", simplify =F) %>%
      compact() %>%
      unlist() %>%
      str_replace_all(" ", "") -> parsed_vars
    
    # extract data for parsed_vars 
    parsed_data <- get_acs(geography = geography, state=state, variables = parsed_vars, output="wide")
    # this function will calculate statistics based on the equations present in Parse_Eqs colunm
    # //todo: figure out how to vectorize this, using rowwise?
    calculate_variables <- function() {    
      calculated_estimates <- list()
      calculated_moes <- list()
      GEOIDS <- select(parsed_data, GEOID)
        for(i in 1:nrow(VarsToParse)) {  
          estName <- paste0("E_",VarsToParse$Names[i])
            # calculate estimate
            parsed_data  %>%
              mutate(!!estName := pmap_dbl(list(!!!parse_exprs(VarsToParse$Parse_Eqs[i])), sum)) %>%
              select(!!estName) -> calculated_estimates[[i]]
            # calculate moe
          moeName <- paste0("M_",VarsToParse$Names[i])
            parsed_data %>%
              mutate(!!moeName := pmap_dbl(list(!!!parse_exprs(VarsToParse$MOE[i])), sum)) %>%
              select(!!moeName) -> calculated_moes[[i]]
        } 
      bind_cols(GEOIDS, calculated_estimates, calculated_moes) %>% 
        return()
    }
    calculated_df <- calculate_variables()
          } else {
              message("no variables to parse") # in case there aren't any equations to parse
          }
          if(exists(x = "calculated_df")) {
            inner_join(acs_data, calculated_df, by="GEOID") %>% # join and return
              return() 
      } else {
          return(acs_data) 
    }
}

SVI_values <- get_SVI_values(SVI, geography = "block group", state="AK")

get_SVI_percentages <- function(SVI, SVI_values, geography, state) {

  SVI %>%
    filter(Parse_Eqs != "Single") %>%
    filter(Statistic == "Percentage")  -> VarsToParse
  # extract single variable values using get_acs()
  SVI %>%
    filter(Parse_Eqs == "Single") %>%
    filter(Statistic == "Percentage") -> single_variables
  
  acs_data <- get_acs(geography = geography, state=state, variables = single_variables$Variables, output="wide") 
  
  SVI %>%
    filter(Statistic == "Percentage") %>%
    select(Variables, Names) %>%
    mutate(value = "E", error= "M") %>%
    pivot_longer(-c(Variables,Names), names_to = "value", values_to = "prefix") %>%
    mutate(variable_code = paste0(Variables, prefix), variable_name = paste(prefix, Names, sep="")) %>% 
    left_join(SVI, by=c("Variables", "Names")) %>%
    select(Variables, variable_code, Domain, Description, variable_name) -> metadata

  replacementNames <- as.vector(metadata$variable_name[match(names(acs_data), metadata$variable_code)])
  colnames(acs_data) <- ifelse(is.na(replacementNames), colnames(acs_data), replacementNames)
  
  acs_data %>%
    right_join(SVI_values, by=c("GEOID", "NAME")) -> base_data
  
  # parse multi-variable equations
  if(length(VarsToParse) > 0) {
    # pulls all variables necessary to create calculations from parsed equations
    str_split(VarsToParse$Variables, pattern =", ", simplify =F) %>%
      compact() %>%
      unlist()-> parsed_vars
    
    # extract data for parsed_vars 
    parsed_data <- get_acs(geography = geography, state=state, variables = parsed_vars, output="wide")
    
    parsed_data %>%
      left_join(base_data, by=c("GEOID","NAME")) -> dataforCalculations

    calculate_variables <- function() {    
      calculated_estimates <- list()
      calculated_moes <- list()
      GEOIDS <- select(parsed_data, GEOID)
      for(i in 1:nrow(VarsToParse)) {  
        estName <- paste0("E",VarsToParse$Names[i])
        # calculate estimate
        dataforCalculations  %>%
          mutate(!!estName := pmap_dbl(list(!!!parse_exprs(VarsToParse$Parse_Eqs[i])), sum)) %>%
          select(!!estName) -> calculated_estimates[[i]]
      }
      bind_cols(dataforCalculations, calculated_estimates) -> toMOEcalculations
      # calculate moe 
      for(i in 1:nrow(VarsToParse)) {  
        moeName <- paste0("M",VarsToParse$Names[i])
        toMOEcalculations %>%
          mutate(!!moeName := pmap_dbl(list(!!!parse_exprs(VarsToParse$MOE[i])), sum)) %>%
          select(!!moeName) -> calculated_moes[[i]]
      } 
      bind_cols(GEOIDS, calculated_estimates, calculated_moes) %>% 
        return()
    }
    calculated_percentages <- calculate_variables()
  } else {
    message("no variables to parse") 
  }
  if(exists(x = "calculated_percentages")) {
    inner_join(acs_data, calculated_percentages, by="GEOID") %>%
      return() 
  } else {
    return(acs_data)
  }
}

SVI_percentages <- get_SVI_percentages(SVI, SVI_values = SVI_values, geography = "block group", state="AK")

#### rankings ####

SVI_rankings <- function(SVI_values, SVI_percentages) {
    ValuesAndPercentages <- bind_cols(SVI_values, SVI_percentages)
    # generate population groups for percentile rankings
    ValuesAndPercentages$POP_GROUP <- cut(ValuesAndPercentages$E_TOTPOP, breaks = c(-Inf, 1, 10, 100, 1000, Inf),
                                      labels=c("Unoccupied", "10 or less persons", "10-100 persons", "100-1,000 persons", "More than 1,000 persons"))
  # note that the calculation for PCI (per capita income) is different than other metrics, since higher per capita
    # incomes are "better", so we take the inverse
    
    ValuesAndPercentages %>%
      group_by(POP_GROUP) %>%
      select(-starts_with("MP_")) %>%
      rename_at(vars(starts_with("EP_")), function(x) gsub('^(.{2})(.*)$', '\\1L\\2', x)) %>%
      mutate_if(is.numeric,list(percent_rank)) %>%
      mutate(EPL_PCI = 1-EPL_PCI) %>% # this calculation is the inverse since higher income is better (see CDC explanation)
      select(GEOID, starts_with("EPL_")) -> percentageRankings
    
    percentageRankings %>%
      pivot_longer(-c(POP_GROUP, GEOID), values_to = "PERCENTILE_RANK", names_to = "Variable") ->  toMerge
    
    percentageRankings %>%
      group_by(POP_GROUP) %>%
      mutate(SPL_THEME1 = sum(EPL_PCI,EPL_POV,EPL_NOHSDP,EPL_UNEMP, na.rm = TRUE)) %>%
        mutate(RPL_THEME1 = percent_rank(SPL_THEME1)) %>% # generate summary for theme 1
      mutate(SPL_THEME2 = sum(EPL_AGE65, EPL_AGE17, EPL_DISABL, EPL_SNGPNT, na.rm = TRUE)) %>%
        mutate(RPL_THEME2 = percent_rank(SPL_THEME2)) %>% # generate summary for theme 2
      mutate(SPL_THEME3 = sum(EPL_MINRTY, EPL_LIMENG, na.rm = TRUE)) %>%
        mutate(RPL_THEME3 = percent_rank(SPL_THEME3)) %>% # generate summary for theme 3
      mutate(SPL_THEME4 =  sum(EPL_MUNIT, EPL_MOBILE, EPL_CROWD, EPL_NOVEH, EPL_GROUPQ, na.rm = TRUE)) %>%
        mutate(RPL_THEME4 = percent_rank(SPL_THEME4)) %>% # generate summary for theme 4
      mutate(SPL_THEMES = sum(SPL_THEME1, SPL_THEME2,SPL_THEME3, SPL_THEME4, na.rm = TRUE)) %>%
        mutate(RPL_THEMES = percent_rank(SPL_THEMES)) %>% # generate overall summary themes
      return()
      
}

SVI_rankings <- SVI_rankings(SVI_percentages = SVI_percentages, SVI_values = SVI_values)

SVI_flags <- function(SVI_rankings) {

  SVI_rankings %>%
    rename_at(vars(starts_with("EPL_")), function(x) gsub('EPL_', 'F_', x)) %>%
    mutate_if(is.numeric, function(x) ifelse(x > 0.9, 1, 0)) %>%
    rowwise() %>%
    mutate(F_THEME1 = sum(F_PCI, F_POV, F_NOHSDP, F_UNEMP, na.rm = TRUE)) %>%
    mutate(F_THEME2 = sum(F_AGE65, F_AGE17, F_DISABL, F_SNGPNT, na.rm = TRUE)) %>%
    mutate(F_THEME3 = sum(F_MINRTY, F_LIMENG, na.rm = TRUE)) %>%
    mutate(F_THEME4 = sum(F_MUNIT, F_MOBILE,  F_CROWD, F_NOVEH, F_GROUPQ, na.rm = TRUE)) %>%
    mutate(F_THEMES = sum(F_THEME1, F_THEME2, F_THEME3, F_THEME4, na.rm = TRUE)) %>%
    ungroup() %>%
    select(GEOID, starts_with("F_")) %>%
    return() 
}

SVI_flags <- SVI_flags(SVI_rankings = SVI_rankings)

# finally merge all of the data

SVI_values %>%
  inner_join(SVI_percentages) %>%
  inner_join(SVI_rankings) %>%
  inner_join(SVI_flags) -> SVI_DATA

geo_data <- geo_join(ak_blocks, SVI_DATA, by = "GEOID")

rgdal::writeOGR(dsn = "ak_regions.json", obj=geo_data, layer="counties", driver="GeoJSON")
