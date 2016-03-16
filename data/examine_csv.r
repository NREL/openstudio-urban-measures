setwd('E:/openstudio-urban-measures/data')
rm(list=ls())

buildings_raw <- read.csv('Portland_buildings_raw.csv')
buildings_clean <- read.csv('Portland_buildings_clean.csv')

good = which(buildings_raw$footprint_area > 50)

ci <- which(buildings_clean$zoning[good] == 'Commercial')
ri <- which(buildings_clean$zoning[good] == 'Residential')
mi <- which(buildings_clean$zoning[good] == 'Mixed')

i = ri

x = buildings_raw$number_of_stories[i]
y = buildings_raw$average_roof_height[i]

x = buildings_raw$footprint_area[i]
y = buildings_raw$floor_area[i]

number_of_stories = buildings_raw$number_of_stories[i] 
num_stories_floor_area = buildings_raw$floor_area[i] / buildings_raw$footprint_area[i]
x = number_of_stories
y = num_stories_floor_area

fit = lm(y ~ -1 + x)
plot(x, y)
abline(fit)
summary(fit)

plot(fit)

barplot(prop.table(table(buildings_clean$space_type)))