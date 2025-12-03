require 'spec_helper'

# Reusing stage table to simplify database integration tests
class FakeForSymbolAttribute < ActiveRecord::Base
  self.table_name = 'pipeline_stages'

  symbol_attr :status
end

module Pipeline
  describe SymbolAttribute do
    before(:each) do
      FakeForSymbolAttribute.delete_all
    end

    it 'should extend active record to allow symbol attributes to be saved as string' do
      obj = FakeForSymbolAttribute.new(status: 'started')
      obj.save!
      expect(obj.status).to eq(:started)
      expect(obj.reload.status).to eq(:started)

      obj.status = 'finished'
      obj.save!
      expect(obj.status).to eq(:finished)
      expect(obj.reload.status).to eq(:finished)
    end

    it 'should extend Symbol to allow symbol attributes in conditions' do
      objs = FakeForSymbolAttribute.where(status: :started)
      expect(objs).to be_empty

      FakeForSymbolAttribute.create(status: :started)

      objs = FakeForSymbolAttribute.where(status: :started)
      expect(objs.size).to eq(1)
    end
  end
end
