################################################################################
#' In this script logistic regression models are fit to sample pairs classified
#' as highly related or not. The model is miss-specified since the sample pairs
#' are not independent. The qqnorm plot of the residuals confirms this.
#' Moreover, besides a categorical variable for Ecuador (2 = intra Ecuador; 1 =
#' inter Ecuador and elsewhere; 0 otherwise) no attempt is made to account for
#' different transmission intensities across sites. Unsurprisingly therefore,
#' the fitted model is not very predictive (it severally underestimates high
#' relatedness). Nevertheless, it does provide a general idea of if/how
#' relatedness changes with connectivity between parasites.
#' 
#' In addition to a factor that identifies cities connected by marine traffic
#' (InterMarine 0 unconnected by sea; 1 connected by coast but not a port; 2
#' connected by two ports), three categorical variables are created to
#' potentially include in the model. These are:
#' 
#' International TRUE,FALSE to see if borders reduce connectivity (expect
#' negative coefficient); Ecuador 0,1,2 to separate Colombia and Ecuador within
#' International = FALSE; Batch -1,0,1 to see if there is a batch effect within
#' and across the old and new samples.
#' 
#' Because Ecuador and International are structurally collinear,
#' InternationalTRUE (which is negative) and Ecuador1 (which is positive) are
#' not significant in the full model. Since International = FALSE averages over
#' within Colombia and within Ecuador, which have very different fractions of
#' highly related parasite pairs, we drop International from the final model.
#' (The final model is the model with the lowest AIC for lowest parameter
#' count). We also consider dropping Batch, because it is collinear with
#' year_diff (see coefficient plots and final model vifs, which decrease when
#' Batch is removed from the final model) and to a lesser extent Ecuador (see
#' coefficient plots). However, in the full model, there does appear to be a
#' batch effect. When the data are partitioned into batches there are some
#' inconsistent results, but partitioning into batches severely reduces the
#' number of sites and years, so inclusion of a batch variable in the model is
#' preferred. Importantly, across all the models fit to all data, there are no
#' changes in the signs of the coefficients, with the exception of International
#' whose sign change is understood (collinear with Ecuador).
#' 
#' Final model interpretation, accounting for batch effect: 
#' Being within Ecuador increases the log odds of being highly related
#' Being compared with Ecuador increases the log odds of being highly related
#' Being across ports increases the log odds of being highly related 
#' Being across coastal cities increases the log odds of being highly related 
#' A unit increase in year diff decreases the log odds of being highly related 
#' A unit increase in geo dist decreases the log odds of being highly related 
#' 
#' Alternative approach: Regress estimated per-inter-location-pair probabilities
#' of high-relatedness onto per-location-pair variables (geo_dist, international
#' etc.). This is similar to regressing per-inter-location-pair high-relatedness
#' fractions onto per-location-pair variables, but it adjusts for differences in
#' sampling collection dates. I do this by first fitting a logistic regression
#' to generate per-inter-location-pair effects, which are then regressed onto
#' per-inter-location-pair variables. The final model I arrive at suggests
#' comparisons with Venezuela drive trends in geo_dist, while InterCoast
#' comparisons are significantly more related. However, it's important to note
#' that this 2-step approach is far from ideal. For example, it does not account
#' for uncertainty in the estimated per-location-pair effects, which are based
#' on very different sample counts and shares
##############################################################################
rm(list = ls())
require(dplyr) # For data wrangling
require(tidyr) # For pivot_wider
require(corrplot) # For corrplot
require(gtools) # For combinations
load("../../RData/mles_CIs_extended_freqsTaylor2020_meta.RData")

# Filter uninformative -------------------------------------------------------
eps <- 0.01 # Used to define clones in Taylor et al. 2020
uninformative_ind <- mle_CIs$r2.5. < eps & mle_CIs$r97.5. > 1-eps; sum(uninformative_ind)
mle_CIs <- mle_CIs[!uninformative_ind,]

# Compute fraction highly related by country and city within -----------------
mle_CIs[mle_CIs$geo_dist == 0,] %>% group_by(Country1) %>% 
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(fract) # Fraction highly related within
mle_CIs[mle_CIs$geo_dist == 0,] %>% group_by(City1, Country1) %>% 
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(fract) # Fraction highly related within

