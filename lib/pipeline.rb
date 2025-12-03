require 'active_record'
require 'delayed_job'

require_relative 'pipeline/core_ext/symbol_attribute'
require_relative 'pipeline/core_ext/transactional_attribute'
require_relative 'pipeline/api_methods'
require_relative 'pipeline/errors'
require_relative 'pipeline/base'
require_relative 'pipeline/stage/base'

# Please refer to Pipeline::Base and Pipeline::Stage::Base for detailed documentation
module Pipeline
  extend(ApiMethods)
end
