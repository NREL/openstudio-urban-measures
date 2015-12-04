# OpenStudio Urban Measures

This repository contains OpenStudio measures for urban modelling.  The repository is built around a data format exported by NREL's GIS department, https://github.nrel.gov/jabbottw/City_Building_Model.  Exports from GIS are in CSV format, a script in this repository, city_csv_to_json.rb, is used to translate these exports into a JSON format.  Measures in this repository can take this format and create simulation ready building models. The urban_geometry_creation measure creates geometry for a single building in the dataset, it assigns stub space types with names that match CBECS PBA codes for commercial buildings or RECS Structure codes for residential buildings.  Mixed-use buildings may have difference space types per floor, the primary building space type will be assigned at the building level.  The urban_building_type measure assigns constructions, space loads, and HVAC systems according to the CBECS PBA codes.  Finally, the urban_dencity_reports measure pushes information about the building to a DENCity database.

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