# Create international logical -----------------------------------------------
mle_CIs$International <- mle_CIs$Country1 != mle_CIs$Country2
mle_CIs %>% group_by(International) %>%
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(n) # Check false largest: yes

# Create Ecuador factor ------------------------------------------------------
# 2 = intra Ecuador; 1 = inter Ecuador and elsewhere; 0 otherwise
mle_CIs$Ecuador <- as.factor((mle_CIs$Country1 == "Ecuador") + (mle_CIs$Country2 == "Ecuador"))
mle_CIs %>% group_by(Ecuador) %>% 
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(n) # Check 0 largest: yes

# Create batch factor --------------------------------------------------------
# -1 = intra old batch; 0 = inter new and old batch; 1 inter new batch
mle_CIs$Batch <- as.factor((mle_CIs$year1 > 2008) + (mle_CIs$year2 > 2008) - 1)
mle_CIs %>% group_by(Batch) %>% 
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(n) # Check 0 largest: yes

# Deterministic structural dependence between International and Ecuador:
# If Ecuador = 1, International = T 
# If Ecuador = 2, International = F
mle_CIs %>% 
  group_by(Ecuador) %>% 
  count(International) %>% 
  tidyr::pivot_wider(names_from = International, values_from = n) %>%
  tibble::column_to_rownames(var = "Ecuador") 

# Deterministic structural dependence between Ecuador and Batch: 
# If Ecuador = 2, Batch = 2
# If Ecuador = 1, Batch != -1
mle_CIs %>% 
  group_by(Ecuador) %>% 
  count(Batch) %>% 
  tidyr::pivot_wider(names_from = Batch, values_from = n) %>%
  tibble::column_to_rownames(var = "Ecuador") 

# Deterministic structural dependence between International and Batch: 
# If International = T, Batch != -1
mle_CIs %>% 
  group_by(Batch) %>% 
  count(International) %>% 
  tidyr::pivot_wider(names_from = International, values_from = n) %>%
  tibble::column_to_rownames(var = "Batch") 

# Dependence between Batch, Ecuador, International and year_diff range
mle_CIs %>% group_by(Batch) %>% summarise(min(year_diff), max(year_diff)) # Impacts min and max
mle_CIs %>% group_by(Ecuador) %>% summarise(min(year_diff), max(year_diff)) # Impacts max for Ecuador = 2
mle_CIs %>% group_by(International) %>% summarise(min(year_diff), max(year_diff)) # No impact

# Dependence between Batch, Ecuador, International and geo_dist range
mle_CIs %>% group_by(Batch) %>% summarise(min(geo_dist), max(geo_dist)) # Impacts max for Batch -1 (no Venezuela)
mle_CIs %>% group_by(Ecuador) %>% summarise(min(geo_dist), max(geo_dist)) # Impacts min and max
mle_CIs %>% group_by(International) %>% summarise(min(geo_dist), max(geo_dist)) # Impacts min and max

# Correlation between continuous variables -----------------
# plot(mle_CIs$geo_dist, mle_CIs$year_diff)
cor(mle_CIs$geo_dist, mle_CIs$year_diff) # Slight correlation

#' Centre the continuous variables ------------------------------
# s.t. we can include an interaction with less multicolinearity 
# (i.e. lowers VIFs for year_diff or geo_dist and year_diff:geo_dist)
before <- glm("highly_related ~ year_diff*geo_dist", family = binomial(link = "logit"), data = mle_CIs)
mle_CIs$geo_dist <- mle_CIs$geo_dist - mean(mle_CIs$geo_dist)
mle_CIs$year_diff <- mle_CIs$year_diff - mean(mle_CIs$year_diff)
after <- glm("highly_related ~ year_diff*geo_dist", family = binomial(link = "logit"), data = mle_CIs)
car::vif(before) # multicolinearity indicator before
car::vif(after) # multicolinearity indicator after 

# Combine Coast and Port since dependence is structural --------
# Cannot have FALSE InterCoast with TRUE InterPort 
mle_CIs$InterMarine <- as.factor(mle_CIs$InterCoast + mle_CIs$InterPort)
summary(glm("highly_related ~ InterMarine + year_diff*geo_dist", family = binomial(link = "logit"), data = mle_CIs))
summary(glm("highly_related ~ InterCoast + InterPort + year_diff*geo_dist", family = binomial(link = "logit"), data = mle_CIs))
mle_CIs %>% group_by(InterMarine) %>% 
  summarise(fract = mean(highly_related), n = n()) %>% 
  arrange(fract) 

