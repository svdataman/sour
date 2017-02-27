# To do:
#   - iccf.core: bring approx() interpolation outside main loop (speed)
#   - add more test data, unit tests
#   - use ACF(0) to normalise CCF(0) to ensure ACF(0)=1...?
 
# -----------------------------------------------------------
cross.correlate <- function(ts.1, ts.2,
                            method = "dcf",
                            max.lag = NULL, 
                            lag.bins = NULL, 
                            min.pts = 5,
                            dtau = NULL,
                            local.est = FALSE,
                            zero.clip = NULL,
                            use.errors = FALSE,
                            one.way = FALSE,
                            cov = FALSE,
                            prob = 0.1, 
                            nsim = 0,
                            peak.frac = 0.8,
                            chatter = 0,
                            plot = FALSE, ...) {
  
  # check arguments
  if (missing(ts.1)) stop('Missing ts.1 data frame.')
  
  # if only one time series then duplicate (compute ACF)
  acf.flag <- FALSE
  if (missing(ts.2)) {
    acf.flag <- TRUE
    ts.2 <- ts.1
  }

  # check the contents of the input time series
  if (!exists("t", where = ts.1)) stop('Missing column t in ts.1.')
  if (!exists("y", where = ts.1)) stop('Missing column y in ts.1.')
  if (!exists("t", where = ts.2)) stop('Missing column t in ts.2.')
  if (!exists("y", where = ts.2)) stop('Missing column y in ts.2.')
  
  # strip out bad data (any NA, NaN or Inf values)
  goodmask.1 <- is.finite(ts.1$t) & is.finite(ts.1$y)
  ts.1 <- ts.1[goodmask.1, ]
  t.1 <- ts.1$t
  n.1 <- length(t.1)
  goodmask.2 <- is.finite(ts.2$t) & is.finite(ts.2$y)
  ts.2 <- ts.2[goodmask.2, ]
  t.2 <- ts.2$t
  n.2 <- length(t.2)
  
  # warning if there's too little data to bother proceeding
  if (n.1 <= 5) stop('ts.1 is too short.')
  if (n.2 <= 5) stop('ts.2 is too short.')

  # if max.tau not set, set it to be 1/4 the max-min time range
  if (is.null(max.lag)) 
    max.lag <- (max(c(t.1, t.2)) - min(c(t.1, t.2))) * 0.25
  
  # if dtau is not defined, set to default
  if (is.null(dtau))
    dtau <- min( diff(t.1) )
  
  # total number of lag bins; make sure its odd!
  n.tau <- ceiling(2 * max.lag / dtau)  
  if (n.tau %% 2 == 0) 
    n.tau <- n.tau + 1
  lag.bins <- round( (n.tau - 1) / 2 )
  if (lag.bins < 4) stop('You have too few lag bins.')
  
  # now adjust max.lag so that -max.lag to +max.lag spans odd number of 
  # dtau bins
  max.lag <- (1/2) * dtau * (n.tau-1)
  
  # define the vector of lag bins. tau is the centre of each bin.
  # should extend from -max.tau to +max.tau, centred on zero.
  tau <- seq(-max.lag, max.lag, by = dtau)
  
  # optional feedback for the user  
  if (chatter > 0) {
    cat('-- lag.bins:', lag.bins, fill = TRUE)
    cat('-- max.lag:', max.lag, fill = TRUE)
    cat('-- n.tau:', n.tau, fill = TRUE)
    cat('-- length(tau)', length(tau), fill = TRUE)
    cat('-- dtau:', dtau, fill = TRUE)
    cat('-- length ts.1:', n.1, ' dt:', diff(t.1[1:2]), fill = TRUE)
    cat('-- length ts.2:', n.2, ' dt:', diff(t.2[1:2]), fill = TRUE)
  }
  
  # compute CCF for the input data
  ccf.out <- NA
  if (method == "dcf") {
    ccf.out <- dcf(ts.1, ts.2, tau,
                   local.est = local.est, min.pts = min.pts, 
                   zero.clip = zero.clip, chatter = chatter, cov = cov)
  } else {
    ccf.out <- iccf(ts.1, ts.2, tau,
                    local.est = local.est, chatter = chatter, 
                    cov = cov, one.way = one.way, zero.clip = zero.clip)
  }
  
  # extract the lag settings
  max.lag <- max(ccf.out$tau)
  nlag <- length(ccf.out$tau)
  lag.bins <- (nlag-1)/2
  dtau <- diff(ccf.out$tau[1:2])
  
  if (chatter > 0) {
    cat('-- max.lag:   ', max.lag, fill = TRUE)
    cat('-- nlag:      ', nlag, fill = TRUE)
    cat('-- lag.bins:  ', lag.bins, fill = TRUE)
    cat('-- dtau:      ', dtau, fill = TRUE)
  }
  
  # plot the CCF
  if (plot == TRUE) {
    plot(0, 0, type = "n", lwd = 2, bty = "n", ylim = c(-1, 1), xlim = c(-1, 1)*max.lag,
         xlab = "lag", ylab = "CCF", ...)
    grid(col = "lightgrey")
    dtau <- diff(ccf.out$tau[1:2])
    if (method == "dcf") {
      lines(ccf.out$tau-dtau/2, ccf.out$ccf, type="s", lwd = 2, col = "blue")
    } else {
      lines(ccf.out$tau, ccf.out$ccf, col = "blue", lwd = 3)
    }
  }
  
  # set up blanks if no simulations are run
  lower <- NA
  upper <- NA
  cent.dist <- NA
  peak.dist <- NA
  
  # (optional) run simulations to compute errors
  if (nsim > 0) {
  
    # check we have enough simulations
    if (nsim < 2/max(prob)) stop('Not enough simulations. Make nsim or prob larger.')
        
    # run some simulations
    sims <- ccf.errors(ts.1, ts.2, tau, nsim = nsim,
                     method = method, peak.frac = peak.frac, min.pts = min.pts,
                     local.est = local.est, zero.clip = zero.clip, prob = prob,
                     cov = cov, chatter = chatter, acf.flag = acf.flag, 
                     one.way = one.way)
    
    lower <- sims$lags$lower
    upper <- sims$lags$upper
    cent.dist <- sims$dists$cent.lag
    peak.disk <- sims$dists$peak.lag
  
  } else {
    
    if (method == "dcf") {
      acf.1 <- dcf(ts.1,  ts.1, tau,
                   local.est = local.est, 
                   min.pts = min.pts, 
                   chatter = chatter, cov = cov)
      acf.2 <- dcf(ts.2, ts.2,  
                   local.est = local.est, 
                   min.pts = min.pts, dtau = dtau,
                   max.lag = max.lag, lag.bins = lag.bins, 
                   chatter = chatter, cov = cov)
    } else {
      acf.1 <- iccf(ts.1, ts.1, tau, 
                    local.est = local.est, 
                    chatter = chatter, 
                    cov = cov, 
                    one.way=one.way)
      acf.2 <- iccf(ts.2, ts.2, tau, 
                    local.est = local.est, 
                    chatter = chatter, 
                    cov = cov, 
                    one.way = one.way)
    }
    
    sigma <- sqrt( (1/ccf.out$n) * sum(acf.1$ccf*acf.2$ccf) )
    lower <- ccf.out$ccf - sigma
    upper <- ccf.out$ccf + sigma
  }
  
  # plot confidence bands
  if (plot == TRUE) {
    pnk <- rgb(255, 192, 203, 100, maxColorValue = 255)
    indx <- is.finite(ccf.out$ccf)
    polygon(c(ccf.out$tau[indx], rev(ccf.out$tau[indx])), c(lower[indx], rev(upper[indx])), 
            col=pnk, border = NA)
    if (method == "dcf") {
      lines(ccf.out$tau-dtau/2, ccf.out$ccf, type = "s", lwd = 2, col = "blue")
    } else {
      lines(ccf.out$tau, ccf.out$ccf, col = "blue", lwd = 3)
    }
  }
  
  # return output  
  result <- list(tau = ccf.out$tau, 
                 ccf = ccf.out$ccf, 
                 lower = lower,
                 upper = upper, 
                 peak.dist = peak.dist,
                 cent.dist = cent.dist, 
                 method = method)
  return(result)
}



