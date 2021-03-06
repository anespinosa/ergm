#  File R/logLik.ergm.R in package ergm, part of the Statnet suite
#  of packages for network analysis, https://statnet.org .
#
#  This software is distributed under the GPL-3 license.  It is free,
#  open source, and has the attribution requirements (GPL Section 7) at
#  https://statnet.org/attribution
#
#  Copyright 2003-2020 Statnet Commons
#######################################################################
## A function to compute and return the log-likelihood of an ERGM MLE.


#' A \code{\link{logLik}} method for [`ergm`] fits.
#' 
#' A function to return the log-likelihood associated with an
#' \code{\link[=ergm.object]{ergm}} fit, evaluating it if
#' necessary. If the log-likelihood was not computed for
#' \code{object}, produces an error unless \code{eval.loglik=TRUE}.
#' 
#' @param object An \code{\link[=ergm.object]{ergm}} fit, returned by
#'   \code{\link{ergm}}.
#' @param add Logical: If `TRUE`, instead of returning the
#'   log-likelihood, return \code{object} with log-likelihood value
#'   set.
#' @param force.reeval Logical: If `TRUE`, reestimate the
#'   log-likelihood even if \code{object} already has an estiamte.
#' @param eval.loglik Logical: If `TRUE`, evaluate the log-likelihood
#'   if not set on \code{object}.
#' @param control A list of control parameters for algorithm tuning.
#'   Constructed using \code{\link{control.logLik.ergm}}.
#' @param \dots Other arguments to the likelihood functions.
#' @return The form of the output of \code{logLik.ergm} depends on
#'   \code{add}: \code{add=FALSE} (the default), a
#'   \code{\link{logLik}} object. If \code{add=TRUE} (the default), an
#'   \code{\link[=ergm.object]{ergm}} object with the log-likelihood
#'   set.
#' 
#'   As of version 3.1, all likelihoods for which \code{logLikNull} is
#'   not implemented are computed relative to the reference
#'   measure. (I.e., a null model, with no terms, is defined to have
#'   likelihood of 0, and all other models are defined relative to
#'   that.)
#' @seealso \code{\link{logLik}}, \code{\link{logLikNull}}, \code{\link{ergm.bridge.llr}},
#'   \code{\link{ergm.bridge.dindstart.llk}}
#' @references Hunter, D. R. and Handcock, M. S. (2006)
#'   \emph{Inference in curved exponential family models for
#'   networks}, Journal of Computational and Graphical Statistics.
#' @keywords models
#' @examples
#' 
#' # See help(ergm) for a description of this model. The likelihood will
#' # not be evaluated.
#' data(florentine)
#' \dontrun{
#' # The default maximum number of iterations is currently 20. We'll only
#' # use 2 here for speed's sake.
#' gest <- ergm(flomarriage ~ kstar(1:2) + absdiff("wealth") + triangle, eval.loglik=FALSE)
#' 
#' gest <- ergm(flomarriage ~ kstar(1:2) + absdiff("wealth") + triangle, eval.loglik=FALSE,
#'              control=control.ergm(MCMLE.maxit=2))
#' # Log-likelihood is not evaluated, so no deviance, AIC, or BIC:
#' summary(gest)
#' # Evaluate the log-likelihood and attach it to the object.
#' 
#' # The default number of bridges is currently 20. We'll only use 3 here
#' # for speed's sake.
#' gest.logLik <- logLik(gest, add=TRUE)
#' 
#' gest.logLik <- logLik(gest, add=TRUE, control=control.logLik.ergm(nsteps=3))
#' # Deviances, AIC, and BIC are now shown:
#' summary(gest.logLik)
#' # Null model likelihood can also be evaluated, but not for all constraints:
#' logLikNull(gest) # == network.dyadcount(flomarriage)*log(1/2)
#' }
#' 
#' @export
logLik.ergm<-function(object, add=FALSE, force.reeval=FALSE, eval.loglik=add || force.reeval, control=control.logLik.ergm(), ...){

  if(!force.reeval && !is.null(object$mle.lik)) return(object$mle.lik)

  # Then, we need to recalculate...
  
  check.control.class("logLik.ergm", "logLik.ergm")
  control.toplevel("logLik.ergm", ...)
 
  control.transfer <- c("MCMC.burnin", "MCMC.interval", "MCMC.prop.weights",
"MCMC.prop.args", "MCMC.packagenames", "MCMC.init.maxedges", "MCMC.samplesize",
"obs.MCMC.burnin", "obs.MCMC.interval", "obs.MCMC.samplesize","MPLE.type","MPLE.max.dyad.types","parallel","parallel.type","parallel.version.check","term.options"
)
  for(arg in control.transfer)
    if(is.null(control[[arg]]))
      control[arg] <- list(object$control[[arg]])

  control <- set.control.class("control.ergm.bridge")

  # "object" has an element control.
  loglik.control<-control
  
  out<-with(object,
            {
              if(!eval.loglik) stop(NO_LOGLIK_MESSAGE)
              
              ## If dyad-independent or MPLE, just go from the deviance.
              if(object$estimate=="MPLE"
                 || (is.dyad.independent(object, term.options=control$term.options)
                     && is.null(object$sample)
                     && is.null(object$response)))
			 if(control$MPLE.type=="penalized")
				 object$glm$loglik - object$glm.null$loglik else
                -object$glm$deviance/2 - -object$glm$null.deviance/2
              else
                ## If dyad-dependent but not valued and has a dyad-independent constraint, bridge from a dyad-independent model.
                if(is.dyad.independent(object$constrained, object$constrained.obs)
                   && is.null(object$response))
                  ergm.bridge.dindstart.llk(formula,reference=reference,constraints=constraints,coef=coef(object),control=loglik.control,llkonly=FALSE,...)
                else
                  ## If valued or has dyad-dependent constraint, compute a path sample from reference measure.
                  ergm.bridge.0.llk(formula,response=object$response,reference=reference,constraints=constraints,coef=coef(object),control=loglik.control,llkonly=FALSE,...)
            }
            )
  
  if(is.numeric(out)){
    llk<-out
  }else{
    llk<-out$llk
    attr(llk,"br")<-out
  }
  if(!inherits(llk,"logLik")){
    class(llk)<-"logLik"
    attr(llk,"df")<-nparam(object, offset=FALSE)
    attr(llk,"nobs")<- nobs(object, ...)
  }

  if(!is.null(object$null.lik) && !is.na(object$null.lik)){ # If Null likelihood is defined, shift the MLE likelihood.
    llk[] <- c(llk + object$null.lik) # The brackets are important to preserve attr()s on llk, and the c() is important to strip the ones from the sum.
  }
  
  if(add){
    object$mle.lik<-llk
    object    
  } else llk
}