# Dependence between port and international variables ----------
Port_chisq <- mle_CIs %>% 
  group_by(InterPort) %>% 
  count(International) %>% 
  tidyr::pivot_wider(names_from = International, values_from = n) %>%
  tibble::column_to_rownames(var = "InterPort") %>%
  as.matrix %>% as.table %>% chisq.test 

print(Port_chisq)
corrplot(Port_chisq$residuals, is.cor = FALSE)

# Dependence between coast and international variables ---------
Coast_chisq <- mle_CIs %>% 
  group_by(InterCoast) %>% 
  count(International) %>% 
  tidyr::pivot_wider(names_from = International, values_from = n) %>%
  tibble::column_to_rownames(var = "InterCoast") %>%
  as.matrix %>% as.table %>% chisq.test

print(Coast_chisq)
corrplot(Coast_chisq$residuals, is.cor = FALSE)

# Dependence between marine and international variables ---------
Marine_chisq <- mle_CIs %>% 
  group_by(InterMarine) %>% 
  count(International) %>% 
  tidyr::pivot_wider(names_from = International, values_from = n) %>%
  tibble::column_to_rownames(var = "InterMarine") %>%
  as.matrix %>% as.table %>% chisq.test

print(Marine_chisq)
corrplot(Marine_chisq$residuals, is.cor = FALSE)

# Dependence between marine and continuous variables -----------------------------------
mle_CIs %>% group_by(InterMarine) %>% summarise(min(year_diff), max(year_diff)) # Not so bad
mle_CIs %>% group_by(InterMarine) %>% summarise(min(geo_dist), max(geo_dist)) # Not great

# Fitting model with all predictors ----------------------------------------------------
fullformula <- "highly_related ~ International + Batch + Ecuador + InterMarine + year_diff*geo_dist"
fullmodel <- glm(fullformula, family = binomial(link = "logit"), data = mle_CIs)
summary(fullmodel); car::vif(fullmodel) # multicolinearity indicator
fullmodel_coef <- fullmodel$coefficients

# Aside: Rather than inc. a batch effect, break the model down into batches ------------

# Batch -1: makes sense since Guapi not as connected as Quibdo and Tado
summary(glm("highly_related ~ InterMarine + year_diff*geo_dist", # Ecuador and International not possible
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == -1, ]))
summary(glm("highly_related ~ InterMarine + year_diff + geo_dist", # Tweak (rm insignificant and replace InterMarine)
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == -1, ]))

# Batch 0: makes sense, additive effect of port on coast (coast switches sign when more sites)
summary(glm("highly_related ~ International + InterMarine + year_diff*geo_dist", # Ecuador = 2 not possible
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 0, ]))
summary(glm("highly_related ~ InterMarine + year_diff + geo_dist", # Tweak (rm insignificant)
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 0, ]))

# Batch 1: complicated, high multicolinearity appears to mask year_diff and geo_dist (compare M_1,M_2,M_3,M_4)
M_1 <- glm("highly_related ~ Ecuador + International + InterCoast + year_diff*geo_dist", # InterPort = 1 not possible
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 1, ])
summary(M_1); car::vif(M_1)
M_2 <- glm("highly_related ~ Ecuador + InterCoast + year_diff*geo_dist", # Tweak (rm insignificant)
            family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 1, ])
summary(M_2); car::vif(M_2)
M_3 <- glm("highly_related ~ year_diff * geo_dist", family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 1, ])
summary(M_3); car::vif(M_3)
M_4 <- glm("highly_related ~ year_diff + geo_dist", family = binomial(link = "logit"), data = mle_CIs[mle_CIs$Batch == 1, ])
summary(M_4); car::vif(M_4)




# Fitting many different models to see multicolinearity -----------

# Create formulas for many different models
flexiterms <- c("Batch", "Ecuador", "International", "InterMarine")
flexiterms_combin <- sapply(1:length(flexiterms), combinations, n = length(flexiterms), v = flexiterms)
formulas <- unlist(sapply(flexiterms_combin, function(x) apply(x, 1, paste, collapse = " + ")))

