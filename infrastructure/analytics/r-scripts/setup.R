# setup.R - Package management, DB connection, and sourcing
# Part of MASAREN Impact-as-a-Service analytics platform

log_msg <- function(msg) {
  cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), msg))
}

log_msg("Starting setup.R: loading packages and configuration")

# ── Required packages ──────────────────────────────────────────────────────────
packages <- c(
  "DBI", "RPostgres", "dplyr", "ggplot2", "tidyr",
  "knitr", "rmarkdown", "jsonlite", "lubridate", "plotly", "DT"
)

for (pkg in packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    log_msg(sprintf("Installing package: %s", pkg))
    install.packages(pkg, repos = "https://cran.rstudio.com/", quiet = TRUE)
    library(pkg, character.only = TRUE)
  }
}
log_msg("All required packages loaded successfully")

# ── Database connection parameters ─────────────────────────────────────────────
DB_HOST <- Sys.getenv("DB_HOST", unset = "localhost")
DB_PORT <- as.integer(Sys.getenv("DB_PORT", unset = "5432"))
DB_NAME <- Sys.getenv("DB_NAME", unset = "masaren_impact")
DB_USER <- Sys.getenv("DB_USER", unset = "masaren_user")
DB_PASS <- Sys.getenv("DB_PASS", unset = "masaren_dev")

# ── connect_db ─────────────────────────────────────────────────────────────────
connect_db <- function() {
  tryCatch(
    {
      conn <- dbConnect(
        RPostgres::Postgres(),
        host     = DB_HOST,
        port     = DB_PORT,
        dbname   = DB_NAME,
        user     = DB_USER,
        password = DB_PASS
      )
      log_msg(sprintf("Connected to PostgreSQL at %s:%s/%s", DB_HOST, DB_PORT, DB_NAME))
      conn
    },
    error = function(e) {
      stop(sprintf("Database connection failed: %s", e$message))
    }
  )
}

# ── disconnect_db ──────────────────────────────────────────────────────────────
disconnect_db <- function(conn) {
  if (!is.null(conn) && dbIsValid(conn)) {
    dbDisconnect(conn)
    log_msg("Disconnected from database")
  }
}

# ── query_db ───────────────────────────────────────────────────────────────────
query_db <- function(conn, query, params = list()) {
  tryCatch(
    {
      result <- dbSendQuery(conn, query)
      if (length(params) > 0) {
        dbBind(result, params)
      }
      data <- dbFetch(result)
      dbClearResult(result)
      data
    },
    error = function(e) {
      log_msg(sprintf("Query failed: %s", e$message))
      data.frame()
    }
  )
}

# ── Source sibling scripts ─────────────────────────────────────────────────────
script_dir <- dirname(sys.frame(1)$ofile)
if (is.null(script_dir) || script_dir == "") {
  script_dir <- getwd()
}
other_scripts <- list.files(
  script_dir,
  pattern = "^[^_].*\\.R$",
  full.names = TRUE,
  ignore.case = TRUE
)
other_scripts <- setdiff(other_scripts, file.path(script_dir, "setup.R"))
other_scripts <- setdiff(other_scripts, file.path(script_dir, "generate_all_reports.R"))

for (scr in other_scripts) {
  log_msg(sprintf("Sourcing %s", basename(scr)))
  source(scr)
}

log_msg("setup.R complete")
