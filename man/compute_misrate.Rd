% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simulate.R
\name{compute_misrate}
\alias{compute_misrate}
\title{calculate the misclassification rates}
\usage{
compute_misrate(a, b)
}
\arguments{
\item{a}{truth class labels}

\item{b}{estimated class labels; a and b are of the same length}
}
\value{
the overall and the class-specific misclassification errors
}
\description{
the first is the truth, the second is the estimated ones
}
\examples{

compute_misrate(c(1,1,1,2,2,2,3,3,3),c(1,1,1,1,2,2,2,2,2))
}
