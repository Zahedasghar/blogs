#| label: appendix-sim-code
#| code-fold: true
#| code-summary: "Show full R code"
#| eval: false
#| echo: true

# (The full code used above is reproduced here for reviewers.
#  Set eval: true if you want to re-run it from the appendix.)

# ===============================================
# Simulated case study: AI in social protection targeting (Pakistan)
# Outputs (written to working directory):
#   - sim_bisp_households.csv
#   - sim_results_summary.csv
#   - fig_error_rates.png
#   - fig_processing_time.png
# ===============================================

set.seed(42)

# ---- 0) Packages ----
req <- c("tidyverse", "ranger", "pROC", "ggplot2")
need <- req[!req %in% installed.packages()[, "Package"]]
if (length(need)) install.packages(need, repos = "https://cloud.r-project.org")
invisible(lapply(req, library, character.only = TRUE))

# ---- 1) Generate synthetic population ----
N <- 10000

provinces <- c("Punjab","Sindh","Khyber Pakhtunkhwa","Balochistan","Islamabad")
prov_probs <- c(0.55, 0.23, 0.16, 0.05, 0.01)

hh <- tibble(
  id = 1:N,
  province = sample(provinces, N, replace = TRUE, prob = prov_probs),
  urban = rbinom(N, 1, 0.42),
  hh_size = pmax(1, pmin(rpois(N, lambda = 5), 15))
)

# Province & urban income shifters (lognormal location)
base_mu <- 10.2
base_sigma <- 0.65
prov_shift <- c(
  "Punjab" = 0.00,
  "Sindh" = 0.08,
  "Khyber Pakhtunkhwa" = -0.05,
  "Balochistan" = -0.12,
  "Islamabad" = 0.35
)
urban_shift <- 0.12

mu_vec <- base_mu + unname(prov_shift[hh$province]) + hh$urban * urban_shift
true_income <- rlnorm(N, meanlog = mu_vec, sdlog = base_sigma) |> pmin(300000) |> pmax(3000)

# Utility use (kWh/month) correlated with income & size + noise
utility_kwh <- (true_income/1000)*0.8 + hh$hh_size*10 + rnorm(N, 0, 30)
utility_kwh <- pmin(pmax(utility_kwh, 10), 1500)

# Mobile money adoption probability: higher in urban & higher income
mm_prob <- pmin(pmax(0.2 + 0.25*hh$urban + 0.000002*pmin(true_income, 200000), 0.02), 0.9)
mobile_money <- rbinom(N, 1, mm_prob)

# Poverty "ground truth": household income threshold (PKR/month)
poverty_line <- 40000
poor_true <- as.integer(true_income < poverty_line)

# ---- 2) Reporting frictions & data errors (for Manual & baseline features) ----
# Simulate self-reported income with under-reporting bias & noise
under_report_factor <- ifelse(poor_true == 1, runif(N, 0.80, 0.95), runif(N, 0.65, 0.90))
report_noise <- rnorm(N, mean = 0, sd = 3000)
reported_income <- pmax(3000, true_income * under_report_factor + report_noise)

# Construct modeling frame
dat <- hh |>
  mutate(
    true_income = true_income,
    reported_income = reported_income,
    utility_kwh = utility_kwh,
    mobile_money = mobile_money,
    poor_true = poor_true
  )

# ---- 3) Three approaches ----
# 3.1 Manual: decision uses self-reported income only
poor_manual <- as.integer(dat$reported_income < poverty_line)

# 3.2 Traditional AI: logistic regression on reported features
# Train/test split
set.seed(7)
idx <- sample(seq_len(N), size = round(0.7*N))
train <- dat[idx,]
test  <- dat[-idx,]

# Factor province
train$province <- factor(train$province, levels = provinces)
test$province  <- factor(test$province,  levels = provinces)

# Fit logistic on reported features (glm tolerates scale() here)
form_glm <- poor_true ~ scale(reported_income) + scale(utility_kwh) + mobile_money + urban + province + scale(hh_size)
m_glm <- glm(form_glm, data = train, family = binomial())
pred_prob_glm <- predict(m_glm, newdata = test, type = "response")
poor_glm <- as.integer(pred_prob_glm >= 0.5)

# 3.3 Agentic AI proxy: "verification + ensemble" with ranger
# Create verified_income by blending toward truth for ~50% of cases
set.seed(8)
verified_flag_tr <- rbinom(nrow(train), 1, 0.5)
verified_flag_te <- rbinom(nrow(test),  1, 0.5)

