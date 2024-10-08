# To process this file correctly with roxygen2 so that S3 methods that are registered conditionally 
# generate proper usage lines in the .Rd file as  \method{...}{...} markup:
#     
# library("sandwich")
# library("insight")
# library("effects")
# devtools::document() 
# 
# Then build the source package.


#' Methods for \code{"ivreg"} Objects
#' @aliases ivregMethods vcov.ivreg bread.ivreg estfun.ivreg terms.ivreg model.matrix.ivreg predict.ivreg
#' print.ivreg summary.ivreg print.summary.ivreg anova.ivreg update.ivreg residuals.ivreg Effect.ivreg 
#' formula.ivreg  find_formula.ivreg alias.ivreg qr.ivreg
#' @description Various methods for processing \code{"ivreg"} objects; for diagnostic methods,
#'   see \code{\link{ivregDiagnostics}}.
#' @seealso \code{\link{ivreg}}, \code{\link{ivreg.fit}}, \code{\link{ivregDiagnostics}}
#' @param object,object2,model,mod An object of class \code{"ivreg"}.
#' @param x An object of class \code{"ivreg"} or \code{"summary.ivreg"}.
#' @param component For \code{\link{terms}}, \code{"regressors"}, \code{"instruments"}, or \code{"full"}; 
#' for \code{\link{model.matrix}}, \code{"projected"}, \code{"regressors"}, or \code{"instruments"};
#' for \code{\link{formula}}, \code{"regressors"}, \code{"instruments"},  or \code{"complete"};
#' for \code{\link{coef}} and \code{\link{vcov}}, \code{"stage2"} or \code{"stage1"}.
#' @param newdata Values of predictors for which to obtain predicted values; if missing
#' predicted (i.e., fitted) values are computed for the data to which the model was fit.
#' @param na.action \code{na} method to apply to predictor values for predictions; default is \code{\link{na.pass}}.
#' @param digits For printing.
#' @param signif.stars Show "significance stars" in summary output.
#' @param vcov. Optional coefficient covariance matrix, or a function to compute the covariance matrix, to use in computing the model summary.
#' @param df For \code{summary}, optional residual degrees of freedom to use in computing model summary. 
#' For \code{predict}, degrees of freedom for computing t-distribution confidence- or prediction-interval limits; the
#' default, \code{Inf}, is equivalent to using the normal distribution; if \code{NULL}, 
#' \code{df} is taken from the residual degrees of freedom for the model.
#' @param diagnostics Report 2SLS "diagnostic" tests in model summary (default is \code{TRUE}). 
#' These tests are not to be confused with the \emph{regression diagnostics} provided elsewhere in the \pkg{ivreg}
#' package: see \code{\link{ivregDiagnostics}}.
#' @param test,test.statistic Test statistics for ANOVA table computed by \code{anova()}, \code{Anova()},
#' or \code{linearHypothesis()}. Only \code{test = "F"} is supported by \code{anova()}; this is also
#' the default for \code{Anova()} and \code{linearHypothesis()}, which also allow \code{test = "Chisq"} for
#' asymptotic tests.
#' @param hypothesis.matrix,rhs For formulating a linear hypothesis; see the documentation
#' for \code{\link[car]{linearHypothesis}} for details.
#' @param formula. To update model.
#' @param evaluate If \code{TRUE}, the default, the updated model is evaluated; if \code{FALSE} the updated call is returned.
#' @param complete If \code{TRUE}, the default, the returned coefficient vector (for \code{coef()}) or coefficient-covariance matrix (for \code{vcov}) includes elements for aliased regressors.
#' @param parm  parameters for which confidence intervals are to be computed; a vector or numbers or names; the default is all parameters.
#' @param level confidence level; the default is \code{0.95}.
#' @param ... arguments to pass down.
#'
#' @importFrom stats model.matrix vcov .vcov.aliased terms predict update anova quantile weighted.mean delete.response lm lm.fit lm.wfit model.offset na.pass pchisq 
#' @importFrom lmtest coeftest waldtest waldtest.default lrtest lrtest.default
#' @importFrom car linearHypothesis
#' @import Formula

