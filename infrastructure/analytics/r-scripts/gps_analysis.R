# gps_analysis.R - GPS data analytics
# Part of MASAREN Impact-as-a-Service analytics platform

log_msg("Starting gps_analysis.R")

analyze_gps <- function(conn, output_dir = "reports") {
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  # ── Records by accuracy range ──────────────────────────────────────────────────
  log_msg("Querying GPS records by accuracy range")
  by_accuracy <- query_db(conn, "
    SELECT
      CASE
        WHEN accuracy <= 5   THEN '0-5m'
        WHEN accuracy <= 10  THEN '5-10m'
        WHEN accuracy <= 50  THEN '10-50m'
        WHEN accuracy <= 100 THEN '50-100m'
        ELSE '>100m'
      END AS accuracy_range,
      COUNT(*) AS count
    FROM gps_records
    GROUP BY accuracy_range
    ORDER BY accuracy_range
  ")
  if (nrow(by_accuracy) == 0) {
    log_msg("WARNING: No GPS records found for accuracy ranges")
    by_accuracy <- data.frame(accuracy_range = character(), count = integer())
  }

  # ── Full accuracy distribution for histogram ───────────────────────────────────
  log_msg("Querying full GPS accuracy distribution")
  all_accuracy <- query_db(conn, "SELECT accuracy FROM gps_records WHERE accuracy IS NOT NULL")
  has_accuracy <- nrow(all_accuracy) > 0

  # ── Potential fraud: zero coordinates ──────────────────────────────────────────
  log_msg("Identifying GPS records with zero coordinates (potential fraud)")
  zero_coords <- query_db(conn, "
    SELECT id, task_id, latitude, longitude, accuracy, recorded_at
    FROM gps_records
    WHERE (latitude = 0 AND longitude = 0)
       OR (latitude IS NULL OR longitude IS NULL)
    ORDER BY recorded_at DESC
  ")
  if (nrow(zero_coords) == 0) {
    log_msg("No zero-coordinate records found")
    zero_coords <- data.frame(
      id = integer(), task_id = character(), latitude = numeric(),
      longitude = numeric(), accuracy = numeric(), recorded_at = as.POSIXct(character())
    )
  }

  # ── Potential fraud: low accuracy clusters ─────────────────────────────────────
  log_msg("Identifying low accuracy clusters (accuracy > 100m)")
  low_accuracy <- query_db(conn, "
    SELECT id, task_id, latitude, longitude, accuracy, recorded_at
    FROM gps_records
    WHERE accuracy > 100 OR accuracy IS NULL
    ORDER BY accuracy DESC
  ")
  if (nrow(low_accuracy) == 0) {
    log_msg("No low-accuracy records found")
    low_accuracy <- data.frame(
      id = integer(), task_id = character(), latitude = numeric(),
      longitude = numeric(), accuracy = numeric(), recorded_at = as.POSIXct(character())
    )
  }

  # ── Geospatial: records within / outside task geofences ────────────────────────
  log_msg("Querying GPS geo-fence compliance")
  geo_fence <- query_db(conn, "
    SELECT
      g.id,
      g.task_id,
      g.latitude,
      g.longitude,
      g.accuracy,
      t.geofence_radius_meters,
      CASE
        WHEN t.geofence_lat IS NOT NULL AND t.geofence_lng IS NOT NULL
          AND g.latitude IS NOT NULL AND g.longitude IS NOT NULL THEN
          (2 * 6371000 * ASIN(SQRT(
            POWER(SIN(RADIANS(g.latitude - t.geofence_lat) / 2), 2)
            + COS(RADIANS(t.geofence_lat))
            * COS(RADIANS(g.latitude))
            * POWER(SIN(RADIANS(g.longitude - t.geofence_lng) / 2), 2)
          )))
        ELSE NULL
      END AS distance_from_center,
      CASE
        WHEN t.geofence_lat IS NOT NULL AND t.geofence_lng IS NOT NULL
          AND g.latitude IS NOT NULL AND g.longitude IS NOT NULL
          AND t.geofence_radius_meters IS NOT NULL THEN
          (2 * 6371000 * ASIN(SQRT(
            POWER(SIN(RADIANS(g.latitude - t.geofence_lat) / 2), 2)
            + COS(RADIANS(t.geofence_lat))
            * COS(RADIANS(g.latitude))
            * POWER(SIN(RADIANS(g.longitude - t.geofence_lng) / 2), 2)
          ))) <= t.geofence_radius_meters
        ELSE NULL
      END AS within_geofence
    FROM gps_records g
    LEFT JOIN tasks t ON g.task_id = t.id
  ")
  if (nrow(geo_fence) == 0) {
    log_msg("WARNING: No geo-fence data available")
    geo_fence <- data.frame(
      id = integer(), task_id = character(), latitude = numeric(),
      longitude = numeric(), accuracy = numeric(), geofence_radius_meters = numeric(),
      distance_from_center = numeric(), within_geofence = logical()
    )
  }

  # ── Combined fraud candidates ──────────────────────────────────────────────────
  fraud_candidates <- data.frame()
  if (nrow(zero_coords) > 0) {
    zero_coords$fraud_reason <- "Zero/Null coordinates"
    fraud_candidates <- rbind(fraud_candidates, zero_coords)
  }
  if (nrow(low_accuracy) > 0) {
    low_accuracy$fraud_reason <- "Low accuracy (>100m)"
    fraud_candidates <- rbind(fraud_candidates, low_accuracy)
  }
  if (nrow(geo_fence) > 0 && any(!is.na(geo_fence$within_geofence))) {
    outside <- geo_fence[!is.na(geo_fence$within_geofence) & !geo_fence$within_geofence, ]
    if (nrow(outside) > 0) {
      outside$fraud_reason <- "Outside geofence"
      outside <- outside[, intersect(names(outside), names(fraud_candidates))]
      fraud_candidates <- rbind(fraud_candidates, outside)
    }
  }

  if (nrow(fraud_candidates) > 0) {
    fraud_candidates <- fraud_candidates[!duplicated(fraud_candidates$id), ]
  }

  # ── Write CSV outputs ──────────────────────────────────────────────────────────
  gps_fraud_path <- file.path(output_dir, "gps_fraud_candidates.csv")
  write.csv(fraud_candidates, gps_fraud_path, row.names = FALSE)
  log_msg(sprintf("Written: %s (n=%d)", gps_fraud_path, nrow(fraud_candidates)))

  # ── Accuracy histogram ─────────────────────────────────────────────────────────
  if (has_accuracy) {
    p_hist <- ggplot(all_accuracy, aes(x = accuracy)) +
      geom_histogram(binwidth = 5, fill = "steelblue", color = "white", alpha = 0.8) +
      labs(title = "GPS Accuracy Distribution",
           x = "Accuracy (meters)", y = "Count") +
      theme_minimal()

    hist_path <- file.path(output_dir, "gps_accuracy_histogram.png")
    ggsave(hist_path, p_hist, width = 10, height = 6, dpi = 150)
    log_msg(sprintf("Written: %s", hist_path))
  } else {
    log_msg("Skipping accuracy histogram: no data")
  }

  # ── Accuracy range bar chart ───────────────────────────────────────────────────
  if (nrow(by_accuracy) > 0) {
    p_acc <- ggplot(by_accuracy, aes(x = accuracy_range, y = count, fill = accuracy_range)) +
      geom_bar(stat = "identity") +
      labs(title = "GPS Records by Accuracy Range", x = "Accuracy Range", y = "Count") +
      theme_minimal() +
      theme(legend.position = "none") +
      scale_fill_brewer(palette = "Blues")

    acc_path <- file.path(output_dir, "gps_accuracy_ranges.png")
    ggsave(acc_path, p_acc, width = 8, height = 5, dpi = 150)
    log_msg(sprintf("Written: %s", acc_path))
  }

  log_msg("gps_analysis.R complete")
  invisible(list(
    by_accuracy     = by_accuracy,
    all_accuracy    = all_accuracy,
    zero_coords     = zero_coords,
    low_accuracy    = low_accuracy,
    geo_fence       = geo_fence,
    fraud_candidates = fraud_candidates
  ))
}

if (interactive() || exists("conn")) {
  output_dir <- ifelse(dir.exists("reports"), "reports", ".")
  analyze_gps(get("conn"), output_dir)
}