# Create stores for many different models
AICs <- array(dim = length(formulas), dimnames = list(formulas))
coefficient_formulas <- array(dim = c(length(formulas), length(fullmodel_coef), 2), 
                              dimnames = list(formulas, names(fullmodel_coef), c("Est", "Prob")))

# Fit many different models
for(i in 1:length(formulas)){
  formula <- paste0("highly_related ~", formulas[i], " + year_diff*geo_dist")
  model <- glm(formula, family = binomial(link = "logit"), data = mle_CIs)
  model_coef <- summary(model)$coefficients
  coefficient_formulas[formulas[i], rownames(model_coef), "Est"] <- model_coef[,"Estimate"]
  coefficient_formulas[formulas[i], rownames(model_coef), "Prob"] <- model_coef[,"Pr(>|z|)"]
  AICs[i] <- model$aic
}

# Plot AICs for many different models
par(mar = c(4,8,1,1))
plot(x = AICs, y = 1:length(formulas), 
     xlab = "AIC", ylab = "", yaxt = "n", bty = "n", 
     panel.first = abline(h = 1:length(formulas), col = "gray"))
axis(side = 2, at = 1:length(formulas), labels = formulas, cex.axis = 0.35, las = 1)

# Plot coefficients for many different models
for(j in 1:length(fullmodel_coef)){
  to_plot <- names(fullmodel_coef)[j]
  ind <- !is.na(coefficient_formulas[,to_plot,"Est"])
  plot(x = coefficient_formulas[,to_plot,"Est"], 
       y = 1:length(formulas), 
       pch = c(16,1)[(coefficient_formulas[,to_plot,"Prob"] >= 0.05)+1], 
       xlab = to_plot, ylab = "", yaxt = "n", bty = "n", 
       panel.first = abline(h = which(ind), col = "gray"))
  axis(side = 2, at = 1:length(formulas), labels = formulas, cex.axis = 0.35, las = 1)
  abline(v = 0, lty = "dotted")
}





#' Final model ----------------------------------------------------------------------
#' Comparing International and Ecuador: These two variables are highly collinear
#' and interfere with one another, so drop one. Of the two, International is
#' better to drop because International averages over within Colombia and within
#' Ecuador, which are very different.
#'
#' Comparing Ecuador and Batch: Batch interferes with Ecuador = 2, introduces
#' structural multicolinearity with year_diff, and there is little variation in
#' the overall fraction that are highly related for Batch = -1 and Batch = 0. 
#' However, we include it there does appear to be some batch effect. 

# Inclusion of Batch lessens some of the Ecuador effect
# Inclusion of Ecuador lessens some of the InterMarine effect
summary(glm("highly_related ~  Batch + Ecuador + InterMarine + year_diff*geo_dist", 
            family = binomial(link = "logit"), data = mle_CIs))$coefficients#[c("InterMarine1","InterMarine2"),]
summary(glm("highly_related ~  Ecuador + InterMarine + year_diff*geo_dist", 
            family = binomial(link = "logit"), data = mle_CIs))$coefficients#[c("InterMarine1","InterMarine2"),]
summary(glm("highly_related ~  InterMarine + year_diff*geo_dist", 
            family = binomial(link = "logit"), data = mle_CIs))$coefficients#[c("InterMarine1","InterMarine2"),]

finalformula <- "highly_related ~  Batch + Ecuador + InterMarine + year_diff*geo_dist"
finalmodel <- glm(finalformula, family = binomial(link = "logit"), data = mle_CIs)
summary(finalmodel); car::vif(finalmodel) # Batch, year_diff and thus year_diff:geo_dist colinear 
finalmodel.augmented <- broom::augment(finalmodel) 
# NB: finalmodel.augmented$.fitted are logit_prob are the same thing

probabilities <- predict(finalmodel, type = "response") # NB unnecessary 
mean(ifelse(probabilities < 0.5, 0, 1)); mean(mle_CIs$highly_related) # Model underestimates severely