#' @rdname ivregMethods
#' @export
coef.ivreg <- function(object, component = c("stage2", "stage1"), complete = TRUE, ...) {
  component <- match.arg(component, c("stage2", "stage1"))
  ## default: stage 2
  if(component == "stage2") {
    cf <- object$coefficients
  } else if(length(object$endogenous) <= 1L) {
  ## otherwise: stage 1 with single endogenous variable
    cf <- object$coefficients1[, object$endogenous]
  } else {
  ## or: stage 1 with multiple endogenous variables
    cf <- object$coefficients1[, object$endogenous, drop = FALSE]
    cf <- structure(as.vector(cf), .Names = as.vector(t(outer(colnames(cf), rownames(cf), paste, sep = ":"))))
  }
  if (!complete) cf <- cf[!is.na(cf)]
  return(cf)
}

#' @rdname ivregMethods
#' @export
vcov.ivreg <- function(object, component = c("stage2", "stage1"), complete = TRUE, ...) {
  component <- match.arg(component, c("stage2", "stage1"))
  ## default: stage 2
  if(component == "stage2") {
    vc <- object$sigma^2 * object$cov.unscaled
    ok <- !is.na(object$coefficients)
  } else {
  ## otherwise: stage 1
    cf <- object$coefficients1
    if(is.null(cf)) return(NULL)
    ok <- apply(!is.na(cf), 1L, all)
    ucov <- chol2inv(object$qr1$qr[1L:sum(ok), 1L:sum(ok), drop = FALSE])
    rownames(ucov) <- colnames(ucov) <- colnames(object$qr1$qr)[1L:sum(ok)]
    endo <- object$endogenous
    if(length(endo) == 1L) {
      vc <- sum(object$residuals1[, endo]^2)/object$df.residual1 * ucov
    } else {
      sigma2 <- structure(
        crossprod(object$residuals1[, endo])/object$df.residual1,
        .Dimnames = rep.int(list(colnames(object$residuals1)[endo]), 2L)
      )
      vc <- kronecker(sigma2, ucov, make.dimnames = TRUE)
      ok <- structure(
        rep.int(ok, length(endo)),
        .Names = as.vector(t(outer(colnames(cf)[endo], rownames(cf), paste, sep = ":"))))
    }
  }
  vc <- .vcov.aliased(!ok, vc, complete = complete)
  return(vc)
}

#' @rdname ivregMethods
#' @importFrom stats qnorm qt
#' @export
confint.ivreg <- function (object, parm, level = 0.95,
  component = c("stage2", "stage1"), complete = TRUE, vcov. = NULL, df = NULL, ...) 
{
  component <- match.arg(component, c("stage2", "stage1"))
  est <- coef(object, component = component, complete = complete)
  se <- if(is.null(vcov.)) {
    vcov(object, component = component, complete = complete)
  } else {
    if(is.function(vcov.)) {
      vcov.(object, ...)
    } else {
      vcov.
    }
  }
  se <- sqrt(diag(se))
  a <- (1 - level)/2
  a <- c(a, 1 - a)
  if(is.null(df)) df <- if(component == "stage2") object$df.residual else object$df.residual1
  crit <- if(is.finite(df) && df > 0) qt(a, df = df) else qnorm(a)
  ci <- cbind(est + crit[1L] * se, est + crit[2L] * se)
  colnames(ci) <- paste(format(100 * a, trim = TRUE, scientific = FALSE, digits = 3L), "%")
  if(missing(parm) || is.null(parm)) parm <- seq_along(est)
  if(is.character(parm)) parm <- which(names(est) %in% parm)
  ci <- ci[parm, , drop = FALSE]
  ci
}

#' @rdname ivregMethods
#' @exportS3Method sandwich::bread
bread.ivreg <- function (x, ...) 
    x$cov.unscaled * x$nobs

