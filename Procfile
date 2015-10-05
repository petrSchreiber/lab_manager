compute_actions: sidekiq -c 1 -r ./lib/lab_manager/sidekiq/boot.rb -q compute_actions
scheduler: bundle exec ./bin/scheduler
web: bundle exec unicorn -p $PORT
