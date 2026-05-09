# frozen_string_literal: true

require "pathname"
require "yaml"
require "json"

module RailsDoctor
  class Error < StandardError; end
end

require_relative "rails_doctor/version"
require_relative "rails_doctor/diagnostic"
require_relative "rails_doctor/rule"
require_relative "rails_doctor/registry"
require_relative "rails_doctor/config"
require_relative "rails_doctor/project"
require_relative "rails_doctor/score"
require_relative "rails_doctor/runner"
require_relative "rails_doctor/installer"
require_relative "rails_doctor/cli"
