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