# -----------------------------------------------------------
# fr.rss
# Inputs: 
#   ts.1      - data frame containing times (1st column)
#                and values (2nd column) for data series.
#                Contains optional errors (3rd column).
#
# Value:
#   result   - a data frame containing columns
#      t     - time bins for randomised data
#      x     - values for randomised data
#     dx     - errors for randomised data
#
# Description:
#  Performs "flux randomisation" and "random sample selection"
# of an input time series, following 
# Peterson et al. (2004, ApJ, 613:682-699).
#
# Given an input data series (t, x, dx) of length N we sample
# N points with replacement. Duplicated points are ignored, so 
# the ouptut is usually shorter than the input. So far this is
# a basic bootstrap procedure.
#
# If error bars are provided: when a point is selected m times, 
# we decrease the error by 1/sqrt(m). See Appendix A of Peterson et al. 
# And after resampling in time, we then add a random Gaussian deviate
# to each remaining data point, with std.dev equal to its error bar.
# In this way both the times and values are randomised.
#
# If errors bars are nor provided, this is a simple bootstrap.
#
# The output is another data frame of (t, y, dy)
#
# History:
#  21/03/16 - First working version
#
# (c) Simon Vaughan, University of Leicester
# -----------------------------------------------------------

fr.rss <- function(dat) {
  
  # check arguments
  if (missing(dat)) stop('Missing DAT argument')
  
  # extract data
  times <- dat$t
  x <- dat$y
  n <- length(times)
  
  # if no errors are provided, we will do a simple bootstrat
  if (exists("dy", where = dat)) {
    bootstrap <- FALSE
    dx <- dat$dy
  } else {
    bootstrap <- TRUE
    dx <- 0
  }
  if (length(dx) < n) dx <- rep(dx[1], n)
    
  # ignore any data with NA value
  mask <- is.finite(x) & is.finite(dx)
  times <- times[mask]   # time
  x <- x[mask]           # value
  dx <- dx[mask]         # error
  n <- length(x)

  # randomly sample the data
  indx <- sample(1:n, n, replace=TRUE)

  # identify which points are sampled more than once
  duplicates <- duplicated(indx)
  indx.clean <- indx[!duplicates]

  # where data points are selected n>0 times, scale the error by 1/sqrt(n)
  n.repeats <- hist(indx, plot=FALSE, breaks=0:n+0.5)$counts
  dx.original <- dx
  dx <- dx / sqrt( pmax.int(1, n.repeats) )
    
  # new data are free from duplicates, and have errors decreased where
  # points are selected multiple times.
  
  times.new <-  times[indx.clean]
  x.new <-      x[indx.clean]
  dx.new <-     dx[indx.clean]
  n <- length(x.new)
  
  # now randomise the fluxes at each data point
  if (bootstrap == FALSE) {
    x.new <- rnorm(n, mean=x.new, sd=dx.new)
  }      
  
  # sort into time order
  indx <- order(times.new)

  # return the ouput data
  return(data.frame(t=times.new[indx], y=x.new[indx], dy=dx.new[indx]))
  
}

