require 'spec_helper'

module Pipeline
  describe Base do

    context '- configuring' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> SecondStage
        end
      end

      it 'should allow accessing stages' do
        expect(SamplePipeline.defined_stages).to eq([FirstStage, SecondStage])
      end

      it 'should allow configuring default failure mode (pause by default)' do
        SamplePipeline.default_failure_mode = :pause
        expect(SamplePipeline.failure_mode).to eq(:pause)

        SamplePipeline.default_failure_mode = :cancel
        expect(SamplePipeline.failure_mode).to eq(:cancel)

        SamplePipeline.default_failure_mode = :something_else
        expect(SamplePipeline.failure_mode).to eq(:pause)
      end
    end

    context '- setup' do
      before(:each) do
        @pipeline = SamplePipeline.new
      end

      it 'should start with status not_started' do
        expect(@pipeline.status).to eq(:not_started)
      end

      it 'should instantiate stages with status not_started' do
        @pipeline.stages.each { |stage| expect(stage.status).to eq(:not_started) }
      end

      it 'should validate status' do
        pipeline = Base.new
        pipeline.write_attribute(:status, :something_else)
        expect(pipeline).not_to be_valid
      end
    end

    context '- persistence' do
      before(:each) do
        @pipeline = Base.new
      end

      it 'should persist pipeline instance' do
        expect(@pipeline).to be_new_record
        expect { @pipeline.save! }.not_to raise_error
        expect(@pipeline).not_to be_new_record
      end

      it 'should allow retrieval by id' do
        @pipeline.save!

        retrieved_pipeline = Base.find(@pipeline.id.to_s)
        expect(retrieved_pipeline).to eq(@pipeline)

        expect { Base.find('invalid_id') }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'should persist type as single table inheritance' do
        pipeline = SamplePipeline.new
        pipeline.save!

        retrieved_pipeline = Base.find(pipeline.id)
        expect(retrieved_pipeline).to be_an_instance_of(SamplePipeline)
      end

      it 'should persist pipeline stages' do
        pipeline = SamplePipeline.new
        pipeline.stages.each { |stage| expect(stage.id).to be_nil }
        expect { pipeline.save! }.not_to raise_error
        pipeline.stages.each { |stage| expect(stage.id).not_to be_nil }
      end

      it 'should allow retrieval of stages with pipeline instance' do
        pipeline = SamplePipeline.new
        pipeline.save!

        retrieved_pipeline = SamplePipeline.find(pipeline.id)
        expect(retrieved_pipeline.stages).to eq(pipeline.stages)
      end

      it 'should associate stages with pipeline instance' do
        pipeline = SamplePipeline.new
        pipeline.save!

        pipeline.stages.each { |stage| expect(stage.pipeline).to eq(pipeline) }
      end

      it 'should destroy stages when pipeline instance is destroyed' do
        pipeline = SamplePipeline.new
        pipeline.save!

        expect(Pipeline::Stage::Base.where(pipeline_instance_id: pipeline.id).count).to be > 0

        pipeline.destroy
        expect(Pipeline::Stage::Base.where(pipeline_instance_id: pipeline.id).count).to eq(0)
      end
    end

    context '- execution (success)' do
      before(:each) do
        @pipeline = SamplePipeline.new
      end

      it 'should increment attempts' do
        expect(@pipeline.attempts).to eq(0)
        @pipeline.perform
        expect(@pipeline.attempts).to eq(1)
      end

      it 'should perform each stage' do
        @pipeline.stages.each { |stage| expect(stage).not_to be_executed }
        @pipeline.perform
        @pipeline.stages.each { |stage| expect(stage).to be_executed }
      end

      it 'should update pipeline status after all stages finished' do
        @pipeline.perform
        expect(@pipeline.status).to eq(:completed)
      end

      it 'should save status' do
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:completed)
      end
    end

    context '- execution (in progress)' do
      it 'should set status to in_progress' do
        pipeline = SamplePipeline.new
        pipeline.send(:_setup)

        expect(pipeline.status).to eq(:in_progress)
        expect(pipeline.reload.status).to eq(:in_progress)
      end
    end

    context '- execution (irrecoverable error)' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> IrrecoverableStage
        end
        @pipeline = ::SamplePipeline.new
      end

      it 'should not re-raise error' do
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should update status' do
        @pipeline.perform
        expect(@pipeline.status).to eq(:failed)
      end

      it 'should save status' do
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:failed)
      end
    end

    context "- execution (recoverable error that doesn't require user input)" do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> RecoverableStage
        end
        @pipeline = SamplePipeline.new
      end

      it 'should re-raise error (so delayed_job retry works)' do
        expect { @pipeline.perform }.to raise_error(RecoverableError)
      end

      it 'should change status to :retry' do
        expect { @pipeline.perform }.to raise_error(RecoverableError)
        expect(@pipeline.status).to eq(:retry)
      end

      it 'should save status' do
        @pipeline.save!
        expect { @pipeline.perform }.to raise_error(RecoverableError)
        expect(@pipeline.reload.status).to eq(:retry)
      end
    end

    context '- execution (recoverable error that requires user input)' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> RecoverableInputRequiredStage
        end
        @pipeline = SamplePipeline.new
      end

      it 'should not re-raise error' do
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should update status' do
        @pipeline.perform
        expect(@pipeline.status).to eq(:paused)
      end

      it 'should save status' do
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:paused)
      end
    end

    context '- execution (other errors will use failure mode to pause/cancel pipeline)' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> GenericErrorStage
        end
        @pipeline = SamplePipeline.new
      end

      it 'should not re-raise error' do
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should update status (pause mode)' do
        SamplePipeline.default_failure_mode = :pause
        @pipeline.perform
        expect(@pipeline.status).to eq(:paused)
      end

      it 'should save status (pause mode)' do
        SamplePipeline.default_failure_mode = :pause
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:paused)
      end

      it 'should update status (cancel mode)' do
        SamplePipeline.default_failure_mode = :cancel
        @pipeline.perform
        expect(@pipeline.status).to eq(:failed)
      end

      it 'should save status (cancel mode)' do
        SamplePipeline.default_failure_mode = :cancel
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:failed)
      end
    end

    context '- execution (retrying)' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> RecoverableInputRequiredStage
        end
        @pipeline = SamplePipeline.new
      end

      it 'should not re-raise error' do
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should update status' do
        @pipeline.perform
        expect(@pipeline.status).to eq(:paused)
      end

      it 'should save status' do
        @pipeline.save!
        @pipeline.perform
        expect(@pipeline.reload.status).to eq(:paused)
      end

      it 'should skip completed stages' do
        @pipeline.perform
        expect(@pipeline.stages[0].attempts).to eq(1)
        expect(@pipeline.stages[1].attempts).to eq(1)

        @pipeline.perform
        expect(@pipeline.stages[0].attempts).to eq(1)
        expect(@pipeline.stages[1].attempts).to eq(2)
      end

      it 'should refresh object (in case it was cancelled after job was scheduled)' do
        # Gets paused on the first time
        @pipeline.save!
        @pipeline.perform

        # Status gets updated to failed on the database (not on the current instance)
        same_pipeline = SamplePipeline.find(@pipeline.id)
        same_pipeline.update_column(:status, :failed)

        # Retrying should fail because pipeline is now failed
        expect { @pipeline.perform }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- execution (state transitions)' do
      before(:each) do
        @pipeline = Base.new
        @pipeline.save!
      end

      it 'should execute if status is :not_started' do
        expect(@pipeline).to be_ok_to_resume
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should execute if status is :paused (for retrying)' do
        @pipeline.update_column(:status, :paused)

        expect(@pipeline).to be_ok_to_resume
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should execute if status is :retry' do
        @pipeline.update_column(:status, :retry)

        expect(@pipeline).to be_ok_to_resume
        expect { @pipeline.perform }.not_to raise_error
      end

      it 'should not execute if status is :in_progress' do
        @pipeline.update_column(:status, :in_progress)

        expect(@pipeline).not_to be_ok_to_resume
        expect { @pipeline.perform }.to raise_error(InvalidStatusError, 'Status is already in progress')
      end

      it 'should not execute if status is :completed' do
        @pipeline.update_column(:status, :completed)

        expect(@pipeline).not_to be_ok_to_resume
        expect { @pipeline.perform }.to raise_error(InvalidStatusError, 'Status is already completed')
      end

      it 'should not execute if status is :failed' do
        @pipeline.update_column(:status, :failed)

        expect(@pipeline).not_to be_ok_to_resume
        expect { @pipeline.perform }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- cancelling' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> RecoverableInputRequiredStage
        end
        @pipeline = SamplePipeline.new
        @pipeline.perform
      end

      it 'should update status' do
        @pipeline.cancel
        expect(@pipeline.status).to eq(:failed)
      end

      it 'should save status' do
        @pipeline.save!
        @pipeline.cancel
        expect(@pipeline.reload.status).to eq(:failed)
      end

      it 'should refresh object (in case it was updated after job was scheduled)' do
        # Gets paused on the first time
        @pipeline.save!

        # Status gets updated to failed on the database (not on the current instance)
        same_pipeline = SamplePipeline.find(@pipeline.id)
        same_pipeline.update_column(:status, :failed)

        # Retrying should fail because pipeline is now failed
        expect { @pipeline.cancel }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- cancelling (state transitions)' do
      before(:each) do
        @pipeline = Base.new
        @pipeline.save!
      end

      it 'should cancel if status is :not_started' do
        expect { @pipeline.cancel }.not_to raise_error
      end

      it 'should cancel if status is :paused (for retrying)' do
        @pipeline.update_column(:status, :paused)

        expect { @pipeline.cancel }.not_to raise_error
      end

      it 'should not cancel if status is :in_progress' do
        @pipeline.update_column(:status, :in_progress)

        expect { @pipeline.cancel }.to raise_error(InvalidStatusError, 'Status is already in progress')
      end

      it 'should not cancel if status is :completed' do
        @pipeline.update_column(:status, :completed)

        expect { @pipeline.cancel }.to raise_error(InvalidStatusError, 'Status is already completed')
      end

      it 'should not cancel if status is :failed' do
        @pipeline.update_column(:status, :failed)

        expect { @pipeline.cancel }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- resuming' do
      before(:each) do
        class ::SamplePipeline
          define_stages FirstStage >> RecoverableInputRequiredStage
        end
        @pipeline = SamplePipeline.new
        @pipeline.perform
      end

      it 'should refresh object (in case it was updated after job was scheduled)' do
        # Gets paused on the first time
        @pipeline.save!

        # Status gets updated to failed on the database (not on the current instance)
        same_pipeline = SamplePipeline.find(@pipeline.id)
        same_pipeline.update_column(:status, :failed)

        # Retrying should fail because pipeline is now failed
        expect { @pipeline.resume }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- resuming (state transitions)' do
      before(:each) do
        @pipeline = Base.new
        @pipeline.save!
      end

      it 'should resume if status is :not_started' do
        expect { @pipeline.resume }.not_to raise_error
      end

      it 'should resume if status is :paused (for retrying)' do
        @pipeline.update_column(:status, :paused)

        expect { @pipeline.resume }.not_to raise_error
      end

      it 'should not resume if status is :in_progress' do
        @pipeline.update_column(:status, :in_progress)

        expect { @pipeline.resume }.to raise_error(InvalidStatusError, 'Status is already in progress')
      end

      it 'should not resume if status is :completed' do
        @pipeline.update_column(:status, :completed)

        expect { @pipeline.resume }.to raise_error(InvalidStatusError, 'Status is already completed')
      end

      it 'should not resume if status is :failed' do
        @pipeline.update_column(:status, :failed)

        expect { @pipeline.resume }.to raise_error(InvalidStatusError, 'Status is already failed')
      end
    end

    context '- callbacks' do
      before(:each) do
        @pipeline = ::SamplePipeline.new
      end

      it 'should allow callback before running the pipeline' do
        expect(@pipeline).to receive(:before_pipeline_callback).once
        @pipeline.perform
      end

      it 'should allow callback after running the pipeline' do
        expect(@pipeline).to receive(:after_pipeline_callback).once
        @pipeline.perform
      end

      it 'should run callback after cancelling a pipeline' do
        expect(@pipeline).to receive(:after_pipeline_callback).once
        @pipeline.cancel
      end
    end
  end
end
