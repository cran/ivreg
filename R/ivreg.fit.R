#' Fitting Instrumental-Variable Regressions by 2SLS
#' 
#' Fit instrumental-variable regression by two-stage least squares (2SLS). This is
#' equivalent to direct instrumental-variables estimation when the number of
#' instruments is equal to the number of predictors.
#' 
#' \code{\link{ivreg}} is the high-level interface to the work-horse function
#' \code{ivreg.fit}. \code{ivreg.fit} is essentially a convenience interface to
#' \code{\link[stats:lmfit]{lm.fit}} (or \code{\link[stats:lmfit]{lm.wfit}})
#' for first projecting \code{x} onto the image of
#' \code{z}, then running a regression of \code{y} on the projected
#' \code{x}, and computing the residual standard deviation.
#' 
#' @aliases ivreg.fit
#' 
#' @param x regressor matrix.
#' @param y vector for the response variable.
#' @param z instruments matrix.
#' @param weights an optional vector of weights to be used in the fitting
#' process.
#' @param offset an optional offset that can be used to specify an a priori
#' known component to be included during fitting.
#' @param \dots further arguments passed to \code{\link[stats:lmfit]{lm.fit}}
#' or \code{\link[stats:lmfit]{lm.wfit}}, respectively.
#' @return \code{ivreg.fit} returns an unclassed list with the following
#' components: 
#' \item{coefficients}{parameter estimates, from the stage-2 regression.} 
#' \item{residuals}{vector of model residuals.} 
#' \item{residuals1}{matrix of residuals from the stage-1 regression.}
#' \item{residuals2}{vector of residuals from the stage-2 regression.}
#' \item{fitted.values}{vector of predicted means for the response.}
#' \item{weights}{either the vector of weights used (if any) or \code{NULL} (if none).} 
#' \item{offset}{either the offset used (if any) or \code{NULL} (if none).} 
#' \item{estfun}{a matrix containing the empirical estimating functions.} 
#' \item{n}{number of observations.} 
#' \item{nobs}{number of observations with non-zero weights.} 
#' \item{p}{number of columns in the model matrix x of regressors.}
#' \item{q}{number of columns in the instrumental variables model matrix z}
#' \item{rank}{numeric rank of the model matrix for the stage-2 regression.} 
#' \item{df.residual}{residual degrees of freedom for fitted model.} 
#' \item{cov.unscaled}{unscaled covariance matrix for the coefficients.} 
#' \item{sigma}{residual standard error.}
#' \item{x}{projection of x matrix onto span of z.}
#' \item{qr}{QR decomposition for the stage-2 regression.}
#' \item{qr1}{QR decomposition for the stage-1 regression.}
#' \item{rank1}{numeric rank of the model matrix for the stage-1 regression.}
#' \item{coefficients1}{matrix of coefficients from the stage-1 regression.}
#' @seealso \code{\link{ivreg}}, \code{\link[stats:lmfit]{lm.fit}}, \code{\link[stats:lmfit]{lm.wfit}}
#' @keywords regression
#' @examples
#' ## data
#' data("CigaretteDemand", package = "ivreg")
#' 
#' ## high-level interface
#' m <- ivreg(log(packs) ~ log(rprice) + log(rincome) | salestax + log(rincome),
#'   data = CigaretteDemand)
#' 
#' ## low-level interface
#' y <- m$y
#' x <- model.matrix(m, component = "regressors")
#' z <- model.matrix(m, component = "instruments")
#' ivreg.fit(x, y, z)$coefficients
#' 
#' @export
ivreg.fit <- function(x, y, z, weights, offset, ...)
{
  ## model dimensions
  n <- NROW(y)
  p <- ncol(x)
  
  ## defaults
  if(missing(z)) z <- NULL
  if(missing(weights)) weights <- NULL
  if(missing(offset)) offset <- rep(0, n)
  
  ## sanity checks
  stopifnot(n == nrow(x))
  if(!is.null(z)) stopifnot(n == nrow(z))
  if(!is.null(weights)) stopifnot(n == NROW(weights))
  stopifnot(n == NROW(offset))
  
  ## project regressors x on image of instruments z
  if(!is.null(z)) {
    if(ncol(z) < ncol(x)) warning("more regressors than instruments")
    auxreg <- if(is.null(weights)) lm.fit(z, x, ...) else lm.wfit(z, x, weights, ...)
    xz <- as.matrix(auxreg$fitted.values)
    # pz <- z %*% chol2inv(auxreg$qr$qr) %*% t(z)
    colnames(xz) <- colnames(x)
  } else {
    auxreg <- NULL
    xz <- x
    # pz <- diag(NROW(x))
    # colnames(pz) <- rownames(pz) <- rownames(x)
  }
  
  ## main regression
  fit <- if(is.null(weights)) lm.fit(xz, y, offset = offset, ...)
    else lm.wfit(xz, y, weights, offset = offset, ...)
 
  ## model fit information
  ok <- which(!is.na(fit$coefficients))
  yhat <- drop(x[, ok, drop = FALSE] %*% fit$coefficients[ok])
  names(yhat) <- names(y)
  res <- y - yhat
  ucov <- chol2inv(fit$qr$qr[1:length(ok), 1:length(ok), drop = FALSE])
  colnames(ucov) <- rownames(ucov) <- names(fit$coefficients[ok])
  rss <- if(is.null(weights)) sum(res^2) else sum(weights * res^2)
  ## hat <- diag(x %*% ucov %*% t(x) %*% pz)
  ## names(hat) <- rownames(x)

  rval <- list(
    coefficients = fit$coefficients,
    residuals = res,
    residuals1 = auxreg$residuals,
    residuals2 = fit$residuals,
    fitted.values = yhat,
    weights = weights,
    offset = if(identical(offset, rep(0, n))) NULL else offset,
    n = n,
    nobs = if(is.null(weights)) n else sum(weights > 0),
    p = p,
    q = ncol(z),
    rank = fit$rank,
    df.residual = fit$df.residual,
    cov.unscaled = ucov,
    sigma = sqrt(rss/fit$df.residual), ## NOTE: Stata divides by n here and uses z tests rather than t tests...
    # hatvalues = hat,
    x = xz,
    qr = fit$qr,
    qr1 = auxreg$qr,
    rank1 = auxreg$rank,
    coefficients1 = coef(auxreg)
  )
  
  return(rval)
}