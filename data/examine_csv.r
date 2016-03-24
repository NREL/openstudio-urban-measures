setwd('E:/openstudio-urban-measures/data')
rm(list=ls())

library(clue)
library(heatmap3)
library(lattice)

# load CBECS data
cbecs_1 <- read.csv('cbecs/FILE01.csv')
plot(cbecs_1$PBA, cbecs_1$SQFT8)
plot(cbecs_1$PBA, cbecs_1$NFLOOR8)

# load GIS data
buildings_raw <- read.csv('Portland_buildings_raw.csv')
buildings_clean <- read.csv('Portland_buildings_clean.csv')

good = which(buildings_raw$footprint_area > 90)

ci <- which((buildings_clean$zoning[good] == 'Commercial') | (buildings_clean$zoning[good] == 'Mixed'))
ri <- which(buildings_clean$zoning[good] == 'Residential')
mi <- which(buildings_clean$zoning[good] == 'Mixed')

# sample nsample commercial buildings from CBECs
mrows <- length(ci)
nsample <- 4*mrows
samp_idx <- sample(seq_len(nrow(cbecs_1)), nsample, prob=cbecs_1$ADJWT8)
cbecs_sample_1 <- cbecs_1[samp_idx, ]

# A has a row for every building and a column for every cbecs sample (repeated n_repeat times)
ft2_to_m2 <- 0.092903
n_repeat = 4
A = matrix(nrow=mrows, ncol=nsample) 
for(i in 1:mrows) {
  for(j in 1:nsample) {
    d <- buildings_clean$floor_area[ci[i]] - (cbecs_sample_1$SQFT8[j] * ft2_to_m2)
    A[i,j] <- abs(d)
  }
}
sol = solve_LSAP(A, maximum = FALSE)
assigned_indices = c(sol)
assigned_cbecs_sample_1 = cbecs_sample_1[assigned_indices,]

#heatmap3(A,useRaster=TRUE)
#levelplot(A)

d1 = (buildings_clean$floor_area[ci] - (cbecs_sample_1$SQFT8 * ft2_to_m2))
sum(abs(d1)) 
d2 = (buildings_clean$floor_area[ci] - (assigned_cbecs_sample_1$SQFT8 * ft2_to_m2))
sum(abs(d2)) 

plot(buildings_clean$floor_area[ci], assigned_cbecs_sample_1$SQFT8 * ft2_to_m2, xlab="Building Floor Area (m2)", ylab="CBECS Floor Area (m2)", col="green")

# TODO: compare space type histograms with CBECS sample and our data
barplot(prop.table(table(cbecs_sample_1$PBA8)))
barplot(prop.table(table(assigned_cbecs_sample_1$PBA8)))
barplot(prop.table(table(buildings_clean$space_type[ci])))

# look at height as a function of number of stories
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