#' @rdname ivregMethods
#' @importFrom stats weights
#' @exportS3Method sandwich::estfun
estfun.ivreg <- function (x, ...) 
{
    xmat <- model.matrix(x, component = "projected")
    if(any(alias <- is.na(coef(x)))) xmat <- xmat[, !alias, drop = FALSE]
    wts <- weights(x)
    if(is.null(wts)) wts <- 1
    res <- residuals(x)
    rval <- as.vector(res) * wts * xmat
    attr(rval, "assign") <- NULL
    attr(rval, "contrasts") <- NULL
    return(rval)
}

#' @rdname ivregMethods
#' @exportS3Method sandwich::vcovHC
vcovHC.ivreg <- function (x, ...) {
    class(x) <- c("ivreg_projected", "ivreg")
    sandwich::vcovHC.default(x, ...)
}

#' #' @rdname ivregMethods
#' #' @export
#' hatvalues.ivreg <- function(model, ...) {
#'   xz <- model.matrix(model, component = "projected")
#'   x  <- model.matrix(model, component = "regressors")
#'   z  <- model.matrix(model, component = "instruments")
#'   solve_qr <- function(x) chol2inv(qr.R(qr(x)))
#'   diag(x %*% solve_qr(xz) %*% t(x) %*% z %*% solve_qr(z) %*% t(z))
#' }

#' @rdname ivregMethods
#' @export
terms.ivreg <- function(x, component = c("regressors", "instruments", "full"), ...)
  x$terms[[match.arg(component, c("regressors", "instruments", "full"))]]

#' @rdname ivregMethods
#' @export
model.matrix.ivreg <- function(object, component = c("regressors", "projected", "instruments"), ...) {
  component <- match.arg(component, c("regressors", "projected", "instruments"))
  if(!is.null(object$x)) rval <- object$x[[component]]
    else if(!is.null(object$model)) {
      X <- model.matrix(object$terms$regressors, object$model, contrasts.arg = object$contrasts$regressors)
      Z <- if(is.null(object$terms$instruments)) NULL
        else model.matrix(object$terms$instruments, object$model, contrasts.arg = object$contrasts$instruments)
      w <- weights(object)
      XZ <- if(is.null(Z)) {
        X
      } else if(is.null(w)) {
        lm.fit(Z, X)$fitted.values
      } else {
        lm.wfit(Z, X, w)$fitted.values
      }
      if(is.null(dim(XZ))) {
        XZ <- matrix(XZ, ncol = 1L, dimnames = list(names(XZ), colnames(X)))
	attr(XZ, "assign") <- attr(X, "assign")
      }
      rval <- switch(component,
        "regressors" = X,
	"instruments" = Z,
	"projected" = XZ)
    } else stop("not enough information in fitted model to return model.matrix")
  return(rval)
}

#' @rdname ivregMethods
#' @export
model.matrix.ivreg_projected <- function(object, ...) model.matrix.ivreg(object, component = "projected")


