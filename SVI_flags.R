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
