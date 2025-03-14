# install.packages("pacman")
pacman::p_load(mgcv, dplyr, lubridate, ggplot2, tidyr)

# Load data averaged across depth and strata
nep_hind <- read.csv("Data/NEP_10k_revised_indices/nep_avg_hind.csv")
nep_hind$simulation = "hindcast"

nep_hist <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_hist.csv")
nep_hist$simulation = "historical"

nep_ssp126 <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_ssp126.csv")
nep_ssp126$simulation = "ssp126"

nep_585 <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_ssp585.csv")
nep_585$simulation = "ssp585"

# Combine in list
roms_avg_data <- do.call(rbind, list(nep_hind, nep_hist, nep_ssp126, nep_585))

# Add time and date information
roms_avg_data <- roms_avg_data %>%
  mutate(
    date = lubridate::as_date(date),
    month = lubridate::month(date),
    year = lubridate::year(date))


### Monthly SST comparison
# Create subset of what we are interested in
sst610 <- roms_avg_data %>% 
  filter(depthclass == "Surface" & NMFS_AREA == "610" & varname == "temp")

# Plot 1
ggplot(sst610, aes(date, value, colour = simulation)) + 
  geom_line() + 
  ylab("Monthly 610 SST (celcius)") + 
  xlab("Year")

# Plot 2
ggplot(sst610, aes(date, value, colour = simulation)) + 
  geom_line() + 
  ylab("Monthly 610 SST (celcius)") + 
  xlab("Year") +
  facet_wrap(~simulation)


### Summer SST comparison
# Take monthlies and average from SSP126
summersst610 <- roms_avg_data %>% 
  filter(depthclass == "Surface" & NMFS_AREA == "610" & varname == "temp") %>%
  mutate(season = case_when(
    month %in% c(3,4,5) ~ "spring",
    month %in% c(11,12,1,2) ~ "winter",
    month %in% c(6,7,8) ~ "summer",
    month %in% c(9,10) ~ "fall",
  )) %>%
  filter(season == "summer") %>%
  group_by(NMFS_AREA, simulation, year, season) %>%
  summarise(value = mean(value))

# Plot 1
ggplot(summersst610, aes(year, value, colour = simulation)) + 
  geom_line() + 
  ylab("Summer 610 SST (celcius)") + 
  xlab("Year")

# Plot 2
ggplot(summersst610, aes(year, value, colour = simulation)) + 
  geom_line() + 
  ylab("Summer 610 SST (celcius)") + 
  xlab("Year") +
  facet_wrap(~simulation)