#' @rdname ivregMethods
#' @param type For \code{predict}, one of \code{"response"} (the default)  or \code{"terms"};
#' for \code{residuals}, one of \code{"response"} (the default), \code{"projected"}, \code{"regressors"},
#' \code{"working"}, \code{"deviance"}, \code{"pearson"}, or \code{"partial"}; 
#' \code{type = "working"} and \code{"response"} are equivalent, as are 
#' \code{type = "deviance"} and \code{"pearson"}; for \code{weights}, \code{"variance"} (the default)
#' for invariance-variance weights (which is \code{NULL} for an unweighted fit) 
#' or \code{"robustness"} for robustness weights (available for M or MM estimation).
#' @param se.fit Compute standard errors of predicted values (default \code{FALSE}).
#' @param interval Type of interval to compute for predicted values: \code{"none"} (the default),
#' \code{"confidence"} for confidence intervals for the expected response, or \code{"prediction"} for
#' prediction intervals for future observations.
#' @param level for confidence or prediction intervals, default \code{0.95}.
#' @param weights Either a numeric vector or a one-sided formula to provide weights for prediction
#' intervals when the fit is weighted. If \code{weights} and \code{newdata} are missing, the weights
#' are those used for fitting the model.
#' 
#' @importFrom stats fitted
#' @export
predict.ivreg <- function(object, newdata, type = c("response", "terms"), na.action = na.pass,
                          se.fit = FALSE, interval = c("none", "confidence", "prediction"), 
                          df = Inf, level = 0.95, weights, ...)
{
  ## type of prediction and type of confidence interval (if any)
  type <- match.arg(type, c("response", "terms"))
  interval <- match.arg(interval, c("none", "confidence", "prediction"))
  
  if (type == "response") {
    ## stage 2 regressor matrix
    if (missing(newdata)) {
      X <- model.matrix(object, component = "regressors")
    } else {
      mf <- model.frame(delete.response(terms(object, component = "full")),
                        data = newdata, na.action = na.action, xlev = object$levels)
      X <- model.matrix(delete.response(terms(object, component = "regressors")),
                        data = mf, contrasts.arg = object$contrasts$regressors)
    }
    
    ## coefficients
    cf <- coef(object, component = "stage2")
    ok <- !is.na(cf)
    if (any(!ok)) warning("aliased coefficients in model, dropped\n")
    
    ## fitted values
    yhat <- drop(X[, ok, drop = FALSE] %*% cf[ok])
    
    ## standard errors and intervals: none
    if (!se.fit && interval == "none") {
      if (missing(newdata)){
        return(naresid(object$na.action, yhat))
      } else{ 
        return(yhat)
      }
    } else {
      X <- X[, ok, drop = FALSE]
      V <- vcov(object, component = "stage2", complete = FALSE)
      n <- nrow(X)
      se <- numeric(n)
      for (i in 1L:n) se[i] <- X[i,] %*% V %*% X[i,]
      se <- sqrt(se)
      result <- if (se.fit) {
        cbind(fit = yhat, se.fit = se)
      } else {
        matrix(yhat, dimnames = list(NULL, "fit"))
      }
      if (interval == "none"){
        if (missing(newdata)){
          return(naresid(object$na.action, result))
        } else {
          return(result)
        }
      }
      if (is.null(df)) df <- df.residual(object)
      t.crit <- qt((1 - level) / 2, df = df, lower.tail = FALSE)
      if (interval == "confidence") {
        lwr <- yhat - t.crit * se
        upr <- yhat + t.crit * se
      } else {
        wts <- 1
        
        # ------- the following code adapted from predict.lm() --------#
        
        if (missing(newdata)){
          warning("predictions on current data refer to future responses\n")
        }
        if (missing(newdata) && missing(weights)) {
          w <- weights(object, type = "variance")
          if (!is.null(w)) {
            wts <- w
            warning("assuming prediction variance inversely proportional to weights used for fitting\n")
          }
        }
        if (!missing(newdata) && missing(weights) && !is.null(object$weights)) {
          warning("assuming constant prediction variance even though model fit is weighted\n")
        }
        if (!missing(weights)) {
          if (inherits(weights, "formula")) {
            if (length(weights) != 2L){
              stop("'weights' as formula should be one-sided")
            }
            d <- if (missing(newdata)) {
              model.frame(object)
            } else {
              newdata
            }
            wts <- eval(weights[[2L]], d, environment(weights))
          } else {
            wts <- weights
          }
        }
        
        # --------------- end of adapted code ----------------#
        
        sigma <- sigma(object)
        se.tot <- sqrt(se^2 + wts * sigma^2)
        lwr <- yhat - t.crit * se.tot
        upr <- yhat + t.crit * se.tot
      }
      result <- cbind(result, lwr = lwr, upr = upr)
      if (missing(newdata)){
        return(naresid(object$na.action, result))
      } else {
        return(result)
      }
    }
  } else {
    .Class <- "lm"
    suppressWarnings(NextMethod())
  }
}

