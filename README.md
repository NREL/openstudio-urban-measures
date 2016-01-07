# OpenStudio Urban Measures

This repository contains OpenStudio measures and utilities for urban modeling. An overview of this functionality is shown below:

![Overview](overview.jpg  =600x "Overview")

1. The first step in the urban modeling process is to develop a GeoJSON file containing building footprints.  Footprints for existing buildings can be exported by the [NREL GIS department](https://github.nrel.gov/jabbottw/City_Building_Model).  Footprints for new buildings can be developed using a future input GUI.  A GeoJSON file containing taxlot boundaries may be useful as reference when drawing new footprints.  At this stage, the building footprints should be limited to approximately ~1000 buildings per file.  If modeling an entire city, the city can be divided into sections that are modeled separately.
2. Once the initial building GeoJSON file is developed, it may be transformed by one or more scripts.  These scripts may fill in missing data in the original dataset or transform it in some way.  Examples of these scripts include assignment of building space type by sampling from the CBECS data set or computing which buildings may shade other buildings.
3. The final building GeoJSON file is then input to an OpenStudio Analysis where the Urban Geometry Creation Measure is used.  This measure reads the building GeoJSON file and creates geometry for each building (including adjacent buildings for heat transfer and surrounding buildings for shading).   This measure also assigns stub space types with names that match CBECS PBA codes for commercial buildings or RECS Structure codes for residential buildings.  Mixed-use buildings may have difference space types per floor, the primary building space type will be assigned at the building level.  Once the geometry is created it is passed through other measures as defined by the OpenStudio Analysis.  The geometry creation measure is typically a pivot variable.  The OpenStudio Analysis also defines a set of variables that define the parameter space for the analysis.  Results from the analysis are pushed to a [DEncity](https://dencity.org) database.
4.  After the analysis is complete, a scenario exporter reads results from the DEncity database and outputs a GeoJSON file with embedded results.  A scenario JSON defines the variable values for each building.  The variables and allowable values are defined by the OpenStudio Analysis JSON.  The variable values associated with each building in the scenario are used to look up results in the DEncity database.
5. If the scenario includes district systems, the scenario exporter writes district system OSM files and simulates them, pushing the results back to DEncity.  The scenario exporter then includes district simulation results in the results GeoJSON.
6. Once a results GeoJSON is written for a particular scenario, the results can be visualized in the desktop results GUI or the NREL Insight Center.  

The GeoJSON format is used in several places in this workflow because it is a well documented file format that is easy to work with and is widely supported by web technologies.  The geometry creation measure and results visualization interfaces require additional structured data that is an extension of the GeoJSON schema.  These data fields are documented in the city_schema.json JSON schema.

# Reference

For reference the RECS Structure codes are:

* Single-Family
* Multifamily (2 to 4 units)
* Multifamily (5 or more units)
* Mobile Home

The CBECS PBA codes are:

* Vacant
* Office
* Laboratory
* Nonrefrigerated warehouse
* Food sales
* Public order and safety
* Outpatient health care
* Refrigerated warehouse
* Religious worship
* Public assembly
* Education
* Food service
* Inpatient health care
* Nursing
* Lodging
* Strip shopping mall
* Enclosed mall
* Retail other than mall
* Service
* Other

# Installation

## OpenStudio Standards

1. Check out https://github.com/NREL/openstudio-standards
2. `cd \openstudio-standards\openstudio-standards`
3. `bundle install`
4. `rake build`
5. `gem install --user-install pkg/openstudio-standards-0.1.0.gem`
6. Set environment variable GEM_PATH to the user gem directory, e.g. C:\Users\dmacumbe\.gem\ruby\2.0.0
