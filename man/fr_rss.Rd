% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cross_correlation.R
\name{fr_rss}
\alias{fr_rss}
\title{Perform flux randomisation/random subset section on input data.}
\usage{
fr_rss(dat)
}
\arguments{
\item{dat}{(data frame) containing columns \code{t, y} and (optionally) 
\code{dy}.}
}
\value{
A data frame containing columns
 \item{t}{time bins for randomised data}
 \item{y}{values for randomised data}
 \item{dy}{errors for randomised data}
}
\description{
\code{fr_rss} returns a randomise version of an input data array.
}
\details{
Performs "flux randomisation" and "random sample selection"
of an input time series, following Peterson et al. (2004, ApJ, v613, pp682-699).
This is essentially a bootstrap for a data vector.
}
\section{Notes}{

Given an input data series (\code{t, y, dy}) of length \code{N} we sample 
\code{N} points with replacement. Duplicated points are ignored, so the
ouptut is usually shorter than the input. So far this is a basic bootstrap
procedure.

If error bars are provided: when a point is selected \code{m} times, we
decrease the error, scaling by \code{1/sqrt(m)}. See Appendix A of Peterson
et al. After resampling, we then add a random Gaussian deviate to each
remaining data point, with std.dev equal to its (new) error bar. If errors
bars are not provided, this is a simple bootstrap (no randomisation of
\code{y}).
}

\examples{
 ## Example using the NGC 5548 data
 plot(cont$t, cont$y, type="l", bty = "n", xlim = c(50500, 52000))
 rcont <- fr_rss(cont)
 lines(rcont$t, rcont$y, col = "red")

 ## Examples from Venables & Ripley
 require(graphics)
 plot(fdeaths, bty = "n")
 tsf <- data.frame(t = time(fdeaths), y = fdeaths)
 rtsf <- fr_rss(tsf)
 lines(rtsf$t, rtsf$y, col="red", type="o")

}
\seealso{
\code{\link{cross_correlate}}, \code{\link{ccf_errors}}
}