# predict.ivreg <- function(object, newdata, type = c("response", "terms"), na.action = na.pass,  ...)
# {
#   type <- match.arg(type, c("response", "terms"))
#   if (type == "response"){
#     if(missing(newdata)) fitted(object)
#     else {
#       mf <- model.frame(delete.response(object$terms$full), newdata,
#                         na.action = na.action, xlev = object$levels)
#       X <- model.matrix(delete.response(object$terms$regressors), mf,
#                         contrasts.arg = object$contrasts$regressors)
#       ok <- !is.na(object$coefficients)
#       drop(X[, ok, drop = FALSE] %*% object$coefficients[ok])
#     } 
#   } else {
#       .Class <- "lm"
#       suppressWarnings(NextMethod())
#   }
# }

#' @rdname ivregMethods
#' @export
print.ivreg <- function(x, digits = max(3, getOption("digits") - 3), ...)
{
  cat("\nCall:\n", deparse(x$call), "\n\n", sep = "")
  cat("Coefficients:\n")
  print.default(format(coef(x), digits = digits), print.gap = 2, quote = FALSE)
  cat("\n")
  invisible(x)
}

#' @rdname ivregMethods
#' @export
summary.ivreg <- function(object, vcov. = NULL, df = NULL, diagnostics = NULL, ...)
{
  # prevent some "inherited" "lm" methods from failing
  if(is.null(diagnostics)) diagnostics <- (length(object$endogenous) > 0L) && (length(object$instruments) > 0L)
  if(diagnostics && ((length(object$endogenous) <= 0L) || (length(object$instruments) <= 0L) || (length(formula(object, component="instruments")) <= 0L))) {
    diagnostics <- FALSE
    warning("diagnostics cannot be computed without endogenous/instrument variables")
  }
  
  ## weighted residuals
  res <- object$residuals
  y <- object$fitted.values + res
  n <- NROW(res)
  w <- object$weights
  if(is.null(w)) w <- rep(1, n)
  res <- res * sqrt(w)

  ## R-squared
  rss <- sum(res^2)
  if(attr(object$terms$regressors, "intercept")) {
    tss <- sum(w * (y - weighted.mean(y, w))^2)
    dfi <- 1    
  } else {
    tss <- sum(w * y^2)
    dfi <- 0
  }
  r.squared <- 1 - rss/tss
  adj.r.squared <- 1 - (1 - r.squared) * ((n - dfi)/object$df.residual)
  
  ## degrees of freedom (for z vs. t test)
  if(is.null(df)) df <- object$df.residual
  if(!is.finite(df)) df <- 0
  if(df > 0 & (df != object$df.residual)) {
    df <- object$df.residual
  }

  ## covariance matrix
  if(is.null(vcov.)) 
      vc <- vcov(object)
  else {
      if(is.function(vcov.)) vc <- vcov.(object)
        else vc <- vcov.
  }
  
  ## Wald test of each coefficient
  cf <- lmtest::coeftest(object, vcov. = vc, df = df, ...)
  attr(cf, "method") <- NULL
  class(cf) <- "matrix"
  
  ## Wald test of all coefficients
  Rmat <- if(attr(object$terms$regressors, "intercept"))
    cbind(0, diag(length(na.omit(coef(object)))-1)) else diag(length(na.omit(coef(object))))
  waldtest <- car::linearHypothesis(object, Rmat, vcov. = vcov., test = ifelse(df > 0, "F", "Chisq"), singular.ok = TRUE)
  waldtest <- c(waldtest[2, "F"], waldtest[2, "Pr(>F)"], waldtest[2, "Df"], if(df > 0) waldtest[2, "Res.Df"] else NULL)
  
  ## diagnostic tests
  diag <- if(diagnostics) ivdiag(object, vcov. = vcov.) else NULL
  
  rval <- list(
    call = object$call,
    terms = object$terms,
    residuals = res,
    weights <- object$weights,
    coefficients = cf,
    sigma = object$sigma,
    df = c(object$rank, if(df > 0) df else Inf, object$rank), ## aliasing
    r.squared = r.squared,
    adj.r.squared = adj.r.squared,
    waldtest = waldtest,
    vcov = vc,
    diagnostics = diag)
    
  class(rval) <- "summary.ivreg"
  return(rval)
}

