---
title: "PointClouds.jl: Fast & flexible processing of lidar data"
tags:
  - point clouds
  - lidar
  - remote sensing
  - julia
authors:
  - name: Manuel F. Schmid
    orcid: 0000-0002-7880-9913
    affiliation: 1
  - name: Jeffrey D. Massey
    affiliation: 2
  - name: Marco G. Giometto
    orcid: 0000-0001-9661-0599
    affiliation: "1, 2"
affiliations:
  - name: Columbia University, New York, NY, USA
    index: 1
  - name: Amazon, Seattle, WA, USA[^1]
    index: 2
date: 19 Jul 2024
bibliography: references.bib
---

[^1]: Marco G. Giometto holds concurrent appointments as Assistant Professor at Columbia University as Amazon Visiting Academic. This paper describes work performed at Columbia University and is not associated with Amazon.

# Summary

PointClouds.jl is a toolbox for working with point-cloud data that lets users implement complex point-processing workflows.
It includes functionality for working with the LAS file format (and its compressed LAZ variant) that is commonly used to save and distribute geospatial point-cloud data obtained from lidar scans.
Such scans are obtained with a laser instrument, often mounted on an airplane, that shoots out light pulses in quick succession and measures the return time of those pulses to reconstruct the points at which the signal was reflected.
This results in a “point cloud” of 3D coordinates and various additional attributes associated with each point, such as the intensity of the reflected signal.
Extracting useful information from that data generally requires a series of processing steps that extend, filter, or transform the point cloud.
PointClouds.jl aims to provide a comprehensive set of functionality to build such processing pipelines.
As lidar scans are becoming more commonplace, large datasets are being made publicly available online.
The lidar point-cloud data collected by the United States Geological Survey as part of their 3D Elevation Program (3DEP) now provides near-complete coverage of the United States at a sub-meter scale, for example.
PointClouds.jl also includes functionality to query such datasets and download the data for any region of interest, allowing a spatial analysis pipeline to be applied to any location within the current coverage.
These capabilities make PointClouds.jl a fast and flexible tool for finding, loading, and analyzing lidar data.


# Statement of need

Remote sensing allows us to obtain a wealth of information about the physical environment.
While many remote sensing technologies produce raster data (e.g. satellite imagery), methods such as lidar (light detection and ranging) and photogrammetry instead identify a collection of points on the land surface, producing a “point cloud” with the 3D coordinates and additional point attributes.
Sensor platforms ranging from satellites to mobile phones generate point-cloud data that can span entire countries or more targeted high-fidelity scans.
Thanks to falling acquisition costs and newly emerging platforms such as unmanned aerial vehicles and self-driving cars, point-cloud data is more readily available than ever before.

It hence comes as no surprise that point-cloud data has found its way into numerous applications in industry, government, and academia.
Examples include computer vision for robotics and autonomous vehicles, generation of digital terrain & surface models, forestry and agriculture, archaeological surveys, geomorphology, and inspection/surveillance of infrastructure.
Whenever an application requires digital data on the geometry of real-world surfaces, acquiring point-cloud data may be an attractive option.

While some of these goals may be achieved by visualizing the point-cloud data and inspecting it manually, most applications rely on a series of automated processing steps to derive actionable information from the raw point-cloud data.
These steps may include noise removal, subsetting, classification, object detection, rasterization, triangulation, and conversion between various data formats.
Some processing steps may also make use of additional data obtained from complementary sensing technologies such as multispectral cameras or rely on pre-existing databases of geospatial information.

Various tools exist to aid with this data processing, both as standalone software and as add-ons to geospatial software.
With PointClouds.jl we present a new contribution to this ecosystem that was motivated by four key requirements:

- interactive development of custom processing steps with solid performance,
- programmatic access to national databases of airborne lidar data,
- easy integration with other Julia software, and
- open-source availability of the code.

The first requirement arises whenever new, custom processing steps are developed or existing algorithms are customized.
For a fast feedback cycle it is advantageous to continuously run and evaluate new code as it is written.
This greatly favors dynamic languages such as Python, Julia, MATLAB, and R, which can be used interactively in a notebook or REPL environment and only require reevaluating modified parts of the code rather than recompiling and rerunning the whole program.
At the same time, the new code should run with adequate performance so it can be evaluated with sample data of meaningful size and used in production without costly rewrites.
To provide interactive point-processing functionality that is sufficiently performant to handle millions or even billions of points, PointClouds.jl relies on the Julia programming language [@Bezanson:2017].
With its “just-ahead-of-time” compilation model, Julia is ideally suited for this task as it can freely mix library functionality with custom code from the user and achieve good performance for both.

