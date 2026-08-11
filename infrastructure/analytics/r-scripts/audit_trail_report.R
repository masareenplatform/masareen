# audit_trail_report.R - Audit trail analytics
# Part of MASAREN Impact-as-a-Service analytics platform

log_msg("Starting audit_trail_report.R")

analyze_audit <- function(conn, output_dir = "reports") {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # ── Audit events by type ───────────────────────────────────────────────────────
  log_msg("Querying audit events by type")
  by_type <- query_db(conn, "
    SELECT event_type, COUNT(*) AS count
    FROM audit_log
    GROUP BY event_type
    ORDER BY count DESC
  ")
  if (nrow(by_type) == 0) {
    log_msg("WARNING: No audit log records found by type")
    by_type <- data.frame(event_type = character(), count = integer())
  }

  # ── Audit events by actor ─────────────────────────────────────────────────────
  log_msg("Querying audit events by actor")
  by_actor <- query_db(conn, "
    SELECT actor_id, actor_type, COUNT(*) AS count
    FROM audit_log
    WHERE actor_id IS NOT NULL
    GROUP BY actor_id, actor_type
    ORDER BY count DESC
  ")
  if (nrow(by_actor) == 0) {
    log_msg("WARNING: No audit records by actor found")
    by_actor <- data.frame(actor_id = character(), actor_type = character(), count = integer())
  }

  # ── Audit events over time ─────────────────────────────────────────────────────
  log_msg("Querying audit events over time")
  over_time <- query_db(conn, "
    SELECT DATE(created_at) AS event_date, COUNT(*) AS events
    FROM audit_log
    GROUP BY DATE(created_at)
    ORDER BY event_date
  ")
  if (nrow(over_time) == 0) {
    log_msg("WARNING: No audit time series data found")
    over_time <- data.frame(event_date = as.Date(character()), events = integer())
  }

  # ── Export full audit trail to CSV ─────────────────────────────────────────────
  log_msg("Exporting full audit trail")
  full_audit <- query_db(conn, "
    SELECT id, event_type, actor_id, actor_type, target_type, target_id,
           metadata, ip_address, created_at
    FROM audit_log
    ORDER BY created_at DESC
  ")
  if (nrow(full_audit) == 0) {
    log_msg("WARNING: No audit records found for export")
    full_audit <- data.frame()
  }

  csv_path <- file.path(output_dir, "audit_trail.csv")
  write.csv(full_audit, csv_path, row.names = FALSE)
  log_msg(sprintf("Written: %s (n=%d)", csv_path, nrow(full_audit)))

  # ── Activity timeline chart ────────────────────────────────────────────────────
  if (nrow(over_time) > 0) {
    p_timeline <- ggplot(over_time, aes(x = as.Date(event_date), y = events)) +
      geom_area(fill = "steelblue", alpha = 0.4) +
      geom_line(color = "steelblue", size = 1) +
      geom_point(color = "steelblue", size = 2) +
      labs(title = "Audit Activity Timeline", x = "Date", y = "Events") +
      theme_minimal()

    tl_path <- file.path(output_dir, "audit_activity.png")
    ggsave(tl_path, p_timeline, width = 12, height = 5, dpi = 150)
    log_msg(sprintf("Written: %s", tl_path))
  } else {
    log_msg("Skipping activity timeline: no data")
  }

  # ── Event type distribution (pie chart) ────────────────────────────────────────
  if (nrow(by_type) > 0) {
    by_type$pct <- round(by_type$count / sum(by_type$count) * 100, 1)
    by_type$label <- sprintf("%s (%.1f%%)", by_type$event_type, by_type$pct)

    p_pie <- ggplot(by_type, aes(x = "", y = count, fill = event_type)) +
      geom_bar(stat = "identity", width = 1) +
      coord_polar("y", start = 0) +
      labs(title = "Audit Event Type Distribution") +
      theme_void() +
      theme(legend.title = element_blank()) +
      geom_text(aes(label = label),
                position = position_stack(vjust = 0.5), size = 3.5)

    pie_path <- file.path(output_dir, "audit_types_pie.png")
    ggsave(pie_path, p_pie, width = 8, height = 7, dpi = 150)
    log_msg(sprintf("Written: %s", pie_path))
  } else {
    log_msg("Skipping pie chart: no data")
  }

  # ── Most active actors ─────────────────────────────────────────────────────────
  top_actors <- head(by_actor, 10)
  if (nrow(top_actors) > 0) {
    p_actors <- ggplot(top_actors, aes(x = reorder(paste(actor_type, actor_id), count), y = count, fill = actor_type)) +
      geom_bar(stat = "identity") +
      coord_flip() +
      labs(title = "Most Active Actors", x = "Actor", y = "Events") +
      theme_minimal() +
      theme(legend.position = "none")

    actors_path <- file.path(output_dir, "audit_top_actors.png")
    ggsave(actors_path, p_actors, width = 10, height = 6, dpi = 150)
    log_msg(sprintf("Written: %s", actors_path))
  }

  log_msg("audit_trail_report.R complete")
  invisible(list(
    by_type   = by_type,
    by_actor  = by_actor,
    over_time = over_time,
    full_audit = full_audit
  ))
}

if (interactive() || exists("conn")) {
  output_dir <- ifelse(dir.exists("reports"), "reports", ".")
  analyze_audit(get("conn"), output_dir)
}
