# generate_all_reports.R - Master orchestrator for all analytics reports
# Part of MASAREN Impact-as-a-Service analytics platform
#
# Usage: Rscript generate_all_reports.R

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

log_msg("==============================================")
log_msg(" MASAREN Impact-as-a-Service — Report Runner")
log_msg("==============================================")

# ── Source setup (packages, DB connection) ─────────────────────────────────────
script_dir <- tryCatch(
  dirname(sys.frame(1)$ofile),
  error = function(e) getwd()
)
if (is.null(script_dir) || script_dir == "") script_dir <- getwd()

setup_path <- file.path(script_dir, "setup.R")
if (!file.exists(setup_path)) {
  stop(sprintf("Cannot find setup.R at %s", setup_path))
}
source(setup_path)

# ── Create report directories ──────────────────────────────────────────────────
output_dir <- file.path(script_dir, "reports")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  log_msg(sprintf("Created output directory: %s", output_dir))
}

# ── Connect to database ────────────────────────────────────────────────────────
conn <- connect_db()
on.exit(disconnect_db(conn))

# ── Run all analysis scripts ───────────────────────────────────────────────────
scripts <- c(
  "evidence_analysis.R",
  "verification_report.R",
  "gps_analysis.R",
  "audit_trail_report.R"
)

results <- list()

for (scr in scripts) {
  scr_path <- file.path(script_dir, scr)
  if (!file.exists(scr_path)) {
    log_msg(sprintf("WARNING: Script not found — %s", scr_path))
    next
  }

  log_msg(sprintf("── Running %s ─────────────────────────", scr))

  result <- tryCatch(
    {
      local_env <- new.env(parent = globalenv())
      local_env$conn <- conn
      local_env$output_dir <- output_dir
      sys.source(scr_path, envir = local_env)
      log_msg(sprintf("Finished %s", scr))
      TRUE
    },
    error = function(e) {
      log_msg(sprintf("ERROR in %s: %s", scr, e$message))
      NULL
    }
  )

  results[[scr]] <- result
}

# ── Generate master HTML report ────────────────────────────────────────────────
log_msg("Generating master report: master_report.html")

img_extensions <- c("*.png", "*.jpg", "*.jpeg", "*.svg")
image_files <- unlist(lapply(img_extensions, function(ext) {
  list.files(output_dir, pattern = glob2rx(ext), full.names = FALSE)
}))
image_files <- unique(image_files)

csv_files <- list.files(output_dir, pattern = "*.csv", full.names = FALSE)

# ── Build master report content ─────────────────────────────────────────────────
title <- "MASAREN — Master Analytics Report"
date_str <- format(Sys.time(), "%Y-%m-%d %H:%M")

images_html <- ""
if (length(image_files) > 0) {
  for (img in image_files) {
    images_html <- sprintf(
      '%s<div class="card"><h3>%s</h3><img src="%s" alt="%s"></div>\n',
      images_html, img, img, img
    )
  }
} else {
  images_html <- "<div class=\"card\"><p>No images generated.</p></div>"
}

csv_html <- ""
if (length(csv_files) > 0) {
  csv_html <- "<ul>\n"
  for (cf in csv_files) {
    csv_html <- sprintf('%s  <li><a href="%s">%s</a></li>\n', csv_html, cf, cf)
  }
  csv_html <- sprintf("%s</ul>\n", csv_html)
} else {
  csv_html <- "<p>No CSV files generated.</p>"
}

# Script completion status
status_html <- "<table><tr><th>Script</th><th>Status</th></tr>"
for (scr in scripts) {
  status <- if (isTRUE(results[[scr]])) "OK" else "FAILED"
  color  <- if (isTRUE(results[[scr]])) "green" else "red"
  status_html <- sprintf(
    '%s<tr><td>%s</td><td style="color:%s;font-weight:bold;">%s</td></tr>',
    status_html, scr, color, status
  )
}
status_html <- sprintf("%s</table>", status_html)

html_content <- sprintf(
'<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>%s</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
         margin: 0; background: #f0f2f5; color: #333; }
  .header { background: linear-gradient(135deg, #1a1a2e, #16213e); color: #fff;
            padding: 2rem; text-align: center; }
  .header h1 { margin: 0; font-size: 2rem; }
  .header p  { margin: 0.5rem 0 0; opacity: 0.8; }
  .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
  .card { background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,0.1);
          padding: 1.5rem; margin-bottom: 2rem; overflow: hidden; }
  .card h2, .card h3 { margin-top: 0; color: #1a1a2e; }
  table { border-collapse: collapse; width: 100%%%%; margin: 1rem 0; }
  th, td { padding: 0.6rem; text-align: left; border-bottom: 1px solid #ddd; }
  th { background: #1a1a2e; color: #fff; }
  tr:hover { background: #f1f1f1; }
  img { max-width: 100%%%%; height: auto; border-radius: 4px; margin: 1rem 0; }
  a { color: #1a73e8; text-decoration: none; }
  a:hover { text-decoration: underline; }
  ul { padding-left: 1.5rem; }
</style>
</head>
<body>
<div class="header">
  <h1>%s</h1>
  <p>Generated: %s</p>
</div>
<div class="container">
  <div class="card">
    <h2>Script Execution Status</h2>
    %s
  </div>

  <div class="card">
    <h2>Generated Charts &amp; Visualizations</h2>
    %s
  </div>

  <div class="card">
    <h2>Generated CSV Reports</h2>
    %s
  </div>
</div>
</body>
</html>',
  title, title, date_str, status_html, images_html, csv_html
)

master_path <- file.path(output_dir, "master_report.html")
writeLines(html_content, master_path)
log_msg(sprintf("Written: %s", master_path))

# ── Console summary ────────────────────────────────────────────────────────────
log_msg("")
log_msg("==============================================")
log_msg(" REPORT GENERATION SUMMARY")
log_msg("==============================================")
for (scr in scripts) {
  icon <- if (isTRUE(results[[scr]])) "OK" else "FAIL"
  log_msg(sprintf("  [%s] %s", icon, scr))
}
log_msg("----------------------------------------------")
log_msg(sprintf("  Output directory: %s", output_dir))
log_msg(sprintf("  Images: %d", length(image_files)))
log_msg(sprintf("  CSVs:   %d", length(csv_files)))
log_msg(sprintf("  Master: master_report.html"))
log_msg("==============================================")

log_msg("generate_all_reports.R complete")