The second requirement of programmatic access to national databases greatly reduces the friction for obtaining detailed data for arbitrary locations and opens up a range of new applications.
Multiple countries are now producing lidar point-cloud datasets that cover the entire territory, generally at a resolution on the order of 10 points/m².
Such programs exist for example in Denmark, England, Estonia, Finland, France, Latvia, the Netherlands, New Zealand, Poland, Slovenia, Spain, Sweden, Switzerland, and the USA.
The ability to query such databases from within your own code and download the available data for any region of interest makes it much easier to take advantage of these resources.
Functionality built on top of PointClouds.jl is instantly applicable to any location in the country as long as the processing pipeline is robust enough to handle the variability in the available data.

The third requirement of integration with Julia software can always be met to some degree, as data can be passed around through foreign function interfaces or external files.
However, having PointClouds.jl implemented in Julia allows us to remove this overhead, write all custom functionality in Julia too, and make use of the growing ecosystem of high-quality Julia packages that offer adjacent functionality.

The final requirement of open-source licensing is especially important for scientific applications, both for knowing exactly how each processing step was performed and for enabling the development of new processing techniques.
It also lowers the barrier of entry if the software can be freely downloaded by anyone without having to buy and manage restrictive licenses.
PointClouds.jl is licensed under the permissive MIT license and can be installed from the Julia package repository with a single command.

PointClouds.jl took shape as part of a research collaboration between Columbia University and Amazon that produced the above requirements, which were not fully met by existing solutions.
The project is aimed at simulating near-surface wind dynamics in any populated area in the United States, with extensibility to other countries of interest.
Such simulations could support drone-delivery operations in the future.
PointClouds.jl allows us to construct a processing pipeline that can access the lidar data for the specified coordinates, derive rasterized representations of resolvable features (terrain, buildings), and estimate aerodynamic properties of unresolvable features (vegetation, surface roughness).
Furthermore, it allows us to assess the sensitivity of wind predictions on properties of the input data and the point-cloud processing methods.
Part of this work was presented at recent conferences [@Schmid:2023; @Giometto:2024] and further publications are in preparation.

While some requirements may be specific to our current research projects, we expect that many applications within and outside of academia may have similar needs and therefore benefit from the approach we took with PointClouds.jl.
In particular, we hope to increase adoption of national lidar datasets, encourage people to run their models on many locations rather than a few hand-picked ones, and encourage more activity in the development of point-cloud processing techniques.

# Overview of functionality

The functionality of PointClouds.jl covers three main areas: data access, file input and output, and in-memory processing.

Regarding data access, PointClouds.jl can query national lidar datasets using coordinates, automatically downloading the available data for the requested areas.
Initial support is included for the USGS 3D Elevation Program (3DEP) in the United States whereas support for other national programs will be added over time.

Initial support is included for the 3D Elevation Program (3DEP) of the United States Geological Survey whereas support for other national programs will be added over time.
The 3DEP dataset is approaching complete coverage of the lower 48 states and distributes the raw point-cloud data “free of charge and without use restriction”.

Regarding file input and output, PointClouds.jl reads and writes the LAS format defined by the American Society for Photogrammetry and Remote Sensing (ASPRS) and in the compressed LAZ variant in all current versions of the format (1.0 – 1.4) with strict adherence to the specification.
It includes support for parsing the coordinate reference system (CRS) information and for working with files that do not fit into memory using lazy processing.
While LAS/LAZ is the most common format for published point-cloud datasets, support for additional point-cloud formats is within the scope of PointClouds.jl and may be added over time, whereas support for general-purpose data formats such as HDF5 is delegated to separate Julia packages.

Regarding point-cloud processing, PointClouds.jl provides robust fundamentals for multithreaded iteration over points, filtering, coordinate transforms, rasterization, and finding the nearest neighbors.
Over time, PointClouds.jl is expected to grow a comprehensive library of point-processing algorithms that can be used as building blocks for complex spatial analysis tasks.

While we are not aware of any other software that is targeting programmatic access to national lidar datasets, there are quite a few existing tools that provide functionality for working with LAS data and applying various processing methods.
The PDAL [@Butler:2021; @PDAL:2024] and lidR [@Roussel:2020] projects in particular provide functionality for geospatial point-cloud processing that is similar to the scope of PointClouds.jl.
These packages, written in C++ and R respectively, are more mature and implement various processing steps (“filters” in PDAL, “metrics” in lidR) that are not yet available in PointClouds.jl.
Applications that heavily rely on existing building blocks to set up a point-processing pipeline may therefore be better served by those alternatives, while we believe that PointClouds.jl is already a competitive offer for implementing custom processing steps, or when working with point-cloud data within a Julia project.
Over time, we hope that PointClouds.jl can also match the maturity and comprehensiveness of the alternative choices.

There are also a number of existing Julia packages that share parts of the functionality and goals of PointClouds.jl.
Nevertheless, we see benefit from a project that optimizes the functionality, ergonomics, and performance across the entire process of finding, loading, and transforming point-cloud data.


# Acknowledgements

We acknowledge the financial support from Amazon. This material is based upon work supported by, or in part by, the Army Research Laboratory and the Army Research Office under grant number W911NF-22-1-0178.


# References
