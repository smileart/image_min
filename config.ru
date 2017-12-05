# frozen_string_literal: true
# encoding: UTF-8

# ================== Confgiure Puma on Heroku ===================
require 'set'
require 'puma'
require 'puma/plugin'
require 'puma/plugin/heroku'

# ======================== ENV and Debug ========================
require_relative './lib/config'
dev = Config.rack_env.casecmp?('development')

require 'byebug' if dev
puts "\nLoaded ENVIRONMENT :: #{Config.env_name}\n\n"

# =================== Live reload in DEV mode ===================
require 'rack/unreloader'
Unreloader = Rack::Unreloader.new(subclasses: ['Roda'], reload: dev) do
  ImageMin
end

Unreloader.require './app.rb'

# ====================== Rack::Attack config ====================
require 'rack/attack'
require_relative 'config/rack_attack'

use Rack::Attack

# ====================== Rack::RequestId config =================
require 'rack/request_id'

use Rack::RequestId, id_generator: ->() { SecureRandom.uuid }

# ====================== Rack::Fraction config =================
require 'rack/fraction'
require 'active_support/core_ext/array/grouping'

# @HACK Temporary fix while these things are still in work:
#       https://github.com/toy/image_optim/pull/149
#       https://github.com/toy/image_optim/issues/21
use Rack::Fraction, percent: Config.zombies_killing_rate do |env|
  zombies_max_population = Config.zombies_max_population

  workers = `ps auxw | grep 'cluster worker [0-9]' | awk '{print $2}'`
  workers = Set.new(workers.lines.map(&:strip))

  zombies_pids = `ps axw -o pid -o stat | grep [Z]N | awk '{ print $1 }'`
  zombies_pids = zombies_pids.lines.map(&:strip)

  zombies_ppids = `ps -xaw -o state -o ppid | grep Z | grep -v PID | awk '{print $2}'`
  zombies_ppids = zombies_ppids.lines.map(&:strip).uniq

  pids_to_kill = workers.intersection(zombies_ppids).to_a

  puts %W[
    [#{Process.pid}] >> There #{zombies_pids.count} zombie(s)
    produced by #{zombies_ppids.count} worker(s) #{zombies_ppids.inspect}
    at the current value of ZOMBIES_MAX_POPULATION = #{zombies_max_population}
  ].join ' '

  # Kill zombies producing workers
  # @CAUTION Zombies killing won't work with one-worker configuration
  if !pids_to_kill.empty? && zombies_pids.count >= zombies_max_population
    # Try not to commit suicide (if the only worker and to complete request)
    pids_to_kill -= [Process.pid.to_s]

    # take ~50% of zombie producing workers
    # pids_to_kill = pids_to_kill.in_groups_of(pids_to_kill.size.quo(2).ceil, false).first

    pids_to_kill = pids_to_kill.join(' ')

    puts "[#{Process.pid}] >> Pid(s) #{pids_to_kill} (was/where) killed by the #{Process.pid}"
    `kill -15 #{pids_to_kill}`
  end

  env
end

# ============================ RUN! =============================
run(dev ? Unreloader : ImageMin)