# -----------------------------------------------------------
# ccf.errors
# Inputs: 
#   ts.1      - data frame containing times (t)
#                and values (y) for data series 1.
#                Contains optional errors (3rd column).
#   ts.2      - data frame for data series 2
#   tau       - list of lags
#   min.pts   - set to NA any lag bins with fewer points (default: 10)
#   local.est - use 'local' (not 'global') means and variances?
#   prob      - probability level to use for confidence intervals
#   nsim      - number of simulations
#   peak.frac - what fraction below peak to include in centroid measurements?
#   zero.clip - remove pairs of points with exactly zero lag? 
#   method    - use DCF or ICCF method (default: dcf)
#   use.errors - TRUE/FALSE passed to dcf() 
#   local.est  - TRUE/FALSE passed to dcf() or iccf()
#   acf.flag  - TRUE if computing ACF and ts.2 = ts.1
#
# Value:
#   result    - a data frame containing columns...
#      tau    - the centre of the lag bins (vector)
#      dcf    - the correlation coefficent in each lag bin
#
# Description:
#  Compute the Discrete Correlation Function based on method 
# outlined in Edelson & Korlik (1998, ApJ). 
# This is a way to estimate the CCF for a pair of time series
# (t.1, x.1) and (t.2, x.2) when the time sampling is uneven
# and non-synchronous. See dcf(...) function.
#
# Computes errors on the DCF values using "flux randomisation" 
# and "random subset sampling" FR/RSS using the fr.rss(...) function.
#
# For each randomised pair of light curves we compute the DCF. 
# We record the DCF, the lag at the peak, and the centroid lag
# (including only points higher than peak.frac * peak).
# Using nsim simulations we compute the (1-p)*100% confidence
# intervals on the DCF values, and the distribution of peaks
# and centroids.
#
# The output is a list containing two components
#    lags     - a data frame with four columns
#    tau      - time lags
#    dcf      - the DCF values for the input data
#    lower    - the lower limit of the confidence interval
#    upper    - the upper limit of the confidence interval
#    dists    - a data frame with two columns
#    peak.lag - the peak values from nsim simulations
#    cent.lag - the centroid values from nsim simulations
#
# History:
#  21/03/16 - v1.0 - First working version
#  05/04/16 - v1.1 - added na.rm option to strip out non-finite values
#  09/04/16 - v1.2 - added use.errors option; minor fixes
#  23/07/16 - v1.3 - minor change to handling of centroid calculation.
#                     if the CCF is entirely <0 then return NA for
#                     centroid.
#
# (c) Simon Vaughan, University of Leicester
# -----------------------------------------------------------

