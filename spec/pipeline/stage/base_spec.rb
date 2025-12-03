require 'spec_helper'

module Pipeline
  module Stage
    describe Base do

      context '- chaining' do
        class Step1 < Base; end
        class Step2 < Base; end
        class Step3 < Base; end

        it 'should start as itself' do
          expect(Step1.build_chain).to eq([Step1])
          expect(Step2.build_chain).to eq([Step2])
          expect(Step3.build_chain).to eq([Step3])
        end

        it 'should allow chaining' do
          expect((Step1 >> Step2).build_chain).to eq([Step1, Step2])
          expect((Step2 >> Step1).build_chain).to eq([Step2, Step1])
          expect((Step1 >> Step2 >> Step3).build_chain).to eq([Step1, Step2, Step3])
        end
      end

      context '- setup' do
        it 'should set default name' do
          expect(Base.new.name).to eq('Pipeline::Stage::Base')
          expect(::SampleStage.new.name).to eq('SampleStage')
        end

        it 'should allow overriding name at class level' do
          StubStage.default_name = 'My custom stage name'
          expect(StubStage.new.name).to eq('My custom stage name')

          StubStage.default_name = :some_symbol
          expect(StubStage.new.name).to eq('some_symbol')
        end

        it 'should allow specifying a name on creation' do
          expect(Base.new(name: 'My Name').name).to eq('My Name')
          StubStage.default_name = nil
          expect(StubStage.new(name: 'Customized Name').name).to eq('Customized Name')
        end

        it 'should start with status not_started' do
          expect(Base.new.status).to eq(:not_started)
        end

        it 'should validate status' do
          stage = Base.new
          stage.write_attribute(:status, :something_else)
          expect(stage).not_to be_valid
        end

        it "should raise error if subclass doesn't implement #run" do
          expect { Base.new.run }.to raise_error('This method must be implemented by any subclass of Pipeline::Stage::Base')
        end
      end

      context '- persistence' do
        before(:each) do
          StubStage.default_name = nil
          @stage = StubStage.new
        end

        it 'should persist stage' do
          expect(@stage).to be_new_record
          expect { @stage.save! }.not_to raise_error
          expect(@stage).not_to be_new_record
        end

        it 'should allow retrieval by id' do
          @stage.save!

          s = StubStage.find(@stage.id)
          expect(s).to eq(@stage)

          expect { Base.find('invalid_id') }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it 'should persist type as single table inheritance' do
          @stage.save!
          stage = Base.find(@stage.id)
          expect(stage).to be_an_instance_of(StubStage)
        end

        it 'should belong to pipeline instance' do
          pipeline = Pipeline::Base.create
          @stage.pipeline = pipeline
          @stage.save!

          expect(Base.find(@stage.id).pipeline).to eq(pipeline)
        end
      end

      context '- execution (success)' do
        before(:each) do
          StubStage.default_name = nil
          @stage = StubStage.new
        end

        it 'should update status after finished' do
          @stage.perform
          expect(@stage.status).to eq(:completed)
          expect(@stage).to be_completed
        end

        it 'should save status' do
          @stage.save!
          @stage.perform
          expect(@stage.reload.status).to eq(:completed)
          expect(@stage.reload).to be_completed
        end

        it 'should increment attempts' do
          expect(@stage.attempts).to eq(0)
          @stage.perform
          expect(@stage.attempts).to eq(1)
        end

        it 'should call template method #run' do
          expect(@stage).not_to be_executed
          @stage.perform
          expect(@stage).to be_executed
        end
      end

      context '- execution (failure)' do
        it 'should re-raise error' do
          stage = FailedStage.new
          expect { stage.perform }.to raise_error(StandardError)
        end

        it 'should update status on irrecoverable error' do
          stage = IrrecoverableStage.new
          expect { stage.perform }.to raise_error(IrrecoverableError)
          expect(stage.status).to eq(:failed)
          expect(stage.reload.status).to eq(:failed)
        end

        it 'should update message on irrecoverable error' do
          stage = IrrecoverableStage.new
          expect { stage.perform }.to raise_error(IrrecoverableError)
          expect(stage.message).to eq('message')
          expect(stage.reload.message).to eq('message')
        end

        it 'should update status on recoverable error (not requiring input)' do
          stage = RecoverableStage.new
          expect { stage.perform }.to raise_error(RecoverableError)
          expect(stage.status).to eq(:failed)
          expect(stage.reload.status).to eq(:failed)
        end

        it 'should update status on recoverable error (requiring input)' do
          stage = RecoverableInputRequiredStage.new
          expect { stage.perform }.to raise_error(RecoverableError)
          expect(stage.status).to eq(:failed)
          expect(stage.reload.status).to eq(:failed)
        end

        it 'should update message on recoverable error' do
          stage = RecoverableStage.new
          expect { stage.perform }.to raise_error(RecoverableError)
          expect(stage.message).to eq('message')
          expect(stage.reload.message).to eq('message')
        end

        it 'should capture generic Exception' do
          stage = GenericErrorStage.new
          expect { stage.perform }.to raise_error(Exception)
          expect(stage.status).to eq(:failed)
          expect(stage.reload.status).to eq(:failed)
        end

        it 'should log exception message and backtrace' do
          class StageFailWithDetails < StubStage
            self.default_name = 'Fail With Details'

            def run
              super
              error = StandardError.new('error message')
              error.set_backtrace(['a', 'b', 'c'])
              raise error
            end
          end
          stage = StageFailWithDetails.new

          expect(stage.logger).to receive(:info).with('Error on stage Fail With Details: error message')
          expect(stage.logger).to receive(:info).with("a\nb\nc")
          expect { stage.perform }.to raise_error(StandardError, 'error message')
        end

        it 'should refresh object (in case it was cancelled after job was scheduled)' do
          # Gets failed on the first time
          stage = RecoverableStage.create!
          expect { stage.perform }.to raise_error(RecoverableError)

          # Status gets updated to completed on the database (not on the current instance)
          same_stage = StubStage.find(stage.id)
          same_stage.update_column(:status, :completed)

          # Retrying should fail because stage is now completed
          expect { stage.perform }.to raise_error(InvalidStatusError, 'Status is already completed')
        end
      end

      context '- execution (in progress)' do
        it 'should set status to in_progress' do
          StubStage.default_name = nil
          stage = StubStage.new
          stage.send(:_setup)

          expect(stage.status).to eq(:in_progress)
          expect(stage.reload.status).to eq(:in_progress)
        end

        it 'should clear message when restarting' do
          StubStage.default_name = nil
          stage = StubStage.new(message: 'some message')
          stage.send(:_setup)

          expect(stage.message).to be_nil
          expect(stage.reload.message).to be_nil
        end
      end

      context '- execution (state transitions)' do
        before(:each) do
          StubStage.default_name = nil
          @stage = StubStage.new
          @stage.save!
        end

        it 'should execute if status is :not_started' do
          expect { @stage.perform }.not_to raise_error
        end

        it 'should execute if status is :failed (for retrying)' do
          @stage.update_column(:status, :failed)

          expect { @stage.perform }.not_to raise_error
        end

        it 'should not execute if status is :in_progress' do
          @stage.update_column(:status, :in_progress)

          expect { @stage.perform }.to raise_error(InvalidStatusError, 'Status is already in progress')
        end

        it 'should not execute if status is :completed' do
          @stage.update_column(:status, :completed)

          expect { @stage.perform }.to raise_error(InvalidStatusError, 'Status is already completed')
        end
      end

      context '- callbacks' do
        before(:each) do
          @stage = ::SampleStage.new
        end

        it 'should allow callback before running the stage' do
          expect(@stage).to receive(:before_stage_callback).once
          @stage.perform
        end

        it 'should allow callback after running the stage on success' do
          expect(@stage).to receive(:after_stage_callback).once
          @stage.perform
        end

        it 'should allow callback after running the stage on failure' do
          allow(@stage).to receive(:run).and_raise(RuntimeError, 'error')
          expect(@stage).to receive(:after_stage_callback).once
          expect { @stage.perform }.to raise_error(RuntimeError, 'error')
        end

        it 'should run callback once for each stage' do
          pipeline = ::SamplePipelineWithCallbacks.new
          pipeline.perform
          expect(pipeline.stages[0].before_stage_executed).to eq(1)
          expect(pipeline.stages[0].after_stage_executed).to eq(1)
        end
      end
    end
  end
end
