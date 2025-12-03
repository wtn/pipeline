module Pipeline
  # Extends ActiveRecord::Base to save and retrieve symbol attributes as strings.
  #
  # Example:
  #   class Card < ActiveRecord::Base
  #     symbol_attrs :rank, :suit
  #   end
  #
  #   card = Card.new(rank: "jack", suit: "hearts")
  #   card.rank # => :jack
  #   card.suit # => :hearts
  #
  # It also allows symbol attributes to be used in ActiveRecord queries:
  #
  #   Card.where(suit: :clubs)
  module SymbolAttribute
    extend ActiveSupport::Concern

    class_methods do
      def symbol_attrs(*attributes)
        attributes.each do |attribute|
          define_method(attribute) do
            value = read_attribute(attribute.to_s)
            value&.to_sym
          end
        end
      end

      alias_method :symbol_attr, :symbol_attrs
    end
  end
end

ActiveSupport.on_load(:active_record) do
  include Pipeline::SymbolAttribute
end