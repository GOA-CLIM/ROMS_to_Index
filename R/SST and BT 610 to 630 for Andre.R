# Alberto Rovellini and Grant Adams
# Derive indices on average surface and bottom temperature for NMFS mgmt areas 610 to 630 between February and April
# Using ROMS NEP subset to the 300 m isocline

pacman::p_load(mgcv, dplyr, lubridate, ggplot2, tidyr, sf, tidyverse)
source("R/Delta_correction.R")

# ------------------------------------------
# CALCULATE AREA PER NMFS MGMT AREA
# ------------------------------------------
nmfs <- st_read('Data/Depth trimmed NMFS shapefiles 300m/NMFS610-650.shp')
areas <- nmfs %>% rowwise() %>% mutate(areas = st_area(geometry)) %>% ungroup()

# area 650 for the 300 m mask is split into two, due to a deep channel. Combine it.
areas <- areas %>% group_by(NMFS_AREA) %>% summarise(geometry = st_union(geometry), areas = sum(areas))

# areas m^2 of 0-300 m shelf by NMFS area
# 610 57225003746
# 620 62597059226
# 630 98582220025
# 640 32560976631
# 650 36726651409

# areas m^2 of 0-1000 m shelf by NMFS area
# 610 63986698621 [m^2]
# 620 69583703140 [m^2]
# 630 105918077937 [m^2]
# 640 37270389681 [m^2]
# 650 43952466109 [m^2]


# ------------------------------------------
# Load data averaged across depth and strata
# ------------------------------------------
nep_hind <- read.csv("Data/NEP_10k_revised_indices/nep_avg_hind_300.csv")
nep_hind$simulation = "hindcast"

nep_hist <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_hist_300.csv")
nep_hist$simulation = "historical"

nep_ssp126 <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_ssp126_300.csv")
nep_ssp126$simulation = "ssp126"

nep_ssp245 <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_ssp245_300.csv")
nep_ssp245$simulation = "ssp245"

nep_ssp585 <- read.csv("Data/NEP_10k_revised_indices/nep_avg_wb_ssp585_300.csv")
nep_ssp585$simulation = "ssp585"

# Combine in list
roms_avg_data <- do.call(rbind, list(nep_hind, nep_hist, nep_ssp126, nep_ssp245, nep_ssp585))

# Add time and date information
roms_avg_data <- roms_avg_data %>%
  mutate(
    date = lubridate::as_date(date),
    month = lubridate::month(date),
    year = lubridate::year(date))


# ---------------------------------------------------------
# Run bias correction for all variables  (hind and no hind)
# ---------------------------------------------------------
# - - 1) NO HINDCAST SPLICED IN
# - SSP126
ssp126_biascorrected_nohind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp126"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = FALSE)

# - SPP245
ssp245_biascorrected_nohind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp245"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = FALSE)

# - SSP585
ssp585_biascorrected_nohind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp585"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = FALSE)

# - - 2) HINDCAST SPLICED IN
# - SSP126
ssp126_biascorrected_hind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp126"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = TRUE) # Splice hindcast in

# - SSP245
ssp245_biascorrected_hind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp245"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = TRUE) # Splice hindcast in

# - SSP585
ssp585_biascorrected_hind <- delta_correction(
  hindcast = roms_avg_data %>% filter(simulation == "hindcast"),
  historical = roms_avg_data %>% filter(simulation == "historical"),
  projection = roms_avg_data %>% filter(simulation == "ssp585"),
  ref_yrs = 2000:2014, # Overlap years for historical and hindcast ROMS
  lognormal = FALSE,
  include_hindcast = TRUE) # Splice hindcast in


# - Plot differences between the bias-corrected and raw runs
ssp585_biascorrected_nohind %>%
  select(-unit, -value) %>%
  left_join(nep_ssp585 %>%
              mutate(year = year(date), month = month(date)) %>%
              select(NMFS_AREA, depthclass, value, varname, year, month),
            by = c('NMFS_AREA', 'depthclass', 'varname', 'year', 'month')) %>%
  filter(between(year, 2020, 2036)) %>%
  select(-year, -month) %>%
  pivot_longer(c(value, value_dc)) %>%
  filter(varname == 'temp' & depthclass %in% c('Surface', 'Bottom') & NMFS_AREA == 610) %>%
  ggplot(aes(x = date, y = value, color = name))+
  geom_line()+
  geom_point()+
  theme_bw()+
  facet_wrap(depthclass~NMFS_AREA)


