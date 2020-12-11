
library(RSelenium)
library(rvest)
library(tidyverse)
library(tidygeocoder)

### Getting addresses from Lego.com
rD <- rsDriver(browser="firefox", port=4545L, verbose=F)
remDr <- rD[["client"]]

# In the browser, I manually navigated to the Lego store locations search
# page and zoomed out so that all of them were visible and therefore listed.

# Getting addresses
webElem <- remDr$findElements(using='class', value='js--results__address')
addresses <- sapply(webElem, function(x){unlist(x$getElementText())})

# Getting store titles
webElem <- remDr$findElements(using='class', value='js--results__title_text')
titles <- sapply(webElem, function(x){unlist(x$getElementText())})



### Organizing dataframe
# Combine store titles and addresses to make dataframe
storesDF <- data.frame(titles, addresses)

# Remove any rows that are empty (just the last one)
storesDF <- storesDF %>% 
  filter(titles != '' & addresses != '')

# Remove numbered store locations (e.g. #152), since
# that causes issues for geocoding
storesDF <- storesDF %>% 
  mutate(clean_addresses = str_replace(addresses, '#\\S* ', ''))



### Geocoding to get lat/long from tidygeocoder::geo (73 missing)
stores_tidy <- geo(address = storesDF$clean_addresses, method = 'cascade')
storesDF <- left_join(storesDF, stores_tidy, by = c('clean_addresses' = 'address'))



### Getting lat/long for missing stores
# Separating addresses that are missing lat/long
missingDF <- storesDF %>% 
  filter(is.na(lat))

# I'm going to use latlong.net to fill in the missing addresses. I registered for a
# free account, which allows 30 free geocodes a day (so this will take 3 days).
# First, I manually navigated to the website and logged into my account.

# Initialize lists of addresses, latitudes, and longitudes
adds <- list()
latitudes <- list()
longitudes <- list()

# Scraping latlong.net (I used a for loop and did small chunks each day)
for(i in 61:73){
  address <- missingDF$clean_addresses[i]
  adds[i] <- address

  # Entering address
  placeElement <- remDr$findElement(using = "id", value = "place")
  placeElement$clearElement() # clears text if present
  placeElement$sendKeysToElement(list(address))
  
  # Clicking 'find' button
  find_button <- remDr$findElement(using = "id", value = "btnfind")
  find_button$clickElement()
  
  # Sleep a bit for lat/long to load
  Sys.sleep(5)
  
  # Extracting latitude and longitude
  latlngElement <- remDr$findElement(using = "id", value = "latlngspan")
  latlngText <- unlist(latlngElement$getElementText())
  lat <- str_extract(latlngText, '(?<=\\()(.*?)(?=,)')
  lng <- str_extract(latlngText, '(?<= )(.*?)(?=\\))')
  
  # Adding lat and lng to lists
  latitudes[i] <- lat
  longitudes[i] <- lng
}

# Create a dataframe of these addresses and newly found lat/longs
adds <- unlist(adds)
latitudes <- unlist(latitudes)
longitudes <- unlist(longitudes)
foundDF <- data.frame(adds, latitudes, longitudes) %>% 
  mutate(latitudes = as.numeric(latitudes), longitudes = as.numeric(longitudes))




### Manually entering some lat/long coordinates
# after the previous two steps, some coordinates were still missing
foundDF %>% 
  filter(latitudes == 0)

# I used Google Maps and latlong.net to find these manually
updateDF <- data.frame(adds = c('12801 W SUNRISE BLVD, SP. 1011, SUNRISE, FL,  33323-4007',
                                'CENTRE COMMERCIAL SO OUEST, LEVALLOIS-PERRET, 92300',
                                'Kalverstraat 57, Amsterdam, 1012 NZ',
                                'CentrO Einkaufszentrum 228, OBERHAUSEN, 46047'),
                       latitudes = c(26.151480, 48.891830, 52.370890, 51.490360),
                       longitudes = c(-80.321050, 2.296360, 4.891890, 6.881020))
# Update foundDF
foundDF <- rows_update(foundDF, updateDF)




### Replacing missing lat/long in storesDF with those in foundDF
# Starting by renaming columns to match storesDF, so that rows_update works
foundDF <- foundDF %>% 
  rename(clean_addresses = adds,
         lat = latitudes,
         long = longitudes)

finalDF <- rows_update(storesDF, foundDF) %>% 
  select(-geo_method) # I don't need the geo_method column

  

### Double-checking that there are no NAs and writing to csv!
sum(is.na(finalDF)) #0
write_csv(finalDF, 'project_data/store_locations.csv')
