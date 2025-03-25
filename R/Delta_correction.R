#' Function to run delta correction on data
#'
#' @param hindcast hindcast time series
#' @param historical historical time series
#' @param projection projection time series
#' @param ref_yrs reference years for the delta correction
#' @param lognormal do the delta-correction on the log scale (TRUE/FALSE)
#' @param use_sd use the ratio of the sd in the delta-correction (TRUE/FALSE)
#' @param include_hindcast use the hindcast in the output (TRUE/FALSE)
#'
#' @return
#' @export
#'
#' @examples
delta_correction <- function(
    hindcast = hnd,
    historical = hist,
    projection = fut,
    ref_yrs = 1990:2014,
    lognormal = FALSE,
    use_sd = FALSE,
    include_hindcast = FALSE){
  
  # Convert to log
  if(lognormal){
    projection$value = log(projection$value)
    historical$value = log(historical$value)
    hindcast$value = log(hindcast$value)
  }
  
  # Get mean and var for each month/ROMS across years
  # - historical
  goa_clim_hist <- historical %>% 
    dplyr::filter(year %in% ref_yrs) %>%
    dplyr::group_by(month, varname, depthclass, NMFS_AREA) %>%
    dplyr::summarize(mean_hist = mean( value,na.rm=T),
                     sd_hist = sd( value, na.rm = T))
  
  # - hindcast
  goa_clim_hind <- hindcast %>% 
    dplyr::filter(year %in% ref_yrs) %>%
    dplyr::group_by(month, varname, depthclass, NMFS_AREA) %>%
    dplyr::summarize(mean_hind = mean( value,na.rm=T),
                     sd_hind = sd( value, na.rm = T))
  
  
  # calculate index using delta correction for projection
  # - Merge projection with hist and hind summary statistics 
  projection <- Reduce(function(x, y) merge(x, y, all=TRUE, by = c("month", "varname", "depthclass", "NMFS_AREA")), 
                       list(projection, goa_clim_hist, goa_clim_hind)) %>%
    arrange(varname, year, month)
  
  # - Merge historical run with hist and hind summary statistics 
  historical <- Reduce(function(x, y) merge(x, y, all=TRUE, by = c("month", "varname", "depthclass", "NMFS_AREA")), 
                       list(historical, goa_clim_hist, goa_clim_hind)) %>%
    arrange(varname, year, month)
  
  # - Calculate index
  if(!lognormal){
    # Projection
    if(use_sd){
      
      # - Delta-correct using ratio of SD
      projection <- projection %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc = mean_hind + (sd_hind/sd_hist * (value - mean_hist))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    } else {
      
      # - Delta-correct NOT using ratio of SD
      projection <- projection %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc = mean_hind + ((value - mean_hist))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    }
    
    # Historical
    if(use_sd){
      
      # - Delta-correct using ratio of SD
      historical <- historical %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc = mean_hind + (sd_hind/sd_hist * (value - mean_hist))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    } else {
      
      # - Delta-correct NOT using ratio of SD
      historical <- historical %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc = mean_hind + ((value - mean_hist))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    }
  }
  
  if(lognormal){
    
    if(use_sd){
      
      # - Delta-correct using ratio of SD
      projection <- projection %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc =  exp(mean_hind + (sd_hind/sd_hist * (log(value) - mean_hist)))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    } else {
      
      # - Delta-correct NOT using ratio of SD
      historical <- historical %>%
        group_by(month, varname, depthclass, NMFS_AREA) %>%
        mutate(value_dc =  exp(mean_hind + ((log(value) - mean_hist)))) %>%
        ungroup() %>% arrange(year, month) %>%
        select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    }
    
    # Back transform historical and projection and hindcast
    historical$value = exp(historical$value)
    projection$value = exp(projection$value)
    hindcast$value = exp(hindcast$value)
  }
  
  # - Combine time series
  # two options:
  # 1: historical + projection
  # 2: historical (<1990) + hindcast (1990-2020) + projection (>2020)
  
  if(!include_hindcast){
    
    full_time_series <- rbind(projection, historical) %>% 
      arrange(year,month)
    
  } else {
    
    hindcast <- hindcast %>%
      arrange(year,month) %>%
      mutate(value_dc = value) %>%
      select(NMFS_AREA, depthclass, varname, year, month, date, value, value_dc, unit)
    
    full_time_series <- rbind(projection %>% filter(year > max(hindcast$year)), 
                              historical %>% filter(year < min(hindcast$year)), 
                              hindcast) %>% 
      arrange(year,month)
    
  }
  
  return(full_time_series)
}