require 'spec_helper'

# Reusing stage table to simplify database integration tests
class FakeForTransactionalAttribute < ActiveRecord::Base
  self.table_name = 'pipeline_stages'

  transactional_attr :status
end

module Pipeline
  describe TransactionalAttribute do
    it 'should extend active record to allow transactional attributes to be saved in a nested transaction' do
      obj = FakeForTransactionalAttribute.create(status: 'started')
      expect(obj.status).to eq('started')
      expect(obj.reload.status).to eq('started')

      obj.status = 'finished'
      expect(obj.status).to eq('finished')
      expect(obj.reload.status).to eq('finished')
    end
  end
end
