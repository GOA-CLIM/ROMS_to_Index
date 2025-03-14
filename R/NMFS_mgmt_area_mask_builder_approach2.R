pacman::p_load(dplyr, sf, raster, devtools, ggplot2)
select <- dplyr::select


## Read data
nmfs <- st_read("Data/NMFS management area shapefiles/gf95_nmfs.shp")
nmfs <- nmfs %>% filter(NMFS_AREA %in% c(610,620,630,640,650)) %>% # subset to 610-650
  filter(GF95_NMFS1 %in% c(186,194,259,585,870)) # Removes inter-coastal in SE AK
etopo <- raster("Data/ETOPO1_Bed_c_gdal.grd/ETOPO1_Bed_c_gdal.grd")


# Crop depth raster to GOA extent
nmfs_mask <- nmfs %>% st_transform(crs = 4326) %>% st_bbox() %>% extent() # get extent in 4326
etopo_goa <-  etopo <- crop(etopo, nmfs_mask) # resize the raster to the study area

# Set depths > 1000 to NA
etopo_goa[etopo_goa < -1000] <- NA
etopo_goa[etopo_goa > 0] <- NA
etopo_goa <- projectRaster(etopo_goa, crs = crs(nmfs)) # reproject

# Plot
etopo_sf <- etopo_goa %>% 
  rasterToPoints() %>% 
  data.frame() %>% 
  st_as_sf(coords = c("x","y"), crs = crs(nmfs)) %>% 
  filter(layer < 0)

ggplot()+
  geom_sf(data = etopo_sf, aes(color = layer))+
  geom_sf(data = nmfs, fill = NA, color = "red")+
  geom_sf_label(data = nmfs, aes(label = NMFS_AREA))+
  labs(title = "ETOPO depth")

# Turn raster to polygon
etopo_goa <- reclassify(etopo_goa, rcl = c(-Inf, Inf, 1))
etopo_pol <- rasterToPolygons(etopo_goa, dissolve = TRUE)
etopo_pol <- disaggregate(etopo_pol)
etopo_pol <- etopo_pol %>% st_as_sf() %>% mutate(index = 1:nrow(.))
etopo_pol <- etopo_pol[1,] # the main shelf polygon seems to be the first row

# Generate mask
goa_mask <- etopo_pol %>% 
  st_intersection(nmfs) %>% 
  select(NMFS_AREA, geometry) %>%
  rowwise() %>%
  mutate(Model = NMFS_AREA) # ifelse(NMFS_AREA %in% c(640,650),"EGOA","WGOA")

# Plot
etopo_sf <- etopo %>% 
  rasterToPoints() %>% 
  data.frame() %>% 
  st_as_sf(coords = c("x","y"), crs = crs(nmfs)) %>% 
  filter(layer < 0)

ggplot()+
  geom_sf(data = etopo_sf, aes(color = layer))+
  geom_sf(data = goa_mask, aes(fill = Model))+
  geom_sf(data = nmfs, fill = NA, color = "red")+
  geom_sf_label(data = nmfs, aes(label = NMFS_AREA))+
  theme_minimal()+
  labs("Masks for GOA models")


# Save
st_write(goa_mask, "Data/Depth trimmed NMFS shapefiles 1000m/NMFS610-650.shp", append = FALSE)