train <- train |>
  mutate(
    verified_income = ifelse(verified_flag_tr == 1,
                             0.7*true_income + 0.3*reported_income,
                             reported_income)
  )

test <- test |>
  mutate(
    verified_income = ifelse(verified_flag_te == 1,
                             0.7*true_income + 0.3*reported_income,
                             reported_income)
  )

# Safe z-score (no NA if sd=0)
z <- function(x) {
  m <- mean(x, na.rm = TRUE)
  s <- sd(x, na.rm = TRUE)
  if (!is.finite(s) || s == 0) return(x - m)
  (x - m) / s
}

# Outcome as factor + engineered features (precompute; no inline scale() in ranger formula)
train <- train |>
  mutate(
    poor_true = factor(poor_true, levels = c(0, 1), labels = c("non_poor", "poor")),
    inc_per_capita  = verified_income / pmax(1, hh_size),
    util_per_capita = utility_kwh    / pmax(1, hh_size),
    z_verified_income = z(verified_income),
    z_utility_kwh     = z(utility_kwh),
    z_hh_size         = z(hh_size),
    z_inc_pc          = z(inc_per_capita),
    z_util_pc         = z(util_per_capita)
  )

test <- test |>
  mutate(
    poor_true = factor(poor_true, levels = c(0, 1), labels = c("non_poor", "poor")),
    inc_per_capita  = verified_income / pmax(1, hh_size),
    util_per_capita = utility_kwh    / pmax(1, hh_size),
    z_verified_income = z(verified_income),
    z_utility_kwh     = z(utility_kwh),
    z_hh_size         = z(hh_size),
    z_inc_pc          = z(inc_per_capita),
    z_util_pc         = z(util_per_capita)
  )

# Keep factor levels consistent
train$province <- factor(train$province, levels = provinces)
test$province  <- factor(test$province,  levels = levels(train$province))

# Drop any rows with NA on required fields (rare in this sim)
needed <- c("poor_true","z_verified_income","z_utility_kwh","z_hh_size",
            "z_inc_pc","z_util_pc","mobile_money","urban","province")
train_clean <- droplevels(train[complete.cases(train[, needed]), ])
test_clean  <- droplevels(test [complete.cases(test [, needed]), ])

# Fit ranger (classification with probabilities)
m_rf <- ranger(
  poor_true ~ z_verified_income + z_utility_kwh + mobile_money + urban + province +
    z_hh_size + z_inc_pc + z_util_pc,
  data = train_clean,
  probability = TRUE,
  num.trees = 500,
  min.node.size = 25,
  respect.unordered.factors = "partition",
  importance = "impurity",
  seed = 99
)

# Predict probabilities for the "poor" class
pred_rf <- predict(m_rf, data = test_clean)
rf_probs <- pred_rf$predictions[, "poor"]

# Threshold via ROC Youden
roc_rf  <- pROC::roc(response = test_clean$poor_true, predictor = rf_probs, quiet = TRUE)
thr_opt <- coords(roc_rf, "best", best.method = "youden", ret = "threshold")[[1]]
poor_rf <- as.integer(rf_probs >= thr_opt)

# Optional "agentic rule": flag potential ghosts (high utility & mobile wallet but predicted poor)
ghost_flag <- (test_clean$utility_kwh > quantile(test_clean$utility_kwh, 0.85)) &
  (test_clean$mobile_money == 1) & (poor_rf == 1)
poor_rf_adj <- poor_rf
poor_rf_adj[ghost_flag] <- 0

# ---- 4) Metrics: inclusion & exclusion errors ----
err_rates <- function(y_true, y_hat) {
  inc <- mean(y_hat == 1 & y_true == 0) # non-poor included
  exc <- mean(y_hat == 0 & y_true == 1) # poor excluded
  c(inclusion = inc, exclusion = exc)
}

# Align all metrics on the same test subset used for agentic comparison
# Recompute manual/logit on the same test_clean rows for fairness
manual_err <- err_rates(as.integer(test_clean$poor_true == "poor"),
                        as.integer(test_clean$reported_income < poverty_line))

# Logistic predictions were made on 'test'; subset to the rows kept in test_clean
test_idx <- as.integer(rownames(test_clean))        # original row indices
all_test_idx <- as.integer(rownames(test))          # map back
keep_map <- match(test_idx, all_test_idx)           # positions in 'test' that survived cleaning

glm_err <- err_rates(as.integer(test_clean$poor_true == "poor"),
                     as.integer(pred_prob_glm[keep_map] >= 0.5))

