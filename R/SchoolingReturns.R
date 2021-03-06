#' U.S. Returns to Schooling Data
#'
#' Data from the U.S. National Longitudinal Survey of Young Men (NLSYM) in 1976
#' but using some variables dating back to earlier years.
#'
#' Investigating the causal link of schooling on earnings in a classical model
#' for wage determinants is problematic because it can be argued that schooling
#' is endogenous. Hence, one possible strategy is to use an exogonous variable
#' as an instrument for the years of education. In his well-known study, Card (1995)
#' uses geographical proximity to a college when growing up as such an instrument,
#' showing that this significantly increases both the years of education and the
#' wage level obtained on the labor market. Using instrumental variables regression
#' Card (1995) shows that the estimated returns to schooling are much higher than
#' when simply using ordinary least squares.
#' 
#' The data are taken from the supplementary material for Verbeek (2004) and are based
#' on the work of Card (1995). The U.S. National Longitudinal Survey of Young Men
#' (NLSYM) began in 1966 and included 5525 men, then aged between 14 and 24.
#' Card (1995) employs labor market information from the 1976 NLSYM interview which
#' also included information about educational attainment. Out of the 3694 men
#' still included in that wave of NLSYM, 3010 provided information on both wages
#' and education yielding the subset of observations provided in \code{SchoolingReturns}.
#'
#' The examples replicate the results from Verbeek (2004) who used the simplest
#' specifications from Card (1995). Including further region or family background
#' characteristics improves the model significantly but does not affect much the
#' main coefficients of interest, namely that of years of education.
#'
#' @usage data("SchoolingReturns", package = "ivreg")
#'
#' @format A data frame with 3010 rows and 22 columns.
#' \describe{
#'   \item{wage}{Raw wages in 1976 (in cents per hour).}
#'   \item{education}{Education in 1976 (in years).}
#'   \item{experience}{Years of labor market experience, computed as \code{age - education - 6}.}
#'   \item{ethnicity}{Factor indicating ethnicity. Is the individual African-American
#'     (\code{"afam"}) or not (\code{"other"})?}
#'   \item{smsa}{Factor. Does the individual reside in a SMSA (standard metropolitan statistical area) in 1976?}
#'   \item{south}{Factor. Does the individual reside in the South in 1976?}
#'   \item{age}{Age in 1976 (in years).}
#'   \item{nearcollege}{Factor. Did the individual grow up near a 4-year college?}
#'   \item{nearcollege2}{Factor. Did the individual grow up near a 2-year college?}
#'   \item{nearcollege4}{Factor. Did the individual grow up near a 4-year public or private college?}
#'   \item{enrolled}{Factor. Is the individual enrolled in college in 1976?}
#'   \item{married}{factor. Is the individual married in 1976?}
#'   \item{education66}{Education in 1966 (in years).}
#'   \item{smsa66}{Factor. Does the individual reside in a SMSA in 1966?}
#'   \item{south66}{Factor. Does the individual reside in the South in 1966?}
#'   \item{feducation}{Father's educational attainment (in years). Imputed with average if missing.}
#'   \item{meducation}{Mother's educational attainment (in years). Imputed with average if missing.}
#'   \item{fameducation}{Ordered factor coding family education class (from 1 to 9).}
#'   \item{kww}{Knowledge world of work (KWW) score.}
#'   \item{iq}{Normed intelligence quotient (IQ) score}
#'   \item{parents14}{Factor coding living with parents at age 14:
#'     both parents, single mother, step parent, other}
#'   \item{library14}{Factor. Was there a library card in home at age 14?}
#'   }
#'
#' @source Supplementary material for Verbeek (2004).
#' @references Card, D. (1995). Using Geographical Variation in College Proximity to Estimate the Return to
#'   Schooling. In: Christofides, L.N., Grant, E.K., and Swidinsky, R. (eds.),
#'   \emph{Aspects of Labour Market Behaviour: Essays in Honour of John Vanderkamp},
#'   University of Toronto Press, Toronto, 201-222.
#' 
#' Verbeek, M. (2004). \emph{A Guide to Modern Econometrics}, 2nd ed. John Wiley.
#'
#' @examples
#' ## load data
#' data("SchoolingReturns", package = "ivreg")
#' 
#' ## Table 5.1 in Verbeek (2004) / Table 2(1) in Card (1995)
#' ## Returns to education: 7.4%
#' m_ols <- lm(log(wage) ~ education + poly(experience, 2, raw = TRUE) + ethnicity + smsa + south,
#'   data = SchoolingReturns)
#' summary(m_ols)
#' 
#' ## Table 5.2 in Verbeek (2004) / similar to Table 3(1) in Card (1995)
#' m_red <- lm(education ~ poly(age, 2, raw = TRUE) + ethnicity + smsa + south + nearcollege,
#'   data = SchoolingReturns)
#' summary(m_red)
#' 
#' ## Table 5.3 in Verbeek (2004) / similar to Table 3(5) in Card (1995)
#' ## Returns to education: 13.3%
#' m_iv <- ivreg(log(wage) ~ education + poly(experience, 2, raw = TRUE) + ethnicity + smsa + south |
#'   nearcollege + poly(age, 2, raw = TRUE) + ethnicity + smsa + south,
#'   data = SchoolingReturns)
#' summary(m_iv)
"SchoolingReturns"