# Check linearity of logit prob with continuous predictors -----------------------
logit_prob <- log(probabilities/(1-probabilities))
pchs <- 1:3; cols <- c("brown", "cornflowerblue", "blue")
plot(y = logit_prob, x = mle_CIs$year_diff, pch = pchs[mle_CIs$Ecuador], col = cols[mle_CIs$InterMarine])
points(y = logit_prob[mle_CIs$geo_dist>1000], x = mle_CIs$year_diff[mle_CIs$geo_dist>1000])
plot(y = logit_prob, x = mle_CIs$geo_dist, pch = pchs[mle_CIs$Ecuador], col = cols[mle_CIs$InterMarine])

# Check for influential values (Cook's distance) --------------------------------
# Are they Venezuelan? No
# If outliers, compare to model where excluded to check they do not drive trends 
plot(finalmodel, which = 4, id.n = 3)
plot(x = finalmodel.augmented$.std.resid, y = finalmodel.augmented$.cooksd) # Many above 3
outliers <- finalmodel.augmented[which(abs(finalmodel.augmented$.std.resid) >= 3),"geo_dist"]
finalmodel_rminf <- glm(finalformula, family = binomial(link = "logit"), 
    data = mle_CIs[which(abs(finalmodel.augmented$.std.resid) < 3),])
finalmodel_rmven <- glm(finalformula, family = binomial(link = "logit"), 
                        data = mle_CIs[mle_CIs$geo_dist >= 0 & mle_CIs$geo_dist < 1000,])
summary(finalmodel)$coefficients 
summary(finalmodel_rminf)$coefficients # same interpretation
summary(glm(finalformula, family = binomial(link = "logit"), 
            data = mle_CIs[mle_CIs$geo_dist < 1000,]))

# Residual plots (not ideal) -------------------------------
qqnorm(y = finalmodel.augmented$.resid)
plot(finalmodel, which=1)

# Calculate the Pearson statistic to evaluate overdispersion ---------------------
X2<-sum(residuals(finalmodel, type="pearson")^2) # Pearson statistic
phi<-X2/finalmodel$df.residual # estimate of dispersion parameter using the Pearson statistic
phi<-finalmodel$deviance/finalmodel$df.residual # estimate of dispersion parameter using the residual deviance
# phi < 1 therefore data are not overdispersed



#============================================================================
# Alternative approach: 
#============================================================================
#' Regress year_diff adjusted per-inter-location-pair probabilities of high
#' relatedness onto per-location-pair variables (geo_dist, international etc.).
#' This is similar to regressing per-location-pair highly relatedness fractions
#' onto per-location-pair variables, but adjusts for differences in year_diff. I
#' do this by first fitting a logistic regression of high-relatedness onto
#' year_diff and per-location-pair dummy variables. This provides
#' per-location-pair effects, which are then regressed onto
#' per-inter-location-pair variables. The final model I arrive at suggests
#' comparisons with Venezuela drive trends in geo_dist, while InterCoast
#' comparisons are significantly more related. However, it's important to note
#' that this 2-step approach is far from ideal. For example, it does not account
#' for uncertainty in the estimated per-location-pair effects, which are based
#' on very different sample counts and shares

# For plotting 
pchs = 22:24
bgs = RColorBrewer::brewer.pal(3,"Dark2")
cols = c("white", "black")

# Make dummy variable columns from City12 --------------------------------------------
length(unique(mle_CIs$City12)) # should add 89 columns 
mle_CIs_wide <- mle_CIs %>%
  tidyr::pivot_wider(names_from = City12, values_from = City12)
ncol(mle_CIs_wide) - ncol(mle_CIs) # Added 88 columns, why not 89? Removes City12
colnames(mle_CIs)[!colnames(mle_CIs) %in% colnames(mle_CIs_wide)]

# Make dummy variable 0/1 -----------------------------------------------------------
mle_CIs_wide[,unique(mle_CIs$City12)][!is.na(mle_CIs_wide[,unique(mle_CIs$City12)])] <- "1"
mle_CIs_wide[,unique(mle_CIs$City12)][is.na(mle_CIs_wide[,unique(mle_CIs$City12)])] <- "0"

# Create City12 matrix with metadata ------------------------------------------------
City12_matrix <- mle_CIs %>% 
  group_by(City12) %>% 
  summarise(fract = mean(highly_related), 
            geo_dist = mean(geo_dist),
            International = unique(International), 
            Ecuador = unique(Ecuador), 
            InterMarine = unique(InterMarine), 
            InterCoast = unique(InterCoast), 
            InterPort = unique(InterPort),
            n = n()) %>% 
  arrange(fract) 


