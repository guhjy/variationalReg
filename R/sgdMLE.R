exactMSmle <- function(X, y, ysig, threshold,
                       nsteps = 2000, nsamps = 4, stepCoef = 0.02,
                       stepRate = 0.6,
                       meanMethod = c("zero", "plugin"),
                       nonzero = NULL, verbose = TRUE) {
  if(is.character(meanMethod)) {
    meanMethod <- meanMethod[1]
  }

  p <- ncol(X)
  suffStat <- t(X) %*% y
  selected <- abs(suffStat) > threshold
  Xs <- X[, selected]
  suffCov <- t(X) %*% X * ysig^2
  XtX <- t(Xs) %*% Xs
  XtXinv <- solve(XtX)

  naiveFit <- lm(y ~ Xs - 1)
  naive <- coef(naiveFit)
  prevGrad <- rep(0, sum(selected))

  if(is.null(nonzero)) {
    nonzero <- selected
  }
  if(is.numeric(meanMethod)) {
    if(length(meanMethod) != p) {
      stop("If mean method is numeric then it must be of size p!")
    }
    mu <- meanMethod
  } else if(meanMethod == "plugin") {
    mu <- as.numeric(suffStat)
  } else if(meanMethod == "zero") {
    mu <- rep(0, p)
    mu[selected] <- suffStat[selected]
  } else {
    stop("mean method not supported")
  }
  betahat <- as.numeric(XtXinv %*% mu[selected])

  sampthreshold <- matrix(threshold, nrow = p, ncol = 2)
  sampthreshold[, 1] <- -sampthreshold[, 1]
  prevSamp <- as.numeric(suffStat)
  precision <- solve(suffCov)
  b1 <- 0.9
  b2 <- 0.99
  mt <- 0
  vt <- 0
  betahat <- naive
  estimates <- matrix(nrow = nsteps + 1, ncol = length(betahat))
  samples <- matrix(nrow = nsteps, ncol = p)
  estimates[1, ] <- betahat
  constrained <- any(nonzero != selected)
  if(verbose) {
    if(constrained) {
      print("Computing constrained conditional MLE!")
    } else {
      print("Computing conditional MLE!")
    }
    pb <- txtProgressBar(min = 0, max = nsteps, style = 3)
  }

  for(m in 1:nsteps) {
    if(verbose) setTxtProgressBar(pb, m)
    samporder <- (1:p)[order(runif(p))]
    start <- rep(0, p)
    condSamp <- mvtSampler(y = start, mu = mu,
                           selected = as.integer(selected),
                           threshold = sampthreshold,
                           precision = precision, nsamp = max(nsamps, 4),
                           burnin = 80, trim = 4, samporder = samporder,
                           verbose = FALSE)
    prevSamp <- condSamp[nsamps, ]
    samples[m, ] <- condSamp[nsamps, ]
    grad <- (suffStat[selected] - colMeans(condSamp)[selected])
    mt <- b1 * mt + (1 - b1) * grad
    vt <- b2 * vt + (1 - b2) * grad^2
    betahat <- betahat + (mt / (1 - b1^m)) / (sqrt(vt/(1 - b2^m)) + 10^-6) * stepCoef / m^stepRate
    mu[selected] <- as.numeric(XtX %*% betahat)
    if(constrained) {
      mu[!nonzero] <- 0
      betahat <- as.numeric(XtXinv %*% mu[selected])
    }

    # correcting signs
    # signs <- sign(naive)
    # betahat <- betahat * signs
    # betahat <- pmax(0, pmin(abs(naive), betahat))
    # betahat <- betahat * signs

    estimates[m + 1, ] <- betahat
  }
  if(verbose) close(pb)

  betahat <- colMeans(estimates[round(nrow(estimates)/2):nrow(estimates), ])
  #print(cbind(betahat, naive))
  return(list(mle = betahat, estimates = estimates, naive = naive,
              samples = samples))
}
