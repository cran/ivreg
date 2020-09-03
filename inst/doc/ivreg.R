## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(echo = TRUE, fig.height=4, fig.width=4)

## ----installation-cran, eval=FALSE--------------------------------------------
#  install.packages("ivreg", dependencies = TRUE)

## ----installation-rforge, eval=FALSE------------------------------------------
#  remotes::install_github("https://github.com/john-d-fox/ivreg/")

## ----data---------------------------------------------------------------------
data("SchoolingReturns", package = "ivreg")
summary(SchoolingReturns[, 1:8])

## ----lm-----------------------------------------------------------------------
m_ols <- lm(log(wage) ~ education + poly(experience, 2) + ethnicity + smsa + south,
  data = SchoolingReturns)
summary(m_ols)

## ----ivreg--------------------------------------------------------------------
library("ivreg")
m_iv <- ivreg(log(wage) ~ education + poly(experience, 2) + ethnicity + smsa + south |
  nearcollege + poly(age, 2) + ethnicity + smsa + south,
  data = SchoolingReturns)
summary(m_iv)

## ----compareCoefs-------------------------------------------------------------
car::compareCoefs(m_ols, m_iv)