City12_coef_names <- City12_matrix$City12[City12_matrix$n >= 10] 

# Logistic regression with year_diff and City12 predictors, -------------------------
# excluding location pairs with too few samples (otherwise GLM doesn't converge). 
# Takes a while
GLM <- glm(sprintf("highly_related ~ year_diff + %s", paste(City12_coef_names, collapse = " + ")), 
           family = binomial(link = "logit"), data = mle_CIs_wide)
summary(GLM)

# Add City12 coefficients to the City12_matrix ---------------------------------------
City12_matrix$Coef <- NA # Initialise column
City12_matrix$Coef[City12_matrix$n >= 10] <- GLM$coefficients[paste0(City12_coef_names,1)]


# Plot time-adjusted probabilities ---------------------------------------------------
# Temporal effect is small, a.s. logit(Coef) and fract are highly correlated. 
# NB some fract = 0 or 1 so lost in linear visualisation, i.e. y = coef, x = logit(fract)
# All the coefficients (could add errir bars)
par(mar = c(4,5,1,1))
plot(y = arm::invlogit(City12_matrix$Coef), 
     x = City12_matrix$fract,
     panel.first = grid(), bty = "n", 
     ylab = "Estimated per-location-pair probability of high relatedness \n post adjustment for differences in sampling collection dates", 
     xlab = "Observed per-location-pair fraction of high relatedness", 
     pch = pchs[as.numeric(City12_matrix$Ecuador)],
     bg = bgs[as.numeric(City12_matrix$InterMarine)], 
     col = cols[as.numeric(City12_matrix$International)+1])
legend("top", cex = 0.75, bty = "n", inset = c(0.05,0.15), 
       pch = pchs, pt.bg = "white", title = "Shape",
       legend  = c("Extra Ecuador", "Inter Ecuador", "Intra Ecuador"))
legend("center", cex = 0.75, bty = "n", inset = c(0.05,0), 
       pch = 22, pt.bg = "gray", col = cols, title = "Outline colour",
       legend  = c("Domestic", "International"))
legend("bottom", cex = 0.75, bty = "n", inset = c(0.05,0.15), 
       pch = 22, pt.bg = bgs, title = "Fill colour", 
       legend  = c("Not coastal", "Coastal", "Port"))

# Sanity check of change in rank for intra-location fractions to probabilities
# Probabilities > fractions (unsurprising since probabilities are for year_diff = 1)
City12_matrix[City12_matrix$geo_dist == 0, c("City12", "fract", "Coef")] %>% arrange(Coef)
plot(y = c(arm::invlogit(City12_matrix$fract[City12_matrix$geo_dist == 0]), 
           arm::invlogit(City12_matrix$Coef[City12_matrix$geo_dist == 0])), 
     x = jitter(rep(0:1, each = sum(City12_matrix$geo_dist == 0)), factor = 0.5), 
     ylim = c(0.5,1), xlim = c(-0.5, 1.5), 
     xlab = "", xaxt = "n", bty = "n", 
     ylab = "Observed fraction value / Estimated probability value", 
     col = 1:sum(City12_matrix$geo_dist == 0))
# arrows(x0 = rep(0.15, sum(City12_matrix$geo_dist == 0)), 
#        x1 = rep(0.85, sum(City12_matrix$geo_dist == 0)), 
#        y0 = arm::invlogit(City12_matrix$fract[City12_matrix$geo_dist == 0]), 
#        y1 = arm::invlogit(City12_matrix$Coef[City12_matrix$geo_dist == 0]),
#        length = 0.05, lwd = 0.5)
axis(side = 1, at = 0:1, labels = c("Observed \n fraction", "Estimated \n probability"), line = 1, 
     tcl = NA)

# Linear regression of coefficients --------------------------------------
Full_LM <- lm("Coef ~ geo_dist + International + InterCoast + InterPort + Ecuador", 
              data = City12_matrix[City12_matrix$geo_dist >= 0,])
summary(Full_LM); anova(Full_LM)

Red_LM <- lm("Coef ~ geo_dist + InterCoast", 
             data = City12_matrix[City12_matrix$geo_dist >= 0,])
summary(Red_LM); Red_LM_augmented <- broom::augment(Red_LM)

