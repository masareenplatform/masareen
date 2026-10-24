# verification_report.R - Verification pipeline analytics
# Part of MASAREN Impact-as-a-Service analytics platform

log_msg("Starting verification_report.R")

analyze_verification <- function(conn, output_dir = "reports") {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # ── Pipelines by status ────────────────────────────────────────────────────────
  log_msg("Querying verification pipelines by status")
  by_status <- query_db(conn, "
    SELECT status, COUNT(*) AS count
    FROM verification_pipeline
    GROUP BY status
    ORDER BY count DESC
  ")
  if (nrow(by_status) == 0) {
    log_msg("WARNING: No verification pipeline records found by status")
    by_status <- data.frame(status = character(), count = integer())
  }

  # ── Pipelines by reviewer ──────────────────────────────────────────────────────
  log_msg("Querying verification pipelines by reviewer")
  by_reviewer <- query_db(conn, "
    SELECT reviewer_id, COUNT(*) AS count
    FROM verification_pipeline
    WHERE reviewer_id IS NOT NULL
    GROUP BY reviewer_id
    ORDER BY count DESC
  ")
  if (nrow(by_reviewer) == 0) {
    log_msg("WARNING: No reviewer assignments found")
    by_reviewer <- data.frame(reviewer_id = character(), count = integer())
  }

  # ── Average AI confidence and fraud risk scores ────────────────────────────────
  log_msg("Calculating average AI confidence and fraud risk scores")
  scores <- query_db(conn, "
    SELECT
      ROUND(AVG(ai_confidence_score)::numeric, 4) AS avg_ai_confidence,
      ROUND(AVG(fraud_risk_score)::numeric, 4)     AS avg_fraud_risk,
      ROUND(AVG(CASE WHEN reviewed_by_human THEN 1 ELSE 0 END)::numeric, 4) AS human_review_rate
    FROM verification_pipeline
  ")
  if (nrow(scores) == 0 || all(is.na(scores))) {
    log_msg("WARNING: No score data available")
    scores <- data.frame(
      avg_ai_confidence = NA_real_,
      avg_fraud_risk    = NA_real_,
      human_review_rate = NA_real_
    )
  }

  # ── Pipeline throughput by day ─────────────────────────────────────────────────
  log_msg("Calculating pipeline throughput by day")
  throughput <- query_db(conn, "
    SELECT
      DATE(created_at) AS day,
      COUNT(*)         AS total,
      SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completed,
      SUM(CASE WHEN status = 'failed'    THEN 1 ELSE 0 END) AS failed
    FROM verification_pipeline
    GROUP BY DATE(created_at)
    ORDER BY day
  ")
  if (nrow(throughput) == 0) {
    log_msg("WARNING: No throughput data available")
    throughput <- data.frame(day = as.Date(character()), total = integer(),
                             completed = integer(), failed = integer())
  }

  # ── Pipeline stage counts (for Sankey-like diagram) ────────────────────────────
  log_msg("Querying pipeline stage transitions")
  stage_counts <- query_db(conn, "
    SELECT stage, COUNT(*) AS count
    FROM verification_pipeline
    GROUP BY stage
    ORDER BY stage
  ")
  if (nrow(stage_counts) == 0) {
    stage_counts <- data.frame(stage = character(), count = integer())
  }

  # ── Write CSV outputs ──────────────────────────────────────────────────────────
  throughput_csv <- file.path(output_dir, "verification_throughput.csv")
  write.csv(throughput, throughput_csv, row.names = FALSE)
  log_msg(sprintf("Written: %s", throughput_csv))

  # ── Sankey-style flow diagram (horizontal bar segments) ────────────────────────
  if (nrow(stage_counts) > 0) {
    stage_counts$pct <- round(stage_counts$count / sum(stage_counts$count) * 100, 1)
    stage_counts$label <- sprintf("%s (n=%d, %.1f%%)", stage_counts$stage, stage_counts$count, stage_counts$pct)
    stage_counts$stage <- factor(stage_counts$stage, levels = rev(unique(stage_counts$stage)))

    p_sankey <- ggplot(stage_counts, aes(y = stage, x = count, fill = stage)) +
      geom_bar(stat = "identity", width = 0.7) +
      geom_text(aes(label = label), hjust = -0.05, size = 3.5) +
      labs(title = "Verification Pipeline Stage Flow", x = "Records", y = "Stage") +
      theme_minimal() +
      theme(legend.position = "none") +
      xlim(0, max(stage_counts$count) * 1.35)

    sankey_path <- file.path(output_dir, "verification_stages.png")
    ggsave(sankey_path, p_sankey, width = 10, height = 5, dpi = 150)
    log_msg(sprintf("Written: %s", sankey_path))
  }

  # ── Reports directory for HTML output ──────────────────────────────────────────
  html_path <- file.path(output_dir, "verification_report.html")

  # ── Throughput chart ──────────────────────────────────────────────────────────
  throughput_chart_path <- file.path(output_dir, "verification_throughput.png")
  if (nrow(throughput) > 0) {
    p_throughput <- ggplot(throughput, aes(x = as.Date(day))) +
      geom_line(aes(y = total,     color = "Total"),     size = 1) +
      geom_line(aes(y = completed, color = "Completed"), size = 1) +
      geom_line(aes(y = failed,    color = "Failed"),    size = 1) +
      labs(title = "Verification Pipeline Throughput", x = "Date", y = "Records", color = "") +
      scale_color_manual(values = c("Total" = "steelblue", "Completed" = "green4", "Failed" = "red3")) +
      theme_minimal()
    ggsave(throughput_chart_path, p_throughput, width = 12, height = 5, dpi = 150)
    log_msg(sprintf("Written: %s", throughput_chart_path))
  }

  # ── Generate HTML report ───────────────────────────────────────────────────────
  log_msg("Generating verification HTML report")

  title <- "MASAREN, Verification Pipeline Report"
  date_str <- format(Sys.time(), "%Y-%m-%d %H:%M")

  html_content <- sprintf(
'<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>%s</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         margin: 2rem; background: #f9f9f9; color: #333; }
  h1, h2, h3 { color: #1a1a2e; }
  .container { max-width: 1100px; margin: 0 auto; }
  .card { background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1);
          padding: 1.5rem; margin-bottom: 2rem; }
  table { border-collapse: collapse; width: 100%%; margin: 1rem 0; }
  th, td { padding: 0.6rem; text-align: left; border-bottom: 1px solid #ddd; }
  th { background: #1a1a2e; color: #fff; }
  tr:hover { background: #f1f1f1; }
  img { max-width: 100%%; height: auto; border-radius: 4px; margin: 1rem 0; }
  .metrics { display: flex; gap: 1.5rem; flex-wrap: wrap; }
  .metric-box { background: #eef2ff; border-radius: 6px; padding: 1rem 1.5rem; min-width: 180px; flex: 1; }
  .metric-box .value { font-size: 1.8rem; font-weight: 700; color: #1a1a2e; }
  .metric-box .label  { font-size: 0.85rem; color: #666; }
</style>
</head>
<body>
<div class="container">
  <h1>Verification Pipeline Report</h1>
  <p>Generated: %s</p>

  <div class="card">
    <h2>Key Metrics</h2>
    <div class="metrics">
      <div class="metric-box">
        <div class="value">%.2f</div>
        <div class="label">Avg AI Confidence</div>
      </div>
      <div class="metric-box">
        <div class="value">%.2f</div>
        <div class="label">Avg Fraud Risk</div>
      </div>
      <div class="metric-box">
        <div class="value">%.1f%%%%</div>
        <div class="label">Human Review Rate</div>
      </div>
    </div>
  </div>

  <div class="card">
    <h2>Pipeline by Status</h2>
    %s
  </div>

  <div class="card">
    <h2>Throughput Over Time</h2>
    <img src="verification_throughput.png" alt="Throughput chart">
  </div>

  <div class="card">
    <h2>Pipeline Stages</h2>
    <img src="verification_stages.png" alt="Stage flow">
  </div>

  <div class="card">
    <h2>Top Reviewers</h2>
    %s
  </div>
</div>
</body>
</html>',
    title, date_str,
    if (!is.na(scores$avg_ai_confidence[1])) scores$avg_ai_confidence[1] else 0,
    if (!is.na(scores$avg_fraud_risk[1]))    scores$avg_fraud_risk[1]    else 0,
    if (!is.na(scores$human_review_rate[1])) scores$human_review_rate[1] * 100 else 0,
    if (nrow(by_status) > 0) {
      paste0(
        "<table><tr><th>Status</th><th>Count</th></tr>",
        paste(sprintf("<tr><td>%s</td><td>%d</td></tr>", by_status$status, by_status$count),
              collapse = ""),
        "</table>"
      )
    } else "<p>No data</p>",
    if (nrow(by_reviewer) > 0) {
      paste0(
        "<table><tr><th>Reviewer ID</th><th>Count</th></tr>",
        paste(sprintf("<tr><td>%s</td><td>%d</td></tr>", by_reviewer$reviewer_id, by_reviewer$count),
              collapse = ""),
        "</table>"
      )
    } else "<p>No data</p>"
  )

  writeLines(html_content, html_path)
  log_msg(sprintf("Written: %s", html_path))

  log_msg("verification_report.R complete")
  invisible(list(
    by_status  = by_status,
    by_reviewer = by_reviewer,
    scores     = scores,
    throughput = throughput,
    stages     = stage_counts
  ))
}

if (interactive() || exists("conn")) {
  output_dir <- ifelse(dir.exists("reports"), "reports", ".")
  analyze_verification(get("conn"), output_dir)
}
