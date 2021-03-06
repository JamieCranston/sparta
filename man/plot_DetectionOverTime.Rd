% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plot_DetectionOverTime.R
\name{plot_DetectionOverTime}
\alias{plot_DetectionOverTime}
\title{Diagnostics for the detection model with respect to Length}
\usage{
plot_DetectionOverTime(model, spname = NULL, min.yr = NULL)
}
\arguments{
\item{model}{a fitted sparta model of class \code{OccDet}.}

\item{spname}{optional name of the species (used for plotting)}

\item{bins}{number of points to estimate across the year. Defaults to 12}

\item{density_function}{whether the model used a density function to fit Julian date. This form was implemented from version 0.1.48 onwards. For models ran using earlier versions of the package this should be set to FALSE}
}
\value{
This function returns plot showing the detection probability on the y axis and year on the x.
}
\description{
Creates a plot of detectability by year for differing list lengths from an occupancy model output.
}
\details{
Takes a object of \code{OccDet}

Calculates the detection probability and produces a plot of detectability over time for the reference data type.
}