ccf.errors <- function(ts.1, ts.2, 
                       tau = NULL,
                       min.pts=5,
                       local.est=FALSE,
                       cov=FALSE,
                       prob=0.1, 
                       nsim=250,
                       peak.frac=0.8,
                       zero.clip=NULL,
                       one.way=FALSE,
                       method="dcf",
                       use.errors=FALSE,
                       acf.flag=FALSE,
                       chatter=0) {

  # check arguments
  if (missing(ts.1)) stop('Missing ts.1 data frame.')
  if (is.null(tau)) stop('Missing tau in.')
  
  # if only one time series then duplicate (compute ACF)
  acf.flag <- FALSE
  if (missing(ts.2)) {
    acf.flag <- TRUE
    ts.2 <- ts.1
  }

  if (peak.frac > 1 | peak.frac < 0) 
    stop('peak.frac should be in the range 0-1')
  
  if (prob > 1 | prob < 0) 
    stop('prob should be in the range 0-1')
  
  nlag <- length(tau)

  # set up an array for the simulated DCFs
  ccf.sim <- array(NA, dim=c(nsim, nlag))  
  peak.lag <- array(NA, dim=nsim)
  cent.lag <- array(NA, dim=nsim)

  # loop over simulations
  for (i in 1:nsim) {
    
    # generate randomised data
    ts1.sim <- fr.rss(ts.1)
    if (acf.flag == FALSE) {
      ts2.sim <- fr.rss(ts.2)
    } else {
      ts2.sim <- ts1.sim
    }
    
    # compute CCF of randomised data
    if (method == "dcf") {
      result.sim <- dcf(ts1.sim, ts2.sim, tau,
                        local.est = local.est, 
                        min.pts = min.pts, 
                        cov = cov,
                        zero.clip = zero.clip, 
                        use.errors = use.errors)
    } else {
      result.sim <- iccf(ts1.sim, ts2.sim, tau,
                         zero.clip = zero.clip, 
                         local.est = local.est, 
                         cov = cov, 
                         one.way = one.way)
    }
    
    ccf.sim[i,] <- result.sim$ccf    
    
    # find and store the peak of the CCF
    peak <- which.max(result.sim$ccf)
    peak.lag[i] <- result.sim$tau[peak]
    
    # find and store the centroid of the CCF
    # if the CCF peak is <0 then return NA 
    if (max(result.sim$ccf, na.rm = TRUE) > 0) {
      mask <- which( result.sim$ccf >= peak.frac * max(result.sim$ccf, na.rm = TRUE) )
      cent.lag[i] <- sum(result.sim$ccf[mask]*result.sim$tau[mask], na.rm = TRUE)  /
                      sum(result.sim$ccf[mask], na.rm = TRUE)
    }
    
    cat("\r Processed", i, "of", nsim, "simulations")
  }

  cat(fill = TRUE)

  # now compute the prob/2 and 1-prob/2 quantiles at each lag
  ccf.lims <- array(NA, dim = c(nlag, 2))
  probs <- c(prob/2, 1-prob/2)
  for (i in 1:nlag) {
    ccf.lims[i,] <- quantile(ccf.sim[,i], probs = probs, na.rm = TRUE)
  }

  # package the DCF: lag, values, lower and upper limits  
  lags <- data.frame(tau = result.sim$tau, lower = ccf.lims[,1], upper = ccf.lims[,2])
  
  # package the peak and centroid data
  dists <- data.frame(peak.lag = peak.lag, cent.lag = cent.lag)
  
  # interval of centroids
  if (chatter >= 0) 
  cat('-- ', signif(100*(1-prob), 3), '% lag interval ', 
      quantile(cent.lag, probs[1], na.rm = TRUE), ' - ',
      quantile(cent.lag, probs[2], na.rm = TRUE), fill = TRUE, sep = "")
  
  
  return(list(lags = lags, dists = dists))
}

# -----------------------------------------------------------