#' @rdname ivregMethods
#' @importFrom stats printCoefmat
#' @export
#' @method print summary.ivreg
print.summary.ivreg <- function(x, digits = max(3, getOption("digits") - 3), 
    signif.stars = getOption("show.signif.stars"), ...)
{
  cat("\nCall:\n")
  cat(paste(deparse(x$call), sep = "\n", collapse = "\n"), "\n\n", sep = "")

  cat(if(!is.null(x$weights) && diff(range(x$weights))) "Weighted ", "Residuals:\n", sep = "")      
  if(NROW(x$residuals) > 5L) {
      nam <- c("Min", "1Q", "Median", "3Q", "Max")
      rq <- if(length(dim(x$residuals)) == 2) 
	  structure(apply(t(x$residuals), 1, quantile), dimnames = list(nam, dimnames(x$residuals)[[2]]))
      else structure(quantile(x$residuals), names = nam)
      print(rq, digits = digits, ...)
  } else {
      print(x$residuals, digits = digits, ...)
  }

  cat("\nCoefficients:\n")
  printCoefmat(x$coefficients, digits = digits, signif.stars = signif.stars,
    signif.legend = signif.stars & is.null(x$diagnostics), na.print = "NA", ...)

  if(!is.null(x$diagnostics)) {
    cat("\nDiagnostic tests:\n")
    printCoefmat(x$diagnostics, cs.ind = 1L:2L, tst.ind = 3L,
      has.Pvalue = TRUE, P.values = TRUE, digits = digits,
      signif.stars = signif.stars, na.print = "NA", ...)  
  }

  cat("\nResidual standard error:", format(signif(x$sigma, digits)),
    "on", x$df[2L], "degrees of freedom\n")

  cat("Multiple R-Squared:", formatC(x$r.squared, digits = digits))
  cat(",\tAdjusted R-squared:", formatC(x$adj.r.squared, digits = digits),
    "\nWald test:", formatC(x$waldtest[1L], digits = digits),
    "on", x$waldtest[3L], if(length(x$waldtest) > 3L) c("and", x$waldtest[4L]) else NULL,       
    "DF,  p-value:", format.pval(x$waldtest[2L], digits = digits), "\n\n")

  invisible(x)
}

#' @rdname ivregMethods
#' @export    
anova.ivreg <- function(object, object2, test = "F", vcov. = NULL, ...)
{
  rval <- waldtest(object, object2, test = test, vcov = vcov.)
  if(is.null(vcov.)) {
    head <- attr(rval, "heading")
    head[1] <- "Analysis of Variance Table\n"
    rss <- sapply(list(object, object2), function(x) sum(residuals(x)^2))
    dss <- c(NA, -diff(rss))
    rval <- cbind(rval, cbind("RSS" = rss, "Sum of Sq" = dss))[,c(1L, 5L, 2L, 6L, 3L:4L)]
    attr(rval, "heading") <- head
    class(rval) <- c("anova", "data.frame")
  }
  return(rval)
}

#' @rdname ivregMethods
#' @importFrom stats getCall
#' @export
update.ivreg <- function (object, formula., ..., evaluate = TRUE)
{
  if(is.null(call <- getCall(object))) stop("need an object with call component")
  extras <- match.call(expand.dots = FALSE)$...
  if(!missing(formula.)) call$formula <- formula(update(Formula(formula(object, component = "complete")), formula.))
  if(length(extras)) {
    existing <- !is.na(match(names(extras), names(call)))
    for (a in names(extras)[existing]) call[[a]] <- extras[[a]]
    if(any(!existing)) {
      call <- c(as.list(call), extras[!existing])
      call <- as.call(call)
    }
  }
  if(evaluate) eval(call, parent.frame())
  else call
}

