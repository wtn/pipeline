require 'spec_helper'

module Pipeline
  describe InvalidPipelineError do
    it 'should accept description message when raised' do
      expect { raise InvalidPipelineError.new, 'message' }.to raise_error(InvalidPipelineError, 'message')
    end
  end

  describe InvalidStatusError do
    it 'should accept status name as symbol' do
      expect { raise InvalidStatusError.new(:started) }.to raise_error(InvalidStatusError, 'Status is already started')
    end

    it 'should accept status name as string' do
      expect { raise InvalidStatusError.new('in progress') }.to raise_error(InvalidStatusError, 'Status is already in progress')
    end

    it 'should replace underscores with spaces' do
      expect { raise InvalidStatusError.new(:in_progress) }.to raise_error(InvalidStatusError, 'Status is already in progress')
    end
  end

  describe IrrecoverableError do
    it 'should accept description message when raised' do
      expect { raise IrrecoverableError.new, 'message' }.to raise_error(IrrecoverableError, 'message')
    end
  end

  describe RecoverableError do
    it 'should accept description message when raised' do
      expect { raise RecoverableError.new, 'message' }.to raise_error(RecoverableError, 'message')
      expect { raise RecoverableError.new('message') }.to raise_error(RecoverableError, 'message')
    end

    it 'might require user input' do
      error = RecoverableError.new('message', true)
      expect(error).to be_input_required
    end

    it "doesn't require user input by default" do
      error = RecoverableError.new
      expect(error).not_to be_input_required
    end
  end
end
