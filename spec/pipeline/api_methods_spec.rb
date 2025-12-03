require 'spec_helper'

module Pipeline
  describe ApiMethods do
    class FakePipeline < Pipeline::Base
    end

    describe '#start' do
      before(:each) do
        @pipeline = FakePipeline.new
        allow(@pipeline).to receive(:new_record?).and_return(false)
        allow(Delayed::Job).to receive(:enqueue)
      end

      it 'should only accept instance of Pipeline::Base' do
        expect { Pipeline.start(@pipeline) }.not_to raise_error
        expect { Pipeline.start(Object.new) }.to raise_error(InvalidPipelineError, 'Invalid pipeline')
      end

      it 'should save pipeline instance (for new record)' do
        expect(@pipeline).to receive(:new_record?).and_return(true)
        expect(@pipeline).to receive(:save!)

        Pipeline.start(@pipeline)
      end

      it 'should not save pipeline instance (if already saved)' do
        expect(@pipeline).to receive(:new_record?).and_return(false)
        expect(@pipeline).not_to receive(:save!)

        Pipeline.start(@pipeline)
      end

      it 'should start a job for a pipeline instance' do
        expect(Delayed::Job).to receive(:enqueue).with(@pipeline)

        Pipeline.start(@pipeline)
      end

      it 'should provide a token for the pipeline instance' do
        allow(@pipeline).to receive(:id).and_return('123')

        token = Pipeline.start(@pipeline)
        expect(token).to eq('123')
      end
    end

    describe '#resume' do
      before(:each) do
        @pipeline = Pipeline::Base.new
        allow(@pipeline).to receive(:resume)
        allow(Pipeline::Base).to receive(:find).with('1').and_return(@pipeline)
        allow(Delayed::Job).to receive(:enqueue)
      end

      it 'should accept a token for a pipeline instance' do
        expect(Pipeline::Base).to receive(:find).with('1')

        Pipeline.resume('1')
      end

      it 'should raise error if trying to resume invalid pipeline' do
        expect(Pipeline::Base).to receive(:find)
          .with('1')
          .and_raise(ActiveRecord::RecordNotFound.new)

        expect { Pipeline.resume('1') }.to raise_error(InvalidPipelineError, 'Invalid pipeline')
      end

      it 'should start a new job for that pipeline instance' do
        expect(Delayed::Job).to receive(:enqueue).with(@pipeline)

        Pipeline.resume('1')
      end

      it 'should resume pipeline instance' do
        expect(@pipeline).to receive(:resume)

        Pipeline.resume('1')
      end
    end

    describe '#cancel' do
      before(:each) do
        @pipeline = Pipeline::Base.new
        allow(@pipeline).to receive(:cancel)
        allow(Pipeline::Base).to receive(:find).with('1').and_return(@pipeline)
      end

      it 'should accept a token for a pipeline instance' do
        expect(Pipeline::Base).to receive(:find).with('1')
        Pipeline.cancel('1')
      end

      it 'should raise error is trying to cancel invalid pipeline' do
        expect(Pipeline::Base).to receive(:find)
          .with('1')
          .and_raise(ActiveRecord::RecordNotFound.new)

        expect { Pipeline.cancel('1') }.to raise_error(InvalidPipelineError, 'Invalid pipeline')
      end

      it 'should cancel pipeline instance' do
        expect(@pipeline).to receive(:cancel)
        Pipeline.cancel('1')
      end
    end
  end
end