rf_err  <- err_rates(as.integer(test_clean$poor_true == "poor"), poor_rf_adj)

# ---- 5) Processing time & simple savings (illustrative) ----
processing_time <- tibble(
  approach = c("Manual (Self-Report Only)", "Traditional AI (Logit)", "Agentic AI (RF + Verification)"),
  hours = c(6*7*24, 3*24, 12)  # 6 weeks, 3 days, 12 hours
)

stipend <- 10500
N_test <- nrow(test_clean)
base_inc <- manual_err["inclusion"]
glm_sav  <- (base_inc - glm_err["inclusion"]) * N_test * stipend
rf_sav   <- (base_inc - rf_err["inclusion"]) * N_test * stipend

results_summary <- tibble(
  approach = c("Manual (Self-Report Only)", "Traditional AI (Logit)", "Agentic AI (RF + Verification)"),
  inclusion_error = c(manual_err["inclusion"], glm_err["inclusion"], rf_err["inclusion"]),
  exclusion_error = c(manual_err["exclusion"], glm_err["exclusion"], rf_err["exclusion"]),
  est_savings_pkr = c(0, glm_sav, rf_sav)
) |>
  mutate(
    inclusion_error_pct = scales::percent(inclusion_error, accuracy = 0.1),
    exclusion_error_pct = scales::percent(exclusion_error, accuracy = 0.1),
    est_savings_million_pkr = round(est_savings_pkr/1e6, 2)
  )

print(results_summary)

# ---- 6) Save CSVs ----
# Tag the original dat with split for reproducibility
dat$split <- ifelse(seq_len(nrow(dat)) %in% idx, "train", "test")
readr::write_csv(dat, "sim_bisp_households.csv")
readr::write_csv(results_summary, "sim_results_summary.csv")

# ---- 7) Figures ----
# Figure 1: Error rates
fig1 <- results_summary |>
  select(approach, inclusion_error, exclusion_error) |>
  pivot_longer(-approach, names_to = "type", values_to = "rate") |>
  mutate(type = recode(type, inclusion_error = "Inclusion Error", exclusion_error = "Exclusion Error")) |>
  ggplot(aes(x = approach, y = rate, fill = type)) +
  geom_col(position = position_dodge(width = 0.8)) +
  geom_text(aes(label = scales::percent(rate, accuracy = 0.1)),
            position = position_dodge(width = 0.8), vjust = -0.2, size = 3.4) +
  labs(
    title = "Figure 1. Inclusion vs Exclusion Error by Targeting Approach (Simulated)",
    x = NULL, y = "Error Rate", fill = NULL
  ) +
  coord_cartesian(ylim = c(0, max(results_summary$inclusion_error, results_summary$exclusion_error)*1.2)) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 10, hjust = 1))

ggsave("fig_error_rates.png", fig1, width = 8, height = 5, dpi = 300)

# Figure 2: Processing time (hours)
fig2 <- processing_time |>
  ggplot(aes(x = approach, y = hours)) +
  geom_col() +
  geom_text(aes(label = paste0(round(hours), " hrs")), vjust = -0.2, size = 3.5) +
  labs(
    title = "Figure 2. Illustrative Processing Time per 10,000 Applications",
    x = NULL, y = "Hours"
  ) +
  theme_minimal(base_size = 12) +
  theme(axis.text.x = element_text(angle = 10, hjust = 1))

ggsave("fig_processing_time.png", fig2, width = 8, height = 5, dpi = 300)

# ---- 8) Console summary for quick write-up ----
cat("\n--- Quick Summary (use in text) ---\n")
cat(sprintf("Manual — Inclusion: %s, Exclusion: %s\n",
            scales::percent(results_summary$inclusion_error[1], 0.1),
            scales::percent(results_summary$exclusion_error[1], 0.1)))
cat(sprintf("Traditional AI — Inclusion: %s, Exclusion: %s, Savings ≈ PKR %.2f million\n",
            scales::percent(results_summary$inclusion_error[2], 0.1),
            scales::percent(results_summary$exclusion_error[2], 0.1),
            results_summary$est_savings_pkr[2]/1e6))
cat(sprintf("Agentic AI — Inclusion: %s, Exclusion: %s, Savings ≈ PKR %.2f million\n",
            scales::percent(results_summary$inclusion_error[3], 0.1),
            scales::percent(results_summary$exclusion_error[3], 0.1),
            results_summary$est_savings_pkr[3]/1e6))

