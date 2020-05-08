# this script will get Census data for Alaska at multiple levels

require(tidyverse)
require(tidycensus)
require(sp)
require(rlang)
#API key for queries, you will need to get your own
census_api_key(key = Sys.getenv("CENSUS_API_KEY"), install = TRUE)

source(c("get_SVI_values.R","get_SVI_percentages.R", "SVI_rankings.R", "SVI_flags.R"))

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

# The second metric is the percentage of disabled persons. The main difference here is that in the modified calculation it is 
# not including persons under the age of 16 (out of the work force). Otherwise it is the same calculation.

traditionalSVI <- read.csv("./data/SVI_Variables.csv", stringsAsFactors = F)

SVI_BlockGroup <- read.csv("./data/SVI_BlockGroup.csv", stringsAsFactors = F)

#### raw values (total population, median income, etc)

SVI_values <- get_SVI_values(SVI, geography = "block group", state="AK")

#### percentage (percent unemployed, percent single parent, etc)

SVI_percentages <- get_SVI_percentages(SVI, SVI_values = SVI_values, geography = "block group", state="AK")

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

ak_blocks <- tigris::block_groups(state="AK")

# join geo data to SVI data

geo_data <- tigris::geo_join(ak_blocks, SVI_DATA, by = "GEOID")

# write the summary file to a geoJSON for visualization

rgdal::writeOGR(dsn = "ak_regions.json", obj=geo_data, layer="counties", driver="GeoJSON")
