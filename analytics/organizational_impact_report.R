# MASAREN Strategic Impact Report - Organizational Performance
library(tidyverse)
library(ggplot2)

# 1. OII Distribution Analysis
analyze_oii_distribution <- function(org_data) {
  ggplot(org_data, aes(x=oii_score)) +
    geom_histogram(binwidth=0.1, fill="navy", color="white") +
    labs(title="Global Distribution of Organization Impact Index (OII)")
}

# 2. SDG Alignment Map
# Maps which SDGs are most frequently verified across the platform
analyze_sdg_trends <- function(event_data) {
  sdg_counts <- event_data %>%
    count(sdg_id) %>%
    arrange(desc(n))
  
  ggplot(sdg_counts, aes(x=reorder(sdg_id, n), y=n)) +
    geom_col(fill="gold") +
    coord_flip() +
    labs(title="Most Impacted SDGs Globally")
}

# Execution
# la_plot <- analyze_sdg_trends(event_data)
# ggsave("reports/sdg_trends.png", la_plot)
