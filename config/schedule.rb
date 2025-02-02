$LOAD_PATH << "."
require "active_support/all"
require "lib/whitehall"

# default cron env is "/usr/bin:/bin" which is not sufficient as govuk_env is in /usr/local/bin
env :PATH, "/usr/local/bin:/usr/bin:/bin"

# We need Rake to use our own environment
job_type :rake, "cd :path && govuk_setenv whitehall bundle exec rake :task --silent :output"

def search_index_consultations_cron_rule
  if Whitehall.integration_or_staging?
    # Don't run near midnight, as this is when the data sync will
    # likely happen, and the task will error
    "0 2-22 * * *"
  else
    :hour
  end
end

every search_index_consultations_cron_rule, roles: [:backend] do
  rake "search:index:consultations"
end

def taxonomy_cron_rules
  if Whitehall.integration_or_staging?
    # at every 10th minute past the hour between 7am and 8pm
    "*/10 7-20 * * *"
  else
    10.minutes
  end
end

every taxonomy_cron_rules, roles: [:backend] do
  rake "taxonomy:rebuild_cache"
end
