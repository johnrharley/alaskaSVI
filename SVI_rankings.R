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
