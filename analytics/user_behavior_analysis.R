# MASAREN Impact Analytics - User Behavior & Retention
library(tidyverse)
library(ggplot2)
library(dplyr)

# Load Data
# In production, this reads from the PostgreSQL read-replica
# data <- read.csv("data/user_activity_logs.csv")

# 1. User Retention Analysis
analyze_retention <- function(data) {
  retention <- data %>%
    group_by(cohort_month) %>%
    summarise(
      month_0 = n_distinct(user_id),
      month_1 = n_distinct(user_id[activity_month == 1]),
      month_2 = n_distinct(user_id[activity_month == 2])
    )
  
  ggplot(retention, aes(x=cohort_month, y=month_1)) + 
    geom_line() + labs(title="Month 1 Retention Rate")
}

# 2. Impact-to-Reputation Correlation
analyze_pms_growth <- function(data) {
  # Correlation between number of verified tasks and PMS growth
  ggplot(data, aes(x=verified_tasks, y=pms_score)) +
    geom_point(alpha=0.5) +
    geom_smooth(method="lm") +
    labs(title="Correlation: Verified Tasks vs PMS Score")
}

# 3. Monetization Efficiency
analyze_ad_roi <- function(data) {
  roi <- data %>%
    group_by(ad_id) %>%
    summarise(
      total_spend = sum(spend),
      total_conversions = sum(conversions),
      cpa = total_spend / total_conversions
    )
  return(roi)
}

# Execution
# res <- analyze_pms_growth(user_data)
# ggsave("reports/pms_growth.png", res)