# Plot fitted model and estimated probabilities --------------------------
plot(y = City12_matrix$Coef[City12_matrix$geo_dist >= 0], 
     x = City12_matrix$geo_dist[City12_matrix$geo_dist >= 0], 
     ylab = "Estimated per-location-pair logit probability of high relatedness \n post adjustment for differences in sampling collection dates",
     xlab = "Great circle distance (km)", 
     pch = pchs[as.numeric(City12_matrix$Ecuador[City12_matrix$geo_dist >= 0])],
     bg = bgs[as.numeric(City12_matrix$InterMarine[City12_matrix$geo_dist >= 0])], 
     col = cols[as.numeric(City12_matrix$International[City12_matrix$geo_dist >= 0])+1])

Red_LM_augmented <- Red_LM_augmented %>% arrange(InterCoast, geo_dist)
lines(Red_LM_augmented$.fitted[!Red_LM_augmented$InterCoast], 
      x = Red_LM_augmented$geo_dist[!Red_LM_augmented$InterCoast], 
      pch = 20, col = bgs[1])
lines(Red_LM_augmented$.fitted[Red_LM_augmented$InterCoast], 
      x = Red_LM_augmented$geo_dist[Red_LM_augmented$InterCoast], 
      pch = 20, col = bgs[2])
legend("topright", cex = 0.75, bty = "n", inset = c(0.05,0.30), 
       pch = pchs, pt.bg = "white", title = "Shape",
       legend  = c("Extra Ecuador", "Inter Ecuador", "Intra Ecuador"))
legend("topright", cex = 0.75, bty = "n", inset = c(0.05,0), 
       pch = 22, pt.bg = "gray", col = cols, title = "Outline colour",
       legend  = c("Domestic", "International"))
legend("topright", cex = 0.75, bty = "n", inset = c(0.05,0.15), 
       pch = 22, pt.bg = bgs, title = "Fill colour", 
       legend  = c("Not coastal", "Coastal", "Port"))


# Clearly, comparisons with Venezuela are driving the trend in above plot -----
# Check result without: geo_dist effect is now significantly positive!
Final_LM <- lm("Coef ~ geo_dist + InterCoast", 
               data = City12_matrix[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000,])
summary(Final_LM); #plot(Final_LM);  
Final_LM_augmented <- broom::augment(Final_LM)

# Plot fitted model and estimated probabilities --------------------------
plot(y = City12_matrix$Coef[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000], 
     x = City12_matrix$geo_dist[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000], 
     ylab = "Estimated per-location-pair logit probability of high relatedness \n post adjustment for differences in sampling collection dates",
     xlab = "Great circle distance (km)", 
     pch = pchs[as.numeric(City12_matrix$Ecuador[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000])],
     bg = bgs[as.numeric(City12_matrix$InterMarine[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000])], 
     col = cols[as.numeric(City12_matrix$International[City12_matrix$geo_dist >= 0 & City12_matrix$geo_dist < 1000])+1])

Final_LM_augmented <- Final_LM_augmented %>% arrange(InterCoast, geo_dist)
lines(Final_LM_augmented$.fitted[!Final_LM_augmented$InterCoast], 
      x = Final_LM_augmented$geo_dist[!Final_LM_augmented$InterCoast], 
      pch = 20, col = bgs[1])
lines(Final_LM_augmented$.fitted[Final_LM_augmented$InterCoast], 
      x = Final_LM_augmented$geo_dist[Final_LM_augmented$InterCoast], 
      pch = 20, col = bgs[2])
legend("bottomleft", cex = 0.75, bty = "n", inset = c(0.05,0.30), 
       pch = pchs, pt.bg = "white", title = "Shape",
       legend  = c("Extra Ecuador", "Inter Ecuador", "Intra Ecuador"))
legend("bottomleft", cex = 0.75, bty = "n", inset = c(0.05,0), 
       pch = 22, pt.bg = "gray", col = cols, title = "Outline colour",
       legend  = c("Domestic", "International"))
legend("bottomleft", cex = 0.75, bty = "n", inset = c(0.05,0.15), 
       pch = 22, pt.bg = bgs, title = "Fill colour", 
       legend  = c("Not coastal", "Coastal", "Port"))


# Model summaries
summary(GLM)
summary(Full_LM)
summary(Red_LM)
summary(Final_LM) 



