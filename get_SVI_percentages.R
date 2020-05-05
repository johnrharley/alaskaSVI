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