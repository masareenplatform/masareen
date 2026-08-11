# evidence_analysis.R - Evidence submission analytics
# Part of MASAREN Impact-as-a-Service analytics platform

log_msg("Starting evidence_analysis.R")

analyze_evidence <- function(conn, output_dir = "reports") {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # ── Evidence counts by status ──────────────────────────────────────────────────
  log_msg("Querying evidence counts by status")
  by_status <- query_db(conn, "
    SELECT status, COUNT(*) AS count
    FROM evidence
    GROUP BY status
    ORDER BY count DESC
  ")
  if (nrow(by_status) == 0) {
    log_msg("WARNING: No evidence records found for status breakdown")
    by_status <- data.frame(status = character(), count = integer())
  }

  # ── Evidence counts by media_type ──────────────────────────────────────────────
  log_msg("Querying evidence counts by media type")
  by_media <- query_db(conn, "
    SELECT media_type, COUNT(*) AS count,
           ROUND(AVG(file_size_bytes)::numeric, 2) AS avg_file_size
    FROM evidence
    GROUP BY media_type
    ORDER BY count DESC
  ")
  if (nrow(by_media) == 0) {
    log_msg("WARNING: No evidence records found for media type breakdown")
    by_media <- data.frame(media_type = character(), count = integer(), avg_file_size = numeric())
  }

  # ── Evidence submissions over time ─────────────────────────────────────────────
  log_msg("Querying evidence submissions per day")
  over_time <- query_db(conn, "
    SELECT DATE(created_at) AS submission_date, COUNT(*) AS submissions
    FROM evidence
    GROUP BY DATE(created_at)
    ORDER BY submission_date
  ")
  if (nrow(over_time) == 0) {
    log_msg("WARNING: No evidence records found for time series")
    over_time <- data.frame(submission_date = as.Date(character()), submissions = integer())
  }

  # ── Overall metrics ────────────────────────────────────────────────────────────
  log_msg("Calculating overall evidence metrics")
  total_evidence <- query_db(conn, "SELECT COUNT(*) AS n FROM evidence")
  total_evidence <- ifelse(nrow(total_evidence) > 0, total_evidence$n[1], 0)

  avg_file_size <- query_db(conn, "
    SELECT ROUND(AVG(file_size_bytes)::numeric, 2) AS avg_size
    FROM evidence
  ")
  avg_file_size <- ifelse(nrow(avg_file_size) > 0 && !is.na(avg_file_size$avg_size[1]),
                          avg_file_size$avg_size[1], 0)

  fraud_count <- query_db(conn, "
    SELECT COUNT(*) AS n FROM evidence WHERE is_fraudulent = TRUE
  ")
  fraud_count <- ifelse(nrow(fraud_count) > 0, fraud_count$n[1], 0)

  fraud_rate <- ifelse(total_evidence > 0,
                       round(fraud_count / total_evidence * 100, 2), 0)

  most_common_media <- if (nrow(by_media) > 0) as.character(by_media$media_type[1]) else "N/A"

  summary_stats <- data.frame(
    metric = c("total_evidence", "avg_file_size_bytes", "most_common_media_type", "fraud_count", "fraud_rate_pct"),
    value  = c(total_evidence, avg_file_size, most_common_media, fraud_count, fraud_rate)
  )

  # ── Write CSV outputs ──────────────────────────────────────────────────────────
  csv_path <- file.path(output_dir, "evidence_summary.csv")
  write.csv(summary_stats, csv_path, row.names = FALSE)
  log_msg(sprintf("Written: %s", csv_path))

  # ── Bar chart: evidence by status ─────────────────────────────────────────────
  if (nrow(by_status) > 0) {
    p_status <- ggplot(by_status, aes(x = reorder(status, count), y = count, fill = status)) +
      geom_bar(stat = "identity") +
      coord_flip() +
      labs(title = "Evidence by Status", x = "Status", y = "Count") +
      theme_minimal() +
      theme(legend.position = "none")

    chart_path <- file.path(output_dir, "evidence_chart.png")
    ggsave(chart_path, p_status, width = 10, height = 6, dpi = 150)
    log_msg(sprintf("Written: %s", chart_path))
  } else {
    log_msg("Skipping evidence chart: no data")
  }

  # ── Time series: submissions per day ──────────────────────────────────────────
  if (nrow(over_time) > 0) {
    over_time$submission_date <- as.Date(over_time$submission_date)
    p_ts <- ggplot(over_time, aes(x = submission_date, y = submissions)) +
      geom_line(color = "steelblue", size = 1) +
      geom_point(color = "steelblue", size = 2) +
      labs(title = "Evidence Submissions per Day", x = "Date", y = "Submissions") +
      theme_minimal()

    ts_path <- file.path(output_dir, "evidence_timeseries.png")
    ggsave(ts_path, p_ts, width = 12, height = 5, dpi = 150)
    log_msg(sprintf("Written: %s", ts_path))
  }

  log_msg("evidence_analysis.R complete")
  invisible(list(
    by_status      = by_status,
    by_media       = by_media,
    over_time      = over_time,
    summary_stats  = summary_stats
  ))
}

if (interactive() || exists("conn")) {
  output_dir <- ifelse(dir.exists("reports"), "reports", ".")
  analyze_evidence(get("conn"), output_dir)
}
