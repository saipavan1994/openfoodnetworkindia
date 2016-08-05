rails_root =  File.dirname(File.dirname(__FILE__))
shared_path = "/home/deployer/apps/openfoodnetwork/shared"
rails_pid_file = "#{shared_path}/pids/unicorn.pid"
delayed_job_pid_file = "#{shared_path}/pids/delayed_job.pid"
filebeat_pid_file = "#{shared_path}/pids/filebeat.pid"
# new god config
p rails_root


# God configuration to start & monitor rails server
# god -c config/rails_production.god
# god terminate
# god start
# god stop
# god restart

#-----------------------------------------------------------------------------

God.watch do |w|

	w.log = rails_root + '/log/production.log'
	w.group = 'daemons'

	w.name = "start_rails_server"


	# Working directory where commands will be run.
	w.dir = rails_root

	# Where unicorn stores its PID file. God uses this to track the process.
	w.pid_file = rails_pid_file


	# Environment variables to set before starting the process.
	w.env = { 'RAILS_ENV' => 'production' }

	w.start = "cd #{rails_root} && bundle exec unicorn -c config/unicorn.rb -D -E production"
	w.stop = "pkill -f unicorn"

	# Clean stale PID files before starting.
	w.behavior :clean_pid_file

	# How often God will check the process.
	# All transitions defined below are checked at this frequency.
	w.interval = 30.seconds

	# Wait 15 seconds before checking if Unicorn has started or restarted successfully.
	w.start_grace = 15.seconds
	w.restart_grace = 15.seconds

	# Determine the state on startup.
	# When God starts, the watch is in the init state. This and all further transitions
	# are checked every interval to determine whether the state has changed.
	w.transition(:init, { true => :up, false => :start }) do |on|

		# Transition from the init state to the up state if the process is already running,
		# or to the start state if it's not.
		on.condition(:process_running) do |c|
			c.running = true
		end
	end

	# Determine when the process has finished starting:
	w.transition([:start, :restart], :up) do |on|

		# Transition from the start or restart state
		# to the up state if the process is running.
		on.condition(:process_running) do |c|
			c.running = true
		end

		# Try checking the process 3 times then transition
		# to the start state again if it hasn't started.
		on.condition(:tries) do |c|
			c.times = 3
			c.transition = :start
		end

		# With the previous configuration, this will start checking whether the process
		# has started 15 seconds after running the start/restart command (start grace).
		# After the first check, it will try checking two more times over 60 seconds
		# (twice the interval), then transition to the start state if the process
		# hasn't started.
	end

	# Start the process if it's not running.
	w.transition(:up, :start) do |on|

		# If the process isn't running, notify developers
		# and transition from the up to the start state.
		on.condition(:process_running) do |c|
			c.running = false
			c.notify = 'developers'
		end
	end

	# Restart if memory or cpu is too high.
	w.restart_if do |restart|

		restart.condition(:memory_usage) do |c|
			c.above = 850.megabytes
			c.times = [3, 5] # 3 out of 5 intervals
			c.notify = 'developers'
		end

		restart.condition(:cpu_usage) do |c|
			c.above = 50.percent
			c.times = 5
			c.notify = 'developers'
		end
	end

	# Safeguard against multiple restarts.
	w.lifecycle do |on|

		on.condition(:flapping) do |c|

			c.notify = 'developers'
			c.to_state = [:start, :restart]
			c.times = 5
			c.within = 30.minutes
			c.transition = :unmonitored

			# Retry monitoring in 10 minutes.
			c.retry_in = 10.minutes

			# If flapping is detected 5 times within 10 hours, notify developers and
			# give up (the process will have to be restarted manually).
			c.retry_times = 5
			c.retry_within = 10.hours
		end
	end

end
