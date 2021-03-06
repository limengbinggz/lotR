% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{prob2stick}
\alias{prob2stick}
\title{transform a vector of probabilities that sum to one to stick proportions.}
\usage{
prob2stick(x)
}
\arguments{
\item{x}{a vector of probabilities (K); sums to \code{1}}
}
\value{
a vector K, with last element of 1; the elements are stick lengths in
the remaining part
}
\description{
transform a vector of probabilities that sum to one to stick proportions.
}
\examples{

prob2stick(c(0.5,0.2,0.3))

}