# Extract variables we want
# ---------------------------------------
# Surface and bottom temperature
# ---------------------------------------
# -- 1) No hindcast
goa_temp_ssp126_nohind <- ssp126_biascorrected_nohind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom") & NMFS_AREA %in% c("610", "620", "630")) %>%
  mutate(simulation = "ssp126") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_ssp245_nohind <- ssp245_biascorrected_nohind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom") & NMFS_AREA %in% c("610", "620", "630")) %>%
  mutate(simulation = "ssp245") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_ssp585_nohind <- ssp585_biascorrected_nohind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom")  & NMFS_AREA %in% c("610", "620", "630")) %>% 
  mutate(simulation = "ssp585") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_610_to_630_nohind <- rbind(goa_temp_ssp126_nohind, goa_temp_ssp245_nohind, goa_temp_ssp585_nohind)
goa_temp_610_to_630_nohind <- goa_temp_610_to_630_nohind %>% mutate(hind = 'no')


# -- 2) Including hindcast
goa_temp_ssp126_hind <- ssp126_biascorrected_hind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom") & NMFS_AREA %in% c("610", "620", "630")) %>%
  mutate(simulation = "ssp126") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_ssp245_hind <- ssp245_biascorrected_hind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom") & NMFS_AREA %in% c("610", "620", "630")) %>%
  mutate(simulation = "ssp245") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_ssp585_hind <- ssp585_biascorrected_hind %>%
  filter(varname == "temp" & depthclass %in% c("Surface", "Bottom") & NMFS_AREA %in% c("610", "620", "630")) %>% 
  mutate(simulation = "ssp585") %>%
  pivot_wider(values_from = c(value_dc, value), names_from = NMFS_AREA) %>%
  mutate(value_dc_610_to_630 = (value_dc_610 * 57225003746 + value_dc_620 * 62597059226 + value_dc_630 * 98582220025) / (57225003746 + 62597059226 + 98582220025)) # Take area weighted mean

goa_temp_610_to_630_hind <- rbind(goa_temp_ssp126_hind, goa_temp_ssp245_hind, goa_temp_ssp585_hind)
goa_temp_610_to_630_hind <- goa_temp_610_to_630_hind %>% mutate(hind = 'yes')


# -- Combine and plot
goa_temp_610_to_630 <- rbind(goa_temp_610_to_630_hind, goa_temp_610_to_630_nohind)

ggplot(goa_temp_610_to_630, aes(date, value_dc_610_to_630, colour = simulation)) + geom_line() +
  ylab("SST (Celsius)") + xlab("Year") + facet_wrap(~simulation + hind + depthclass)

goa_temp_610_to_630 <- goa_temp_610_to_630 %>%
  arrange(depthclass, simulation, hind, year, month) %>%
  relocate(hind, .before = varname) %>%
  relocate(simulation, .before = varname)

write.csv(goa_temp_610_to_630 %>%
            filter(hind == "yes"), 'Output/goa_temperature_610_to_630_300m.csv', row.names = F)


# ---------------------------------------
# Calc mean feb to april temperature
# ---------------------------------------
goa_temp_610_to_630_FebApril <- goa_temp_610_to_630 %>%
  filter(month %in% c(2:4)) %>%
  group_by(year, depthclass, varname, simulation, hind) %>%
  summarise(mean_value_dc_610_to_630 = mean(value_dc_610_to_630)) %>% 
  mutate(varname = "Mean temp Feb to April") %>%
  arrange(depthclass, simulation, hind, year) %>%
  select(depthclass, hind, simulation, varname, year, mean_value_dc_610_to_630)

# -- Plot
ggplot(goa_temp_610_to_630_FebApril %>% filter(depthclass == "Surface"), aes(year, mean_value_dc_610_to_630, colour = simulation)) + 
  geom_line() +
  ylab("SST (Celsius)") + 
  xlab("Year") + 
  facet_wrap(~simulation + hind)

ggplot(goa_temp_610_to_630_FebApril %>% filter(depthclass == "Bottom"), aes(year, mean_value_dc_610_to_630, colour = simulation)) + 
  geom_line() +
  ylab("Bottom temp (Celsius)") + 
  xlab("Year") + 
  facet_wrap(~simulation + hind)

# -- Save
write.csv(goa_temp_610_to_630_FebApril %>%
            filter(hind == "yes"), 'Output/goa_temp_610_to_630_summer_300M.csv', row.names = F)