#' @importFrom stats model.frame model.response pf
ivdiag <- function(obj, vcov. = NULL) {
  ## extract data
  y <- model.response(model.frame(obj))
  x <- model.matrix(obj, component = "regressors")
  z <- model.matrix(obj, component = "instruments")
  w <- weights(obj)
  
  ## names of "regressors" and "instruments"
  xnam <- colnames(x)
  znam <- colnames(z)

  ## endogenous/instrument variables
  endo <- obj$endogenous
  inst <- obj$instruments
  if((length(endo) <= 0L) | (length(inst) <= 0L))
    stop("no endogenous/instrument variables")

  ## return value
  rval <- matrix(NA, nrow = length(endo) + 2L, ncol = 4L)
  colnames(rval) <- c("df1", "df2", "statistic", "p-value")
  rownames(rval) <- c(if(length(endo) > 1L) paste0("Weak instruments (", xnam[endo], ")") else "Weak instruments",
    "Wu-Hausman", "Sargan")
  
  ## convenience functions
  lmfit <- function(x, y, w = NULL) {
    rval <- if(is.null(w)) lm.fit(x, y) else lm.wfit(x, y, w)
    rval$x <- x
    rval$y <- y
    return(rval)
  }
  rss <- function(obj, weights = NULL) if(is.null(weights)) sum(obj$residuals^2) else sum(weights * obj$residuals^2)
  wald <- function(obj0, obj1, vcov. = NULL, weights = NULL) {
    df <- c(obj1$rank - obj0$rank, obj1$df.residual)
    if(!is.function(vcov.)) {
      w <- ((rss(obj0, w) - rss(obj1, w)) / df[1L]) / (rss(obj1, w)/df[2L])
    } else {
      if(NCOL(obj0$coefficients) > 1L) {
        cf0 <- structure(as.vector(obj0$coefficients),
	  .Names = c(outer(rownames(obj0$coefficients), colnames(obj0$coefficients), paste, sep = ":")))
        cf1 <- structure(as.vector(obj1$coefficients),
	  .Names = c(outer(rownames(obj1$coefficients), colnames(obj1$coefficients), paste, sep = ":")))
      } else {
        cf0 <- obj0$coefficients
        cf1 <- obj1$coefficients
      }
      cf0 <- na.omit(cf0)
      cf1 <- na.omit(cf1)
      ovar <- which(!(names(cf1) %in% names(cf0)))
      vc <- vcov.(lm(obj1$y ~ 0 + obj1$x, weights = w))
      w <- t(cf1[ovar]) %*% solve(vc[ovar,ovar]) %*% cf1[ovar]
      w <- w / df[1L]
    }
    pval <- pf(w, df[1L], df[2L], lower.tail = FALSE)
    c(df, w, pval)
  }
    
  # Test for weak instruments
  for(i in seq_along(endo)) {
  aux0 <- lmfit(z[, -inst, drop = FALSE], x[, endo[i]], w)
  aux1 <- lmfit(z,                        x[, endo[i]], w)
  rval[i, ] <- wald(aux0, aux1, vcov. = vcov., weights = w)
  }

  ## Wu-Hausman test for endogeneity
  if(length(endo) > 1L) aux1 <- lmfit(z, x[, endo], w)
  xfit <- as.matrix(aux1$fitted.values)
  colnames(xfit) <- paste("fit", colnames(xfit), sep = "_")
  auxo <- lmfit(      x,        y, w)
  auxe <- lmfit(cbind(x, xfit), y, w)
  rval[nrow(rval) - 1L, ] <- wald(auxo, auxe, vcov. = vcov., weights = w)

  ## Sargan test of overidentifying restrictions 
  r <- residuals(obj)  
  auxs <- lmfit(z, r, w)
  rssr <- if(is.null(w)) sum((r - mean(r))^2) else sum(w * (r - weighted.mean(r, w))^2)
  rval[nrow(rval), 1L] <- length(inst) - length(endo)
  if(rval[nrow(rval), 1L] > 0L) {
    rval[nrow(rval), 3L] <- length(r) * (1 - rss(auxs, w)/rssr)
    rval[nrow(rval), 4L] <- pchisq(rval[nrow(rval), 3L], rval[nrow(rval), 1L], lower.tail = FALSE)
  }

  return(rval)
}