NO_LOGLIK_MESSAGE <- paste0("Log-likelihood was not estimated for this fit. To get deviances, AIC, and/or BIC, use ",sQuote("*fit* <-logLik(*fit*, add=TRUE)")," to add it to the object or rerun this function with eval.loglik=TRUE.")

#' Calculate the null model likelihood
#'
#' @param object a fitted model.
#' @param ... further arguments to lower-level functions.
#' 
#' \code{logLikNull} computes, when possible the log-probability of
#' the data under the null model (reference distribution).
#' 
#' @return
#' \code{logLikNull} returns an object of type \code{\link{logLik}} if it is
#' able to compute the null model probability, and \code{NA} otherwise.
#' @export
logLikNull <- function(object, ...) UseMethod("logLikNull")

#' @describeIn logLikNull A method for [`ergm`] fits; currently only
#'   implemented for binary ERGMs with dyad-independent sample-space
#'   constraints.
#' @param control A list of control parameters for algorithm tuning.
#'   Constructed using \code{\link{control.logLik.ergm}}.
#' @export
logLikNull.ergm <- function(object, control=control.logLik.ergm(), ...){
  check.control.class("logLik.ergm", "logLikNull.ergm")

  control.toplevel("logLik.ergm", ...)
  if(!is.null(object$null.lik)) return(object$null.lik)
  
  nobs <- nobs(object,...)

  llk <-
    if(!is.null(object$response)){
      message(paste(strwrap(paste("Note: Null model likelihood calculation is not implemented for valued ERGMs at this time. ", NO_NULL_IMPLICATION)), collapse="\n"))
      NA
    }else if(!is.dyad.independent(object$constrained, object$constrained.obs)){
      message(paste(strwrap(paste("Note: The constraint on the sample space is not dyad-independent. Null model likelihood is only implemented for dyad-independent constraints at this time. Number of observations is similarly poorly defined. ", NO_NULL_IMPLICATION)), collapse="\n"))
      NA
    }else nobs * log(1/2)
  

  class(llk)<-"logLik"
  attr(llk,"df")<-0
  attr(llk,"nobs")<-nobs

  llk
}

#' @describeIn ergm Return the number of informative dyads of a model fit.
#' @export 
nobs.ergm <- function(object, ...){
  # FIXME: We need a more general framework for handling constrained
  # and partially observed network "degrees of freedom". PROGRESS: We
  # can handle dyad-independent ones fine, now.
  
  if(!is.dyad.independent(object$constrained, object$constrained.obs)
     && getOption("ergm.loglik.warn_dyads")){
    warning("The number of observed dyads in this network is ill-defined due to complex constraints on the sample space. Disable this warning with ",sQuote("options(ergm.loglik.warn_dyads=FALSE)"),".")
  }
  
  NVL3(NVL(object$null.lik, object$mle.lik),
       attr(.,"nobs"),
       sum(as.rlebdm(object, which="informative")))
}

NO_NULL_IMPLICATION <- "This means that all likelihood-based inference (LRT, Analysis of Deviance, AIC, BIC, etc.) is only valid between models with the same reference distribution and constraints."
