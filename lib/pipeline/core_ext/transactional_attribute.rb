module Pipeline
  # Extends ActiveRecord::Base to provide attributes that are saved in a nested
  # transaction when updated through a setter.
  #
  # NOTE: When the extended attributes are updated, the entire record is saved
  #
  # Example:
  #   class Car < ActiveRecord::Base
  #     transactional_attrs :state, :engine_state
  #
  #     def run
  #       self.engine_state = :on if self.state == :on
  #     end
  #   end
  #
  #   car = Car.new
  #   car.state = :on # this will save the record in a transaction
  #   car.run # Record will be saved again, since #run updates :engine_state
  module TransactionalAttribute
    extend ActiveSupport::Concern

    class_methods do
      def transactional_attrs(*attributes)
        attributes.each do |attribute|
          define_method("#{attribute}=") do |value|
            ActiveRecord::Base.transaction(requires_new: true) do
              write_attribute(attribute.to_s, value)
              save!
            end
          end
        end
      end

      alias_method :transactional_attr, :transactional_attrs
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include Pipeline::TransactionalAttribute
end