## If #Instruments = #Regressors then
##   b = (Z'X)^{-1} Z'y
## and solves the estimating equations
##   Z' (y - X beta) = 0
## For
##   cov(y) = Omega
## the following holds
##   cov(b) = (Z'X)^{-1} Z' Omega Z (X'Z)^{-1}
##   
## Generally:  
##   b = (X' P_Z X)^{-1} X' P_Z y
## with estimating equations
##   X' P_Z (y - X beta) = 0
## where P_Z is the usual projector (hat matrix wrt Z) and
##   cov(b) = (X' P_Z X)^{-1} X' P_Z Omega P_Z X (X' P_Z X)^{-1}
## Thus meat is X' P_Z Omega P_Z X and bread i (X' P_Z X)^{-1}
## 
## See
##   http://www.stata.com/support/faqs/stat/2sls.html

#' @rdname ivregMethods
#' @importFrom stats residuals
#' @export
residuals.ivreg <- function(object, type=c("response", "projected", "regressors", "working",
                                            "deviance", "pearson", "partial", "stage1"), ...){
  type <- match.arg(type, c("response", "projected", "regressors", "working", "deviance", "pearson", "partial", "stage1"))
  w <- weights(object)
  if (is.null(w)) w <- 1
  res <- switch(type,
                working  =,
                response  = object$residuals,
                deviance =,
                pearson  = sqrt(w)*object$residuals,
                projected   = object$residuals1,
                regressors  = object$residuals2,
                partial  = object$residuals + predict(object, type = "terms"),
		stage1 = object$residuals1[, object$endogenous, drop = FALSE])
  naresid(object$na.action, res)
}

#' @rdname ivregMethods
#' @param focal.predictors Focal predictors for effect plot, see \code{\link[effects:effect]{Effect}}.
#' @exportS3Method effects::Effect
Effect.ivreg <- function (focal.predictors, mod, ...) {
  mod$contrasts <- mod$contrasts$regressors
  NextMethod()
}

#' @rdname ivregMethods
#' @importFrom stats formula
#' @export
formula.ivreg <- function(x, component = c("complete", "regressors", "instruments"), ... ) {
  component <- match.arg(component, c("complete", "regressors", "instruments"))
  if (component == "complete"){
    class(x) <- "default"
    formula(x)
    
  } else {
    formula(x$terms[[component]])
  }
}

#' @rdname ivregMethods
#' @exportS3Method insight::find_formula 
find_formula.ivreg <- function(x, ...) {
    list(conditional=formula(x, "regressors"), instruments=formula(x, "instruments"))
}

#' @rdname ivregMethods
#' @importFrom car Anova
#' @export
Anova.ivreg <- function(mod, test.statistic=c("F", "Chisq"), ...){
  test.statistic <- match.arg(test.statistic, c("F", "Chisq"))
  NextMethod(test.statistic=test.statistic)
}

#' @rdname ivregMethods
#' @export
linearHypothesis.ivreg <- function(model, hypothesis.matrix, rhs=NULL, 
                                   test=c("F", "Chisq"), ...){
  test <- match.arg(test, c("F", "Chisq"))
  NextMethod(test=test)
}

#' @importFrom stats alias
#' @rdname ivregMethods
#' @export
alias.ivreg <- function(object, ...){
    .Class <- "lm"
    NextMethod()
}

#' @rdname ivregMethods
#' @export
qr.ivreg <- function(x, ...){
    .Class <- "lm"
    NextMethod()
}

#' @rdname ivregMethods
#' @export
weights.ivreg <- function(object, type=c("variance", "robustness"), ...){
  type <- match.arg(type, c("variance", "robustness"))
  if (type == "variance") object$weights else object$rweights
}
